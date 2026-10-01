local wow = require("tests.mock.wow")

local ns, calls, anchorShown, demo

local function Load(saved)
	wow.reset()
	_G.LootBeaconOptions = saved
	calls, anchorShown, demo = {}, false, false
	local function Track(name)
		return function() calls[#calls + 1] = name end
	end
	ns = wow.loadAddon({ "locale.lua", "config.lua", "core.lua" }, {
		Bars = {
			Init = Track("Bars.Init"),
			Refresh = Track("Bars.Refresh"),
			IsAnchorShown = function() return anchorShown end,
			SetAnchorShown = function(value)
				anchorShown = value
				calls[#calls + 1] = "Bars.SetAnchorShown:" .. tostring(value)
			end,
			IsDemo = function() return demo end,
			SetDemo = function(value, count)
				demo = value
				calls[#calls + 1] = "Bars.SetDemo:" .. tostring(value) .. (count and ":" .. count or "")
			end,
		},
		Chat = { Init = Track("Chat.Init"), Refresh = Track("Chat.Refresh") },
	})
	wow.fireAddonLoaded()
end

describe("option validation", function()
	before_each(function() Load() end)

	it("starts from the defaults when nothing was saved", function()
		local options = ns.ValidateOptions(nil)
		assert.same({
			barsEnabled = true, scale = 1, growDirection = "down", summariesEnabled = true, chatWindow = 0,
			anchor = { x = 0, y = 200 },
		}, options)
		assert.are_not.equal(ns.defaults.anchor, options.anchor)
	end)

	it("replaces values of the wrong type", function()
		local options = ns.ValidateOptions({ barsEnabled = "yes", scale = "big", summariesEnabled = 1 })
		assert.is_true(options.barsEnabled)
		assert.equals(1, options.scale)
		assert.is_true(options.summariesEnabled)
	end)

	it("resets a stack direction it doesn't recognise", function()
		assert.equals("down", ns.ValidateOptions({ growDirection = "sideways" }).growDirection)
		assert.equals("up", ns.ValidateOptions({ growDirection = "up" }).growDirection)
	end)

	it("keeps the scale between 0.5 and 2", function()
		assert.equals(2, ns.ValidateOptions({ scale = 5 }).scale)
		assert.equals(0.5, ns.ValidateOptions({ scale = 0.1 }).scale)
		assert.equals(1, ns.ValidateOptions({ scale = 0 / 0 }).scale)
		assert.equals(1.25, ns.ValidateOptions({ scale = 1.25 }).scale)
	end)

	it("only accepts a real chat window number", function()
		assert.equals(0, ns.ValidateOptions({ chatWindow = 3.5 }).chatWindow)
		assert.equals(0, ns.ValidateOptions({ chatWindow = 11 }).chatWindow)
		assert.equals(0, ns.ValidateOptions({ chatWindow = -1 }).chatWindow)
		assert.equals(3, ns.ValidateOptions({ chatWindow = 3 }).chatWindow)
	end)

	it("resets an anchor that's missing pieces", function()
		assert.same({ x = 0, y = 200 }, ns.ValidateOptions({ anchor = {} }).anchor)
		assert.same({ x = 1, y = 2 }, ns.ValidateOptions({ anchor = { x = 1, y = 2 } }).anchor)
	end)

	it("resets an anchor saved in the old point-based format", function()
		assert.same({ x = 0, y = 200 },
			ns.ValidateOptions({ anchor = { point = "TOP", relativePoint = "TOP", x = 0, y = -180 } }).anchor)
	end)
end)

describe("settings panel", function()
	it("cleans up the saved options when the addon loads", function()
		Load({ scale = 9, growDirection = "up" })
		assert.equals(2, LootBeaconOptions.scale)
		assert.equals("up", LootBeaconOptions.growDirection)
	end)

	it("starts the bars and chat exactly once", function()
		Load()
		assert.same({ "Bars.Init", "Chat.Init" }, calls)
	end)

	it("refreshes the bars whenever a bar setting changes", function()
		Load()
		calls = {}
		wow.settings.LOOTBEACON_BARS_ENABLED:SetValue(false)
		wow.settings.LOOTBEACON_SCALE:SetValue(1.5)
		wow.settings.LOOTBEACON_GROW_DIRECTION:SetValue("up")
		assert.same({ "Bars.Refresh", "Bars.Refresh", "Bars.Refresh" }, calls)
		assert.is_false(LootBeaconOptions.barsEnabled)
		assert.equals(1.5, LootBeaconOptions.scale)
	end)

	it("refreshes chat when summaries are toggled", function()
		Load()
		calls = {}
		wow.settings.LOOTBEACON_SUMMARIES_ENABLED:SetValue(false)
		assert.same({ "Chat.Refresh" }, calls)
	end)

	it("lists every named chat window, fresh each time the dropdown opens", function()
		Load()
		assert.same({
			{ value = 0, label = "Automatic" },
			{ value = 1, label = "General" },
			{ value = 2, label = "Combat Log" },
			{ value = 3, label = "Loot" },
		}, wow.dropdowns.LOOTBEACON_CHAT_WINDOW())
		wow.chatWindowNames[3] = "Rolls"
		assert.equals("Rolls", wow.dropdowns.LOOTBEACON_CHAT_WINDOW()[4].label)
	end)

	it("shows the anchor from the Move bars button", function()
		Load()
		wow.buttons["Move bars"].click()
		assert.equals("Bars.SetAnchorShown:true", calls[#calls])
	end)

	it("registers the category with Blizzard's settings", function()
		Load()
		assert.equals("LootBeacon", wow.registeredCategory.name)
	end)
end)

describe("slash command", function()
	before_each(function() Load() end)

	it("registers /lootbeacon and /lb", function()
		assert.equals("/lootbeacon", SLASH_LOOTBEACON1)
		assert.equals("/lb", SLASH_LOOTBEACON2)
	end)

	it("opens the settings panel with no arguments", function()
		SlashCmdList.LOOTBEACON("")
		assert.same({ { "LootBeacon" } }, wow.calls.OpenToCategory)
	end)

	it("toggles the anchor", function()
		SlashCmdList.LOOTBEACON("move")
		SlashCmdList.LOOTBEACON("  MOVE  ")
		assert.same({ "Bars.Init", "Chat.Init", "Bars.SetAnchorShown:true", "Bars.SetAnchorShown:false" }, calls)
	end)

	it("toggles sample bars and says how to hide them", function()
		SlashCmdList.LOOTBEACON("test")
		assert.is_true(demo)
		assert.truthy(wow.printed[1]:find("Type /lb test again", 1, true))
		SlashCmdList.LOOTBEACON("test")
		assert.is_false(demo)
		assert.equals(1, #wow.printed)
	end)

	it("shows the number of sample bars you ask for", function()
		SlashCmdList.LOOTBEACON("test 2")
		assert.is_true(demo)
		SlashCmdList.LOOTBEACON("test 7")
		assert.is_true(demo)
		assert.same({ "Bars.Init", "Chat.Init", "Bars.SetDemo:true:2", "Bars.SetDemo:true:7" }, calls)
		assert.equals(2, #wow.printed)
		SlashCmdList.LOOTBEACON("test")
		assert.is_false(demo)
	end)
end)
