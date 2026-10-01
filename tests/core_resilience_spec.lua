local wow = require("tests.mock.wow")

local State = { Greed = 3 }
local ns, events

local function Load()
	wow.reset()
	ns = wow.loadAddon({ "locale.lua", "config.lua", "core.lua" })
	events = {}
	for _, name in ipairs({ "Started", "Updated", "Closed", "Resolved", "TimedOut" }) do
		ns.Tracker:RegisterCallback(name, function(record)
			events[#events + 1] = name .. ":" .. tostring(record.key)
		end)
	end
end

local function Count(prefix)
	local n = 0
	for _, event in ipairs(events) do
		if event:sub(1, #prefix) == prefix then n = n + 1 end
	end
	return n
end

local function Win(key, encounterID)
	local winner = wow.RollInfo("Echo", "HUNTER", State.Greed, 92, true)
	wow.setDrop(encounterID, wow.Drop(key, { winner = winner, rollInfos = { winner } }))
	wow.fire("LOOT_HISTORY_UPDATE_DROP", encounterID, key)
end

describe("item info that isn't cached yet", function()
	before_each(Load)

	it("keeps asking until it arrives, then fills the record in", function()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ pending = true }))
		local record = ns.Tracker:GetRecord(500)
		assert.is_true(record.pending)
		wow.advance(0.5)
		assert.is_true(record.pending)
		wow.rolls[1].info = wow.ItemInfo({ name = "Late Arrival" })
		wow.advance(0.5)
		assert.is_false(record.pending)
		assert.equals("Late Arrival", record.name)
		assert.equals("Updated:500", events[#events])
	end)

	it("stops asking once you've rolled", function()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ pending = true }))
		wow.cancelRoll(1)
		wow.rolls[1].info = wow.ItemInfo({ name = "Too Late" })
		wow.advance(5)
		local record = ns.Tracker:GetRecord(500)
		assert.is_true(record.pending)
		assert.is_nil(record.name)
		assert.equals("Closed:500", events[#events])
	end)

	it("stops asking when the roll runs out of time", function()
		wow.startRoll(1, 500, 1000, wow.ItemInfo({ pending = true }))
		wow.advance(1.5)
		wow.rolls[1].info = wow.ItemInfo({ name = "Too Late" })
		wow.advance(2)
		assert.is_true(ns.Tracker:GetRecord(500).pending)
	end)
end)

describe("watchdog", function()
	before_each(Load)

	it("gives up after the roll time plus 15 seconds, but still reports a late result once", function()
		wow.startRoll(1, 500, 60000)
		wow.advance(74)
		assert.equals(0, Count("TimedOut"))
		wow.advance(2)
		assert.equals(1, Count("TimedOut"))
		assert.is_true(ns.Tracker:GetRecord(500).timedOut)
		Win(500, 0)
		wow.fire("LOOT_HISTORY_UPDATE_DROP", 0, 500)
		assert.equals(1, Count("Resolved"))
		wow.advance(100)
		assert.equals(1, Count("TimedOut"))
	end)

	it("never fires for a roll that resolved in time", function()
		wow.startRoll(1, 500, 60000)
		wow.advance(10)
		Win(500, 0)
		wow.advance(100)
		assert.equals(0, Count("TimedOut"))
	end)
end)

describe("record lifetime", function()
	before_each(Load)

	it("forgets a resolved roll a minute later", function()
		wow.startRoll(1, 500, 60000)
		Win(500, 0)
		wow.advance(59)
		assert.is_not_nil(ns.Tracker:GetRecord(500))
		wow.advance(2)
		assert.is_nil(ns.Tracker:GetRecord(500))
	end)

	it("keeps a timed-out roll around for five minutes in case the result turns up", function()
		wow.startRoll(1, 500, 60000)
		wow.advance(76) -- timed out at 75s, forgotten 300s after that
		wow.advance(298)
		assert.is_not_nil(ns.Tracker:GetRecord(500))
		wow.advance(2)
		assert.is_nil(ns.Tracker:GetRecord(500))
	end)
end)

describe("after a /reload in the middle of a roll", function()
	local link = "|cnIQ3:|Hitem:270227|h[Ephemeral Choker]|h|r"

	before_each(function()
		Load()
		wow.addRoll(5, 60000, wow.ItemInfo(), link) -- ends at 1,060,000 ms
		wow.advance(5)
		wow.addRoll(6, 60000, wow.ItemInfo(), link) -- ends at 1,065,000 ms
		wow.setDrop(3493, wow.Drop(800, { link = link, startTime = 1005000, duration = 60000 }))
		wow.setDrop(3493, wow.Drop(801, { link = link, startTime = 1000000, duration = 60000 }))
		wow.advance(10)
	end)

	it("matches two identical items to their own history entries by end time", function()
		wow.fire("PLAYER_ENTERING_WORLD", false, true)
		assert.equals(6, ns.Tracker:GetRecord(800).rollID)
		assert.equals(5, ns.Tracker:GetRecord(801).rollID)
		assert.equals(3493, ns.Tracker:GetRecord(801).encounterID)
		assert.equals(60000, ns.Tracker:GetRecord(801).duration)
	end)

	it("times the watchdog from the time left, not the full roll", function()
		wow.fire("PLAYER_ENTERING_WORLD", false, true)
		wow.advance(59)
		assert.equals(0, Count("TimedOut"))
		wow.advance(2)
		assert.same({ "TimedOut:801" }, (function()
			local list = {}
			for _, event in ipairs(events) do
				if event:find("^TimedOut") then list[#list + 1] = event end
			end
			return list
		end)())
	end)

	it("doesn't create the same roll twice", function()
		wow.fire("PLAYER_ENTERING_WORLD", false, true)
		wow.fire("PLAYER_ENTERING_WORLD", false, false)
		assert.equals(2, Count("Started"))
	end)
end)

describe("reload recovery edge cases", function()
	before_each(Load)

	it("never matches a history entry that already has a winner", function()
		local link = "|cnIQ2:|Hitem:5071|h[Shadow Wand]|h|r"
		wow.addRoll(5, 60000, wow.ItemInfo(), link)
		wow.setDrop(0, wow.Drop(900, { link = link, startTime = 1000000, winner = wow.RollInfo("Alpha", "MAGE", 3, 50, true) }))
		wow.fire("PLAYER_ENTERING_WORLD", false, true)
		assert.is_nil(ns.Tracker:GetRecord(900))
		assert.is_not_nil(ns.Tracker:GetRecord("roll:5"))
	end)

	it("still tracks a roll it can't match, just without history", function()
		wow.addRoll(7, 60000, wow.ItemInfo({ name = "Mystery" }))
		wow.fire("PLAYER_ENTERING_WORLD", false, true)
		local record = ns.Tracker:GetRecord("roll:7")
		assert.equals("Mystery", record.name)
		assert.is_nil(record.encounterID)
		assert.equals("Started:roll:7", events[1])
	end)

	it("leaves alone rolls it already tracks", function()
		wow.startRoll(1, 500, 60000)
		wow.fire("PLAYER_ENTERING_WORLD", false, false)
		assert.equals(1, Count("Started"))
	end)
end)
