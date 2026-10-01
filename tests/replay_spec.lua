local wow = require("tests.mock.wow")

local FILES = { "locale.lua", "config.lua", "core.lua", "bars.lua", "chat.lua" }
local fixture = dofile("tests/fixtures/dungeon_run.lua")

-- The probe packed every API answer as {n = count, ok, values...}; "<nil>" stood in for nil.
local function Unpacked(packed, first)
	local values = {}
	for i = first, packed.n do
		local value = packed[i]
		if value == "<nil>" then value = nil end
		values[i - first + 1] = value
	end
	return values, packed.n - first + 1
end

local EXPECTED = {
	{ tag = "[Greed - 92]", name = "<HUNTER>Echo", item = "[Simple Branch of Intellect]" },
	{ tag = "[Greed - 94]", name = "<HUNTER>Echo", item = "[Dwarven Hatchet of the Bear]" },
	{ tag = "[Need - 71]", name = "<MAGE>Alpha", item = "[Ephemeral Choker]" },
	{ tag = "[Greed - 78]", name = "<DRUID>Charlie", item = "[Spellbinder Robe]" },
	{ tag = "[Greed - 96]", name = "<PALADIN>Delta", item = "[Shadowgem]" },
	{ tag = "[Greed - 99]", name = "<PALADIN>Delta", item = "[Shadow Wand]" },
	{ tag = "[Greed - 97]", name = "<PALADIN>Delta", item = "[Cadet Leggings of the Tiger]" },
	{ tag = "[Need - 60]", name = "<MAGE>Alpha", item = "[Fang of Magmatus]" },
	{ tag = "[Greed - 70]", name = "<PALADIN>Delta", item = "[Treads of the Protector Golem]" },
	{ tag = "[Greed - 97]", name = "<ROGUE>Bravo", item = "[Bard's Belt of the Wolf]" },
	{ tag = "[Need - 66]", name = "<HUNTER>Echo", item = "[Durgen's Crescent Axe]" },
}

describe("replaying a real Hall of Thanes run", function()
	local ns, counts, hidden, kept

	setup(function()
		wow.reset()
		ns = wow.loadAddon(FILES)
		wow.fireAddonLoaded()
		counts = { Started = 0, Closed = 0, Resolved = 0, TimedOut = 0 }
		for name in pairs(counts) do
			ns.Tracker:RegisterCallback(name, function() counts[name] = counts[name] + 1 end)
		end
		hidden, kept = {}, {}
		for _, entry in ipairs(fixture) do
			wow.advanceTo(entry.t)
			local data, kind = entry.data, entry.kind
			local args, n = Unpacked(data.args or { n = 0 }, 1)
			if kind == "START_LOOT_ROLL" then
				local info = Unpacked(data.roll.itemInfo, 2)
				local link = Unpacked(data.roll.itemLink, 2)[1]
				wow.addRoll(args[1], args[2], info, link)
				wow.fire(kind, unpack(args, 1, n))
			elseif kind == "LOOT_HISTORY_UPDATE_ENCOUNTER" then
				for _, drop in ipairs(Unpacked(data.drops, 2)[1] or {}) do
					wow.setDrop(args[1], drop)
				end
				wow.fire(kind, unpack(args, 1, n))
			elseif kind == "LOOT_HISTORY_UPDATE_DROP" then
				local drop = Unpacked(data.drop, 2)[1]
				if type(drop) == "table" then wow.setDrop(args[1], drop) end
				wow.fire(kind, unpack(args, 1, n))
			elseif kind == "CANCEL_LOOT_ROLL" then
				wow.cancelRoll(args[1])
			elseif kind == "CHAT_MSG_LOOT" then
				if wow.runChatFilters(kind, args[1]) then
					hidden[#hidden + 1] = args[1]
				else
					kept[#kept + 1] = args[1]
				end
			else
				wow.fire(kind, unpack(args, 1, n))
			end
		end
		wow.advance(600)
	end)

	it("follows every roll from start to finish", function()
		assert.same({ Started = 11, Closed = 11, Resolved = 11, TimedOut = 0 }, counts)
	end)

	it("prints exactly one correct summary per item, in the order they were decided", function()
		local messages = ChatFrame3._messages
		assert.equals(#EXPECTED, #messages)
		for index, expected in ipairs(EXPECTED) do
			local message = messages[index]
			assert.truthy(message:find(expected.tag .. "|h|r " .. expected.name .. " won ", 1, true), message)
			assert.truthy(message:find(expected.item, 1, true), message)
		end
	end)

	it("hides all 122 roll lines and keeps all 116 other loot lines", function()
		assert.equals(122, #hidden)
		assert.equals(116, #kept)
		for _, line in ipairs(hidden) do
			assert.equals(1, line:find("|HlootHistory:", 1, true))
		end
		for _, line in ipairs(kept) do
			assert.is_nil(line:find("|HlootHistory:", 1, true))
		end
	end)

	it("cleans up after itself", function()
		assert.same({}, ns.Tracker:GetOpenRecords())
		assert.equals(0, #ns.Bars.GetShownRecords())
	end)
end)
