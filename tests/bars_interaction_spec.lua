local wow = require("tests.mock.wow")

local State = { NeedMainSpec = 0 }
local FILES = { "locale.lua", "config.lua", "core.lua", "bars.lua", "chat.lua" }
local ns

local function Load(saved, beforeLoaded)
	wow.reset()
	_G.LootBeaconOptions = saved
	ns = wow.loadAddon(FILES)
	if beforeLoaded then beforeLoaded() end
	wow.fireAddonLoaded()
end

local function BarFor(key)
	return ns.Bars.GetBar(ns.Tracker:GetRecord(key))
end

local function Click(button)
	button:GetScript("OnClick")(button, "LeftButton")
end

describe("rolling from a bar", function()
	before_each(function()
		Load()
		wow.startRoll(1, 500, 60000)
	end)

	it("rolls the button's choice", function()
		Click(BarFor(500).buttons.need)
		assert.same({ { 1, 1 } }, wow.calls.RollOnLoot)
	end)

	it("skips the confirmation box on shift-click", function()
		wow.shift = true
		Click(BarFor(500).buttons.greed)
		assert.same({ { 1, 2 } }, wow.calls.RollOnLoot)
		wow.fire("CONFIRM_LOOT_ROLL", 1, 2, "")
		assert.same({ { 1, 2 } }, wow.calls.ConfirmLootRoll)
		assert.same({ "CONFIRM_LOOT_ROLL", 1 }, wow.calls.StaticPopup_Hide[1])
	end)

	it("passes normally even with shift held", function()
		wow.shift = true
		Click(BarFor(500).buttons.pass)
		assert.same({ { 1, 0 } }, wow.calls.RollOnLoot)
	end)
end)

describe("bar tooltips", function()
	before_each(function()
		Load()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ canNeed = false, reasonNeed = 1 }), "|cnIQ2:|Hitem:5071|h[Shadow Wand]|h|r")
		wow.setDrop(0, wow.Drop(500, { rollInfos = { wow.RollInfo("Alpha", "MAGE", State.NeedMainSpec) } }))
		wow.fire("LOOT_HISTORY_UPDATE_DROP", 0, 500)
	end)

	it("lists who picked a choice, why you can't, and the shift-click hint", function()
		local need = BarFor(500).buttons.need
		need:GetScript("OnEnter")(need)
		assert.same({ "Need", LOOT_ROLL_INELIGIBLE_REASON1, "<MAGE>Alpha", "Shift-click to skip the confirmation." },
			GameTooltip._lines)
	end)

	it("doesn't offer the shift-click hint on Pass", function()
		local pass = BarFor(500).buttons.pass
		pass:GetScript("OnEnter")(pass)
		assert.same({ "Pass" }, GameTooltip._lines)
	end)

	it("shows the item tooltip and handles modified clicks on the icon", function()
		local icon = BarFor(500).icon
		icon:GetScript("OnEnter")(icon)
		assert.equals(1, GameTooltip._lootRollItem)
		icon:GetScript("OnClick")(icon)
		assert.same({ { "|cnIQ2:|Hitem:5071|h[Shadow Wand]|h|r" } }, wow.calls.HandleModifiedItemClick)
	end)
end)

describe("roll timer", function()
	it("drains as the roll runs down", function()
		Load()
		wow.startRoll(1, 500, 60000)
		local bar = BarFor(500)
		bar.timer:SetWidth(200)
		wow.advance(30)
		bar:GetScript("OnUpdate")(bar, 0)
		assert.equals(100, bar.timer.fill:GetWidth())
	end)
end)

describe("anchor and sample bars", function()
	it("shows the anchor with three sample bars, and right-clicking locks both away", function()
		Load()
		ns.Bars.SetAnchorShown(true)
		assert.is_true(ns.Bars._anchor:IsShown())
		assert.is_true(ns.Bars.IsDemo())
		assert.equals(3, #ns.Bars.GetShownRecords())
		ns.Bars._anchor:GetScript("OnMouseUp")(ns.Bars._anchor, "RightButton")
		assert.is_false(ns.Bars._anchor:IsShown())
		assert.is_false(ns.Bars.IsDemo())
		assert.equals(0, #ns.Bars.GetShownRecords())
	end)

	it("never rolls from a sample bar", function()
		Load()
		ns.Bars.SetDemo(true)
		Click(ns.Bars.GetBar(ns.Bars.GetShownRecords()[1]).buttons.need)
		assert.is_nil(wow.calls.RollOnLoot)
		assert.truthy(wow.printed[1]:find("Sample roll", 1, true))
	end)

	it("shows the real item tooltip for a sample bar", function()
		Load()
		ns.Bars.SetDemo(true)
		local icon = ns.Bars.GetBar(ns.Bars.GetShownRecords()[1]).icon
		icon:GetScript("OnEnter")(icon)
		assert.equals("item:2073", GameTooltip._hyperlink)
	end)

	it("shows sample bars even with the roll bars switched off", function()
		Load({ barsEnabled = false })
		ns.Bars.SetDemo(true)
		assert.equals(3, #ns.Bars.GetShownRecords())
	end)

	it("saves where the anchor was dragged", function()
		Load()
		local root = ns.Bars._root
		root:ClearAllPoints()
		root:SetPoint("CENTER", UIParent, "CENTER", 12, 34)
		ns.Bars._anchor:GetScript("OnDragStop")(ns.Bars._anchor)
		assert.same({ point = "CENTER", relativePoint = "CENTER", x = 12, y = 34 }, LootBeaconOptions.anchor)
	end)

	it("puts the bars back where they were saved", function()
		Load({ anchor = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 50, y = 60 } })
		assert.same({ "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 50, 60 }, ns.Bars._root._points[1])
	end)

	it("brings an anchor that ended up off screen back to the default spot", function()
		Load({ anchor = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 5000, y = 5000 } }, function()
			ns.Bars._root.GetRect = function() return 5000, 5000, 300, 44 end
		end)
		assert.same({ point = "TOP", relativePoint = "TOP", x = 0, y = -180 }, LootBeaconOptions.anchor)
		assert.same({ "TOP", UIParent, "TOP", 0, -180 }, ns.Bars._root._points[1])
	end)

	it("applies a new scale right away", function()
		Load()
		wow.settings.LOOTBEACON_SCALE:SetValue(1.5)
		assert.equals(1.5, ns.Bars._root:GetScale())
	end)
end)
