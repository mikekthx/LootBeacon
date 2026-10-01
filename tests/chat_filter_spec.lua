local wow = require("tests.mock.wow")

local ns

local function Load(saved)
	wow.reset()
	_G.LootBeaconOptions = saved
	ns = wow.loadAddon({ "locale.lua", "config.lua", "core.lua", "chat.lua" }, {
		Bars = { Init = function() end, Refresh = function() end },
	})
	wow.fireAddonLoaded()
end

describe("roll-message patterns", function()
	before_each(function() Load() end)

	it("turns a plain format string into an anchored pattern", function()
		assert.equals("^(.+) won: (.+)$", ns.Chat.BuildPattern("%s won: %s"))
	end)

	it("escapes Lua's magic characters", function()
		assert.equals("^Need Roll %- (%d+) for (.+) by (.+) %+ Role Bonus$",
			ns.Chat.BuildPattern("Need Roll - %d for %s by %s + Role Bonus"))
	end)

	it("understands the positional tokens translated strings use", function()
		local pattern = ns.Chat.BuildPattern("%2$s: Wurf %1$d (%3$s)")
		assert.equals("^(.+): Wurf (%d+) %((.+)%)$", pattern)
		assert.truthy(("Alpha: Wurf 42 ([Ring])"):find(pattern))
	end)

	it("skips missing or empty strings", function()
		assert.is_nil(ns.Chat.BuildPattern(nil))
		assert.is_nil(ns.Chat.BuildPattern(""))
	end)
end)

describe("roll spam", function()
	before_each(function() Load() end)

	it("hides every line that starts with Blizzard's loot history link", function()
		assert.is_true(ns.Chat.IsRollSpam(LOOT_ROLL_STARTED:format(128897282, "[Wand]")))
		assert.is_true(ns.Chat.IsRollSpam(LOOT_ROLL_GREED:format(128897282, "Alpha", "[Wand]")))
		assert.is_true(ns.Chat.IsRollSpam(LOOT_ROLL_YOU_WON:format(128897282, "[Wand]")))
	end)

	it("hides the roll lines Blizzard prints without that link", function()
		assert.is_true(ns.Chat.IsRollSpam(LOOT_ROLL_PASSED_AUTO:format("Alpha", "[Wand]")))
		assert.is_true(ns.Chat.IsRollSpam(LOOT_ROLL_PASSED_AUTO_FEMALE:format("Delta", "[Wand]")))
		assert.is_true(ns.Chat.IsRollSpam(LOOT_ROLL_DISENCHANT:format("Alpha", "[Wand]")))
		assert.is_true(ns.Chat.IsRollSpam(LOOT_ROLL_ROLLED_DE:format(55, "[Wand]", "Bravo")))
		assert.is_true(ns.Chat.IsRollSpam(LOOT_ROLL_ROLLED_NEED_ROLE_BONUS:format(80, "[Wand]", "Bravo")))
	end)

	it("leaves loot-received lines alone", function()
		assert.is_false(ns.Chat.IsRollSpam(LOOT_ITEM:format("Alpha-Realm", "[Wand]")))
		assert.is_false(ns.Chat.IsRollSpam(LOOT_ITEM_SELF:format("[Wand]")))
		assert.is_false(ns.Chat.IsRollSpam(nil))
	end)

	it("keeps a line that only mentions a roll link part-way through", function()
		assert.is_false(ns.Chat.IsRollSpam("Bravo says: " .. LOOT_ROLL_STARTED:format(1, "[Wand]")))
	end)
end)

describe("loot chat filter", function()
	it("filters only while roll summaries are on, and never twice", function()
		Load()
		local spam = LOOT_ROLL_STARTED:format(1, "[Wand]")
		assert.is_true(wow.runChatFilters("CHAT_MSG_LOOT", spam))
		wow.settings.LOOTBEACON_SUMMARIES_ENABLED:SetValue(false)
		assert.is_false(wow.runChatFilters("CHAT_MSG_LOOT", spam))
		wow.settings.LOOTBEACON_SUMMARIES_ENABLED:SetValue(true)
		wow.settings.LOOTBEACON_SUMMARIES_ENABLED:SetValue(true)
		assert.equals(1, #wow.filters.CHAT_MSG_LOOT)
	end)

	it("starts with no filter when summaries were saved off", function()
		Load({ summariesEnabled = false })
		assert.equals(0, #(wow.filters.CHAT_MSG_LOOT or {}))
	end)

	it("lets ordinary loot lines through", function()
		Load()
		assert.is_false(wow.runChatFilters("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format("[Wand]")))
	end)
end)

describe("output window", function()
	it("picks the first window that shows loot messages by default", function()
		Load()
		assert.equals(ChatFrame3, ns.Chat.GetOutputFrame())
	end)

	it("uses the window chosen in settings", function()
		Load({ chatWindow = 2 })
		assert.equals(ChatFrame2, ns.Chat.GetOutputFrame())
	end)

	it("falls back when the chosen window has been closed", function()
		Load({ chatWindow = 5 })
		assert.equals(ChatFrame3, ns.Chat.GetOutputFrame())
	end)

	it("falls back to the main chat frame when no window shows loot", function()
		Load()
		ChatFrame3.messageTypeList = { "SAY" }
		assert.equals(DEFAULT_CHAT_FRAME, ns.Chat.GetOutputFrame())
	end)
end)
