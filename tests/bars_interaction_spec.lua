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
	local function Field(name)
		local values = {}
		for index, record in ipairs(ns.Bars.GetShownRecords()) do values[index] = record[name] end
		return values
	end

	it("are just item IDs, filled in from the game's own item data", function()
		Load()
		ns.Bars.SetDemo(true)
		assert.same({ 2073, 13136, 873, 19019 }, Field("itemID"))
		assert.same({ "Dwarven Hatchet of the Bear", "Lil Timmy's Peashooter", "Staff of Jordan",
			"Thunderfury, Blessed Blade of the Windseeker" }, Field("name"))
		assert.same({ 2, 3, 4, 5 }, Field("quality"))
		assert.same({ 132395, 135617, 135157, 135349 }, Field("texture"))
		assert.same({ false, false, false, true }, Field("bindOnPickUp"))
		assert.equals("|cnIQ5:|Hitem:19019|h[Thunderfury, Blessed Blade of the Windseeker]|h|r", Field("link")[4])
		assert.same({ false, false, false, false }, Field("pending"))
	end)

	it("let you Need on everything, and offer Disenchant on the staff", function()
		Load()
		ns.Bars.SetDemo(true)
		for _, record in ipairs(ns.Bars.GetShownRecords()) do
			assert.is_true(ns.Bars.GetBar(record).buttons.need:IsEnabled())
		end
		assert.same({ false, false, true, false }, Field("canDisenchant"))
	end)

	it("wait for items the client hasn't seen yet", function()
		Load()
		wow.uncachedItems[19019] = true
		ns.Bars.SetDemo(true)
		local record = ns.Bars.GetShownRecords()[4]
		local bar = ns.Bars.GetBar(record)
		assert.is_true(record.pending)
		assert.equals(RETRIEVING_ITEM_INFO, bar.name:GetText())
		assert.same({ { 19019 } }, wow.calls.RequestLoadItemDataByID)
		wow.loadItem(19019)
		assert.is_false(record.pending)
		assert.equals("Thunderfury, Blessed Blade of the Windseeker", bar.name:GetText())
		assert.is_true(bar.icon.bind:IsShown())
	end)

	it("shrug off item data that arrives after they're gone", function()
		Load()
		wow.uncachedItems[19019] = true
		ns.Bars.SetDemo(true)
		ns.Bars.SetDemo(false)
		wow.loadItem(19019)
		assert.equals(0, #ns.Bars.GetShownRecords())
	end)

	it("show however many you ask for, cycling through the items", function()
		Load()
		ns.Bars.SetDemo(true, 2)
		assert.same({ 2073, 13136 }, Field("itemID"))
		ns.Bars.SetDemo(true, 6)
		assert.same({ 2073, 13136, 873, 19019, 2073, 13136 }, Field("itemID"))
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
