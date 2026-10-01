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
		assert.equals(98, bar.timer.fill:GetWidth())
	end)
end)

describe("moving the panel and sample rolls", function()
	local function Panel() return ns.Bars._panel end

	local function PlacePanel(left, right, top, bottom)
		local panel = Panel()
		panel.GetLeft = function() return left end
		panel.GetRight = function() return right end
		panel.GetTop = function() return top end
		panel.GetBottom = function() return bottom end
	end

	it("unlocks with sample rolls and a drag hint, and right-clicking locks it again", function()
		Load()
		ns.Bars.SetAnchorShown(true)
		assert.is_true(ns.Bars.IsAnchorShown())
		assert.is_true(ns.Bars.IsDemo())
		assert.equals(4, #ns.Bars.GetShownRecords())
		assert.equals("LootBeacon: drag to move, right-click to lock", Panel()._title)
		Panel():GetScript("OnMouseUp")(Panel(), "RightButton")
		assert.is_false(ns.Bars.IsAnchorShown())
		assert.is_false(ns.Bars.IsDemo())
		assert.equals(0, #ns.Bars.GetShownRecords())
		assert.equals(LOOT_ROLLS, Panel()._title)
		assert.is_false(Panel():IsShown())
	end)

	it("ignores right-clicks while locked", function()
		Load()
		wow.startRoll(1, 500, 60000)
		Panel():GetScript("OnMouseUp")(Panel(), "RightButton")
		assert.is_true(Panel():IsShown())
	end)

	it("never rolls from a sample row", function()
		Load()
		ns.Bars.SetDemo(true)
		Click(ns.Bars.GetBar(ns.Bars.GetShownRecords()[1]).buttons.need)
		assert.is_nil(wow.calls.RollOnLoot)
		assert.truthy(wow.printed[1]:find("Sample roll", 1, true))
	end)

	it("shows the real item tooltip for a sample row", function()
		Load()
		ns.Bars.SetDemo(true)
		local icon = ns.Bars.GetBar(ns.Bars.GetShownRecords()[1]).icon
		icon:GetScript("OnEnter")(icon)
		assert.equals("item:2073", GameTooltip._hyperlink)
	end)

	it("shows sample rows even with the roll bars switched off", function()
		Load({ barsEnabled = false })
		ns.Bars.SetDemo(true)
		assert.equals(4, #ns.Bars.GetShownRecords())
	end)

	it("saves the top edge where the panel was dropped when stacking down", function()
		Load()
		PlacePanel(900, 1200, 800, 600)
		Panel():GetScript("OnDragStop")(Panel())
		assert.same({ x = 90, y = 260 }, LootBeaconOptions.anchor)
		assert.same({ "TOP", UIParent, "CENTER", 90, 260 }, Panel()._points[1])
	end)

	it("saves the bottom edge when stacking up", function()
		Load({ growDirection = "up" })
		PlacePanel(900, 1200, 800, 600)
		Panel():GetScript("OnDragStop")(Panel())
		assert.same({ x = 90, y = 60 }, LootBeaconOptions.anchor)
		assert.same({ "BOTTOM", UIParent, "CENTER", 90, 60 }, Panel()._points[1])
	end)

	it("puts the panel back where it was saved", function()
		Load({ anchor = { x = 50, y = 60 } })
		assert.same({ "TOP", UIParent, "CENTER", 50, 60 }, Panel()._points[1])
	end)

	it("keeps the pinned edge still when the scale changes", function()
		Load({ anchor = { x = 50, y = 60 } })
		wow.settings.LOOTBEACON_SCALE:SetValue(2)
		assert.equals(2, Panel():GetScale())
		assert.same({ "TOP", UIParent, "CENTER", 25, 30 }, Panel()._points[1])
	end)

	it("pins the bottom edge when stacking up", function()
		Load({ anchor = { x = 50, y = 60 }, growDirection = "up" })
		wow.settings.LOOTBEACON_SCALE:SetValue(0.5)
		assert.same({ "BOTTOM", UIParent, "CENTER", 100, 120 }, Panel()._points[1])
	end)

	it("doesn't move the panel when the stacking direction flips", function()
		Load({ anchor = { x = 0, y = 200 } })
		ns.Bars.SetDemo(true)
		local height = Panel():GetHeight()
		wow.settings.LOOTBEACON_GROW_DIRECTION:SetValue("up")
		assert.same({ x = 0, y = 200 - height }, LootBeaconOptions.anchor)
		assert.same({ "BOTTOM", UIParent, "CENTER", 0, 200 - height }, Panel()._points[1])
		wow.settings.LOOTBEACON_GROW_DIRECTION:SetValue("down")
		assert.same({ x = 0, y = 200 }, LootBeaconOptions.anchor)
	end)

	it("brings a panel that ended up off screen back to the default spot", function()
		Load({ anchor = { x = 5000, y = 5000 } }, function()
			ns.Bars._panel.GetRect = function() return 5000, 5000, 320, 82 end
		end)
		assert.same({ x = 0, y = 200 }, LootBeaconOptions.anchor)
		assert.same({ "TOP", UIParent, "CENTER", 0, 200 }, Panel()._points[1])
	end)
end)

describe("sample rolls", function()
	local function Links()
		local links = {}
		for _, record in ipairs(ns.Bars.GetShownRecords()) do links[#links + 1] = record.link end
		return links
	end

	it("show four real items, from a plain drop up to a legendary", function()
		Load()
		ns.Bars.SetDemo(true)
		assert.same({ "item:2073", "item:13136", "item:873", "item:19019" }, Links())
		local records = ns.Bars.GetShownRecords()
		assert.same({ "Dwarven Hatchet of the Bear", "Lil Timmy's Peashooter", "Staff of Jordan",
			"Thunderfury, Blessed Blade of the Windseeker" },
			{ records[1].name, records[2].name, records[3].name, records[4].name })
		assert.same({ 2, 3, 4, 5 }, { records[1].quality, records[2].quality, records[3].quality, records[4].quality })
		assert.same({ false, false, false, true },
			{ records[1].bindOnPickUp, records[2].bindOnPickUp, records[3].bindOnPickUp, records[4].bindOnPickUp })
		assert.equals("Interface\\Icons\\INV_Sword_39", records[4].texture)
	end)

	it("show however many you ask for, cycling through the items", function()
		Load()
		ns.Bars.SetDemo(true, 2)
		assert.same({ "item:2073", "item:13136" }, Links())
		ns.Bars.SetDemo(true, 6)
		assert.same({ "item:2073", "item:13136", "item:873", "item:19019", "item:2073", "item:13136" }, Links())
		local records = ns.Bars.GetShownRecords()
		assert.are_not.equal(records[1], records[5])
		assert.are_not.equal(ns.Bars.GetBar(records[1]), ns.Bars.GetBar(records[5]))
	end)

	it("keep the count sensible", function()
		Load()
		ns.Bars.SetDemo(true, 0)
		assert.equals(1, #ns.Bars.GetShownRecords())
		ns.Bars.SetDemo(true, 500)
		assert.equals(20, #ns.Bars.GetShownRecords())
	end)
end)
