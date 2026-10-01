local wow = require("tests.mock.wow")

local State = { NeedMainSpec = 0, Pass = 5 }
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

describe("Blizzard's roll frames", function()
	it("are held back while the bars are on", function()
		Load()
		GroupLootContainer_AddRoll(1, 60000)
		assert.is_nil(wow.calls.GroupLootContainer_AddRoll)
	end)

	it("come through when the bars are off", function()
		Load({ barsEnabled = false })
		GroupLootContainer_AddRoll(1, 60000)
		assert.same({ { 1, 60000 } }, wow.calls.GroupLootContainer_AddRoll)
	end)

	it("come through in the gamepad interface", function()
		Load()
		wow.gamepad = true
		assert.is_false(ns.Bars.IsActive())
		GroupLootContainer_AddRoll(1, 60000)
		assert.same({ { 1, 60000 } }, wow.calls.GroupLootContainer_AddRoll)
	end)
end)

describe("a roll bar", function()
	before_each(function() Load() end)

	it("shows the item's name, bind tag and quality border", function()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ name = "Ephemeral Choker", quality = 3, bop = true }))
		local bar = BarFor(500)
		assert.is_true(bar:IsShown())
		assert.equals("|cffff4d1aBoP|r Ephemeral Choker", bar.name:GetText())
		assert.equals("loottoast-itemborder-q3", bar.icon.border:GetAtlas())
	end)

	it("tags bind-on-equip items in green", function()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ name = "Shadow Wand", bop = false }))
		assert.equals("|cff4dff4dBoE|r Shadow Wand", BarFor(500).name:GetText())
	end)

	it("greys out Need with Blizzard's reason when you can't need", function()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ canNeed = false, reasonNeed = 1 }))
		local need = BarFor(500).buttons.need
		assert.is_false(need:IsEnabled())
		assert.equals(0.35, need:GetAlpha())
		assert.equals(LOOT_ROLL_INELIGIBLE_REASON1, need.reason)
	end)

	it("puts Transmog where Greed goes when it's offered", function()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ canTransmog = true }))
		local buttons = BarFor(500).buttons
		assert.is_true(buttons.transmog:IsShown())
		assert.is_false(buttons.greed:IsShown())
	end)

	it("shows Disenchant only when the roll offers it", function()
		wow.startRoll(1, 500, 60000)
		assert.is_false(BarFor(500).buttons.disenchant:IsShown())
		wow.startRoll(2, 501, 60000, wow.ItemInfo({ canDisenchant = true }))
		assert.is_true(BarFor(501).buttons.disenchant:IsShown())
	end)

	it("counts how many players picked each choice", function()
		wow.startRoll(1, 500, 60000)
		wow.setDrop(0, wow.Drop(500, { rollInfos = {
			wow.RollInfo("Alpha", "MAGE", State.NeedMainSpec),
			wow.RollInfo("Bravo", "ROGUE", State.Pass),
			wow.RollInfo("Charlie", "DRUID", State.Pass),
		} }))
		wow.fire("LOOT_HISTORY_UPDATE_DROP", 0, 500)
		local buttons = BarFor(500).buttons
		assert.equals("1", buttons.need.count:GetText())
		assert.equals("2", buttons.pass.count:GetText())
		assert.equals("", buttons.greed.count:GetText())
	end)

	it("waits on item info with only Pass usable, and leaves cleanly", function()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ pending = true }))
		local bar = BarFor(500)
		assert.equals(RETRIEVING_ITEM_INFO, bar.name:GetText())
		assert.is_false(bar.buttons.need:IsEnabled())
		assert.is_false(bar.buttons.greed:IsEnabled())
		assert.is_true(bar.buttons.pass:IsEnabled())
		wow.cancelRoll(1)
		assert.is_nil(BarFor(500))
		assert.is_false(bar:IsShown())
	end)

	it("goes away once you've rolled", function()
		wow.startRoll(1, 500, 60000)
		local bar = BarFor(500)
		wow.cancelRoll(1)
		assert.is_nil(BarFor(500))
		assert.is_false(bar:IsShown())
	end)
end)

describe("stacking", function()
	it("stacks downward by default", function()
		Load()
		wow.startRoll(1, 500, 60000)
		wow.advance(1)
		wow.startRoll(2, 501, 60000)
		assert.same({ "TOP", BarFor(500), "BOTTOM", 0, -4 }, BarFor(501)._points[1])
	end)

	it("stacks upward when asked", function()
		Load({ growDirection = "up" })
		wow.startRoll(1, 500, 60000)
		wow.advance(1)
		wow.startRoll(2, 501, 60000)
		assert.same({ "BOTTOM", BarFor(500), "TOP", 0, 4 }, BarFor(501)._points[1])
	end)
end)

describe("switching the bars off and on", function()
	it("hands open rolls to Blizzard so they still have a window", function()
		Load()
		wow.startRoll(1, 500, 60000)
		wow.settings.LOOTBEACON_BARS_ENABLED:SetValue(false)
		assert.same({ { 1, 60000 } }, wow.calls.GroupLootContainer_AddRoll)
		assert.is_nil(BarFor(500))
		wow.settings.LOOTBEACON_BARS_ENABLED:SetValue(true)
		assert.is_nil(BarFor(500))
		wow.startRoll(2, 501, 60000)
		assert.is_not_nil(BarFor(501))
	end)

	it("leaves rolls that started while the bars were off to Blizzard", function()
		Load({ barsEnabled = false })
		wow.startRoll(1, 500, 60000)
		wow.settings.LOOTBEACON_BARS_ENABLED:SetValue(true)
		assert.is_nil(BarFor(500))
	end)

	it("hides in the gamepad interface and comes straight back without waiting for news", function()
		Load()
		wow.startRoll(1, 500, 60000)
		local root = ns.Bars._root
		wow.gamepad = true
		root:GetScript("OnUpdate")(root, 0.1)
		assert.is_nil(BarFor(500))
		wow.gamepad = false
		GroupLootContainer_AddRoll(1, 60000) -- what Blizzard's RefreshRolls does on the way back
		assert.is_not_nil(BarFor(500))
		assert.is_nil(wow.calls.GroupLootContainer_AddRoll)
	end)
end)
