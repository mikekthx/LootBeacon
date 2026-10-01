local wow = require("tests.mock.wow")

local State = { NeedMainSpec = 0, Greed = 3, Pass = 5 }
local ns

local function Load(saved)
	wow.reset()
	_G.LootBeaconOptions = saved
	ns = wow.loadAddon({ "locale.lua", "config.lua", "core.lua", "chat.lua" }, {
		Bars = { Init = function() end, Refresh = function() end },
	})
	wow.fireAddonLoaded()
end

local function Win(key, encounterID, name, class, state, roll)
	local winner = wow.RollInfo(name, class, state, roll, true)
	wow.setDrop(encounterID, wow.Drop(key, { winner = winner, rollInfos = { winner } }))
	wow.fire("LOOT_HISTORY_UPDATE_DROP", encounterID, key)
end

describe("summary text", function()
	before_each(function() Load() end)

	it("names the winner, their roll and the item", function()
		local record = { key = 128897282, encounterID = 0, link = "[Simple Branch of Intellect]",
			winner = wow.RollInfo("Echo", "HUNTER", State.Greed, 92, true) }
		assert.equals("|cffffff00|Haddon:LootBeacon:0:128897282|h[Greed - 92]|h|r <HUNTER>Echo won [Simple Branch of Intellect]",
			ns.Chat.FormatSummary(record))
	end)

	it("colors Need wins red", function()
		local record = { key = 128929538, encounterID = 3496, link = "[Durgen's Crescent Axe]",
			winner = wow.RollInfo("Echo", "HUNTER", State.NeedMainSpec, 66, true) }
		assert.equals("|cffff2020|Haddon:LootBeacon:3496:128929538|h[Need - 66]|h|r <HUNTER>Echo won [Durgen's Crescent Axe]",
			ns.Chat.FormatSummary(record))
	end)

	it("says when everyone passed", function()
		local record = { key = 9, encounterID = 3494, link = "[Treads]", allPassed = true }
		assert.equals("|cff9d9d9d|Haddon:LootBeacon:3494:9|h[All Passed]|h|r [Treads]", ns.Chat.FormatSummary(record))
	end)

	it("points a timeout at Blizzard's own loot history link", function()
		assert.equals("|cff9d9d9d|HlootHistory:500|h[Roll result unavailable]|h|r [Wand]",
			ns.Chat.FormatTimeout({ key = 500, link = "[Wand]" }))
	end)

	it("drops the link from a timeout when the roll was never matched", function()
		assert.equals("[Roll result unavailable] [Wand]", ns.Chat.FormatTimeout({ key = "roll:7", link = "[Wand]" }))
	end)
end)

describe("printing summaries", function()
	it("prints one line to the output window when a roll is decided", function()
		Load()
		wow.startRoll(1, 500, 60000, nil, "[Wand]")
		Win(500, 0, "Echo", "HUNTER", State.Greed, 92)
		wow.fire("LOOT_HISTORY_UPDATE_DROP", 0, 500)
		assert.equals(1, #ChatFrame3._messages)
		assert.truthy(ChatFrame3._messages[1]:find("[Greed - 92]", 1, true))
	end)

	it("prints the fallback line when the watchdog gives up", function()
		Load()
		wow.startRoll(1, 500, 60000, nil, "[Wand]")
		wow.advance(76)
		assert.equals(1, #ChatFrame3._messages)
		assert.truthy(ChatFrame3._messages[1]:find("Roll result unavailable", 1, true))
	end)

	it("stays quiet if summaries are switched off before the roll finishes", function()
		Load()
		wow.startRoll(1, 500, 60000, nil, "[Wand]")
		wow.settings.LOOTBEACON_SUMMARIES_ENABLED:SetValue(false)
		Win(500, 0, "Echo", "HUNTER", State.Greed, 92)
		assert.equals(0, #ChatFrame3._messages)
		assert.is_false(wow.runChatFilters("CHAT_MSG_LOOT", LOOT_ROLL_STARTED:format(500, "[Wand]")))
	end)
end)

describe("clicking a summary link", function()
	before_each(function()
		Load()
		local winner = wow.RollInfo("Alpha", "MAGE", State.NeedMainSpec, 71, true)
		wow.setDrop(3493, wow.Drop(500, {
			link = "|cnIQ3:|Hitem:270227|h[Ephemeral Choker]|h|r",
			winner = winner,
			rollInfos = {
				winner,
				wow.RollInfo("Bravo", "ROGUE", State.NeedMainSpec, 71),
				wow.RollInfo("Echo", "HUNTER", State.Pass),
			},
		}))
	end)

	it("shows everyone's rolls, with the winner checked and passes grouped", function()
		wow.clickLink("addon:LootBeacon:3493:500")
		assert.is_true(ItemRefTooltip:IsShown())
		assert.same({
			"|cnIQ3:Ephemeral Choker|r",
			"|A:lootroll-icon-need:14:14|a 71  <MAGE>Alpha |A:lootroll-icon-checkmark:14:14|a",
			"|A:lootroll-icon-need:14:14|a 71  <ROGUE>Bravo",
			"Passed",
			"|A:lootroll-icon-pass:14:14|a   <HUNTER>Echo",
		}, ItemRefTooltip._lines)
	end)

	it("closes the tooltip when the same link is clicked again", function()
		wow.clickLink("addon:LootBeacon:3493:500")
		wow.clickLink("addon:LootBeacon:3493:500")
		assert.is_false(ItemRefTooltip:IsShown())
	end)

	it("opens Blizzard's Loot Rolls window on shift-click", function()
		wow.shift = true
		wow.clickLink("addon:LootBeacon:3493:500")
		assert.same({ { 3493 } }, wow.calls.SetLootHistoryFrameToEncounter)
		assert.is_false(ItemRefTooltip:IsShown())
	end)

	it("says so when the roll details are gone", function()
		wow.clickLink("addon:LootBeacon:0:999")
		assert.same({ "Unknown", "Roll details are no longer available." }, ItemRefTooltip._lines)
	end)

	it("ignores links that aren't ours", function()
		wow.clickLink("item:2073")
		assert.is_false(ItemRefTooltip:IsShown())
		assert.is_nil(wow.calls.SetLootHistoryFrameToEncounter)
	end)
end)
