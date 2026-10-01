local wow = require("tests.mock.wow")

local State = { NeedMainSpec = 0, Greed = 3 }
local FILES = { "locale.lua", "config.lua", "core.lua", "bars.lua", "chat.lua" }
local ns

local function Load(saved)
	wow.reset()
	_G.LootBeaconOptions = saved
	ns = wow.loadAddon(FILES)
	wow.fireAddonLoaded()
end

local function BarFor(key)
	return ns.Bars.GetBar(ns.Tracker:GetRecord(key))
end

local function Click(button)
	button:GetScript("OnClick")(button, "LeftButton")
end

local function Win(key, encounterID)
	local winner = wow.RollInfo("Echo", "HUNTER", State.Greed, 92, true)
	wow.setDrop(encounterID, wow.Drop(key, { winner = winner, rollInfos = { winner } }))
	wow.fire("LOOT_HISTORY_UPDATE_DROP", encounterID, key)
end

describe("a bar never outlives its roll", function()
	before_each(function() Load() end)

	it("closes when the game says the roll is complete", function()
		wow.startRoll(1, 500, 60000)
		wow.fire("LOOT_ROLLS_COMPLETE", 500)
		assert.is_nil(BarFor(500))
		assert.is_true(ns.Tracker:GetRecord(500).closed)
	end)

	it("closes when the roll is decided before you roll", function()
		wow.startRoll(1, 500, 60000)
		Win(500, 0)
		assert.is_nil(BarFor(500))
	end)

	it("closes when the watchdog gives up", function()
		wow.startRoll(1, 500, 60000)
		wow.advance(76)
		assert.is_nil(BarFor(500))
	end)

	it("is replaced when the game announces a recovered roll again", function()
		wow.addRoll(7, 60000, wow.ItemInfo())
		wow.fire("PLAYER_ENTERING_WORLD", false, true)
		wow.fire("START_LOOT_ROLL", 7, 60000, 500)
		local open = ns.Tracker:GetOpenRecords()
		assert.equals(1, #open)
		assert.equals(500, open[1].key)
		assert.equals(1, #ns.Bars.GetShownRecords())
		wow.advance(100)
		assert.equals(1, #ChatFrame3._messages) -- the real roll's own timeout; the replaced guess stays quiet
	end)
end)

describe("shift-click", function()
	before_each(function()
		Load()
		wow.startRoll(1, 500, 60000)
	end)

	it("still rolls, then confirms when the game asks", function()
		wow.shift = true
		Click(BarFor(500).buttons.greed)
		assert.same({ { 1, 2 } }, wow.calls.RollOnLoot)
		assert.is_nil(wow.calls.ConfirmLootRoll)
		wow.fire("CONFIRM_LOOT_ROLL", 1, 2, "")
		assert.same({ { 1, 2 } }, wow.calls.ConfirmLootRoll)
		assert.same({ "CONFIRM_LOOT_ROLL", 1 }, wow.calls.StaticPopup_Hide[1])
	end)

	it("hides the confirmation box again a moment later in case it opened after us", function()
		wow.shift = true
		Click(BarFor(500).buttons.greed)
		wow.fire("CONFIRM_LOOT_ROLL", 1, 2, "")
		wow.advance(0.1)
		assert.equals(2, #wow.calls.StaticPopup_Hide)
	end)

	it("confirms Disenchant the same way", function()
		wow.startRoll(2, 501, 60000, wow.ItemInfo({ canDisenchant = true }))
		wow.shift = true
		Click(BarFor(501).buttons.disenchant)
		wow.fire("CONFIRM_DISENCHANT_ROLL", 2, 3)
		assert.same({ { 2, 3 } }, wow.calls.ConfirmLootRoll)
	end)

	it("leaves the confirmation box to you without shift", function()
		Click(BarFor(500).buttons.need)
		wow.fire("CONFIRM_LOOT_ROLL", 1, 1, "")
		assert.same({ { 1, 1 } }, wow.calls.RollOnLoot)
		assert.is_nil(wow.calls.ConfirmLootRoll)
	end)
end)

describe("handing rolls to Blizzard", function()
	it("passes a real duration even when the game has none", function()
		Load()
		wow.startRoll(1, 500, 60000)
		wow.rolls[1].duration = nil
		wow.settings.LOOTBEACON_BARS_ENABLED:SetValue(false)
		assert.same({ { 1, 60000 } }, wow.calls.GroupLootContainer_AddRoll)
	end)

	it("lets Blizzard show a roll it queued before the bars were switched on", function()
		Load({ barsEnabled = false })
		wow.startRoll(1, 500, 60000)
		wow.settings.LOOTBEACON_BARS_ENABLED:SetValue(true)
		GroupLootContainer_AddRoll(1, 60000) -- Blizzard pulling it from its waiting queue
		assert.same({ { 1, 60000 } }, wow.calls.GroupLootContainer_AddRoll)
		assert.is_nil(BarFor(500))
	end)

	it("remembers a roll Blizzard took while the bars were off", function()
		Load()
		wow.startRoll(1, 500, 60000)
		wow.gamepad = true
		wow.settings.LOOTBEACON_BARS_ENABLED:SetValue(false)
		wow.gamepad = false
		GroupLootContainer_AddRoll(1, 60000) -- Blizzard's RefreshRolls on the way out of gamepad mode
		wow.settings.LOOTBEACON_BARS_ENABLED:SetValue(true)
		assert.is_nil(BarFor(500))
	end)
end)

describe("saved anchor checks", function()
	before_each(function() Load() end)

	local DEFAULT = { point = "TOP", relativePoint = "TOP", x = 0, y = -180 }

	it("resets a point that isn't a real anchor name", function()
		assert.same(DEFAULT, ns.ValidateOptions({ anchor = { point = "MIDDLE", relativePoint = "TOP", x = 0, y = 0 } }).anchor)
	end)

	it("falls back to the point when the relative point isn't real", function()
		assert.same({ point = "LEFT", relativePoint = "LEFT", x = 1, y = 2 },
			ns.ValidateOptions({ anchor = { point = "LEFT", relativePoint = "NOWHERE", x = 1, y = 2 } }).anchor)
	end)

	it("resets offsets that aren't real numbers", function()
		assert.same(DEFAULT, ns.ValidateOptions({ anchor = { point = "TOP", x = 0 / 0, y = 0 } }).anchor)
		assert.same(DEFAULT, ns.ValidateOptions({ anchor = { point = "TOP", x = 0, y = math.huge } }).anchor)
	end)
end)

describe("rolls you never got a window for", function()
	before_each(function() Load() end)

	it("still print who won, without a bar", function()
		wow.setDrop(0, wow.Drop(900, { startTime = 1000000, duration = 60000,
			rollInfos = { wow.RollInfo("Alpha", "MAGE", State.Greed) } }))
		wow.fire("LOOT_HISTORY_UPDATE_DROP", 0, 900)
		assert.equals(0, #ns.Bars.GetShownRecords())
		Win(900, 0)
		assert.equals(1, #ChatFrame3._messages)
		assert.truthy(ChatFrame3._messages[1]:find("[Greed - 92]", 1, true))
	end)

	it("are ignored when they were already decided before LootBeacon saw them", function()
		Win(901, 0)
		assert.equals(0, #ChatFrame3._messages)
		assert.is_nil(ns.Tracker:GetRecord(901))
	end)

	it("time out from the drop's own end time", function()
		wow.setDrop(0, wow.Drop(902, { startTime = 1000000, duration = 60000 }))
		wow.fire("LOOT_HISTORY_UPDATE_DROP", 0, 902)
		wow.advance(74)
		assert.equals(0, #ChatFrame3._messages)
		wow.advance(2)
		assert.equals(1, #ChatFrame3._messages)
		assert.truthy(ChatFrame3._messages[1]:find("Roll result unavailable", 1, true))
	end)
end)
