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

describe("a roll row", function()
	before_each(function() Load() end)

	it("shows the item name and a quality border like the character sheet", function()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ name = "Ephemeral Choker", quality = 3, bop = true }))
		local bar = BarFor(500)
		assert.is_true(bar:IsShown())
		assert.equals("Ephemeral Choker", bar.name:GetText())
		local calls = wow.calls.SetItemButtonQuality
		assert.same({ bar.icon, 3, "|cnIQ2:|Hitem:2073|h[Test Item]|h|r" }, calls[#calls])
	end)

	it("marks Bind on Pickup items with BoP in the icon's corner", function()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ bop = true }))
		local bind = BarFor(500).icon.bind
		assert.is_true(bind:IsShown())
		assert.equals("BoP", bind:GetText())
		assert.equals("BOTTOMLEFT", (bind:GetPoint(1)))
	end)

	it("shows no tag on items that aren't Bind on Pickup", function()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ name = "Shadow Wand", bop = false }))
		assert.is_false(BarFor(500).icon.bind:IsShown())
		assert.equals("Shadow Wand", BarFor(500).name:GetText())
	end)

	it("greys out Need with Blizzard's reason when you can't need", function()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ canNeed = false, reasonNeed = 1 }))
		local need = BarFor(500).buttons.need
		assert.is_false(need:IsEnabled())
		assert.equals(0.35, need:GetAlpha())
		assert.equals(LOOT_ROLL_INELIGIBLE_REASON1, need.reason)
	end)

	it("never offers Transmog", function()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ canTransmog = true }))
		local buttons = BarFor(500).buttons
		assert.is_nil(buttons.transmog)
		assert.is_true(buttons.greed:IsShown())
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

	it("keeps each count inside its own button", function()
		wow.startRoll(1, 500, 60000)
		local count = BarFor(500).buttons.pass.count
		local point, relativeTo, relativePoint, x, y = count:GetPoint(1)
		assert.equals("BOTTOMRIGHT", point)
		assert.equals(BarFor(500).buttons.pass, relativeTo)
		assert.equals("BOTTOMRIGHT", relativePoint)
		assert.is_true(x <= 0 and y >= 0)
	end)

	it("waits on item info with only Pass usable, and leaves cleanly", function()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ pending = true }))
		local bar = BarFor(500)
		assert.equals(RETRIEVING_ITEM_INFO, bar.name:GetText())
		assert.is_false(bar.icon.bind:IsShown())
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

describe("the roll panel", function()
	it("lists rolls under its title, oldest first, when stacking down", function()
		Load()
		wow.startRoll(1, 500, 60000)
		wow.advance(1)
		wow.startRoll(2, 501, 60000)
		assert.same({ "TOPLEFT", ns.Bars._panel, "TOPLEFT", 16, -8 }, BarFor(500)._points[1])
		assert.same({ "TOPLEFT", BarFor(500), "BOTTOMLEFT", 0, -8 }, BarFor(501)._points[1])
	end)

	it("puts the newest roll on top when stacking up", function()
		Load({ growDirection = "up" })
		wow.startRoll(1, 500, 60000)
		wow.advance(1)
		wow.startRoll(2, 501, 60000)
		assert.same({ "TOPLEFT", ns.Bars._panel, "TOPLEFT", 16, -8 }, BarFor(501)._points[1])
		assert.same({ "TOPLEFT", BarFor(501), "BOTTOMLEFT", 0, -8 }, BarFor(500)._points[1])
	end)

	it("hides the divider under the last row only", function()
		Load()
		wow.startRoll(1, 500, 60000)
		wow.advance(1)
		wow.startRoll(2, 501, 60000)
		assert.is_true(BarFor(500).divider:IsShown())
		assert.is_false(BarFor(501).divider:IsShown())
	end)

	it("fits itself to its rolls and hides when there are none", function()
		Load()
		local panel = ns.Bars._panel
		assert.is_false(panel:IsShown())
		wow.startRoll(1, 500, 60000)
		wow.advance(1)
		wow.startRoll(2, 501, 60000)
		assert.is_true(panel:IsShown())
		assert.equals(8 + 2 * 39 + 8 + 8, panel:GetHeight())
		wow.cancelRoll(1)
		wow.cancelRoll(2)
		assert.is_false(panel:IsShown())
	end)

	it("is titled like Blizzard's Loot Rolls window", function()
		Load()
		assert.equals(LOOT_ROLLS, ns.Bars._panel._title)
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
		local panel = ns.Bars._panel
		wow.gamepad = true
		panel:GetScript("OnUpdate")(panel, 0.1)
		assert.is_nil(BarFor(500))
		wow.gamepad = false
		GroupLootContainer_AddRoll(1, 60000) -- what Blizzard's RefreshRolls does on the way back
		assert.is_not_nil(BarFor(500))
		assert.is_nil(wow.calls.GroupLootContainer_AddRoll)
	end)
end)
