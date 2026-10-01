local wow = require("tests.mock.wow")

local State = { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 }
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

local function Win(key, encounterID, name, class, state, roll)
	local winner = wow.RollInfo(name, class, state, roll, true)
	wow.setDrop(encounterID, wow.Drop(key, { winner = winner, rollInfos = { winner } }))
	wow.fire("LOOT_HISTORY_UPDATE_DROP", encounterID, key)
end

describe("roll tracker", function()
	before_each(Load)

	it("maps loot history states to button choices", function()
		assert.equals("need", ns.ChoiceForState(State.NeedMainSpec))
		assert.equals("need", ns.ChoiceForState(State.NeedOffSpec))
		assert.equals("transmog", ns.ChoiceForState(State.Transmog))
		assert.equals("greed", ns.ChoiceForState(State.Greed))
		assert.equals("pass", ns.ChoiceForState(State.Pass))
		assert.is_nil(ns.ChoiceForState(State.NoRoll))
		assert.is_nil(ns.ChoiceForState(9, false))
		assert.equals("disenchant", ns.ChoiceForState(9, true))
	end)

	it("uses RollOnLoot's own numbers for each choice", function()
		assert.same({ pass = 0, need = 1, greed = 2, disenchant = 3, transmog = 4 }, ns.ROLL)
	end)

	it("colors names by class", function()
		assert.equals("<MAGE>Alpha", ns.ClassColoredName("Alpha", "MAGE"))
		assert.equals("Alpha", ns.ClassColoredName("Alpha", nil))
	end)

	it("creates a record from the roll's item info when a roll starts", function()
		local link = "|cnIQ3:|Hitem:5071|h[Shadow Wand]|h|r"
		wow.setDrop(0, wow.Drop(500))
		wow.startRoll(1, 500, 60000,
			wow.ItemInfo({ name = "Shadow Wand", quality = 3, bop = true, canNeed = false, reasonNeed = 1 }), link)
		local record = ns.Tracker:GetRecord(500)
		assert.equals(1, record.rollID)
		assert.equals("Shadow Wand", record.name)
		assert.equals(3, record.quality)
		assert.is_true(record.bindOnPickUp)
		assert.is_false(record.canNeed)
		assert.equals(1, record.reasonNeed)
		assert.equals(link, record.link)
		assert.equals(0, record.encounterID)
		assert.equals(60000, record.duration)
		assert.equals("Started:500", events[1])
	end)

	it("finds the encounter when the history entry shows up after the roll starts", function()
		wow.startRoll(1, 600, 180000)
		assert.is_nil(ns.Tracker:GetRecord(600).encounterID)
		wow.setDrop(3493, wow.Drop(600))
		wow.fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 3493)
		assert.equals(3493, ns.Tracker:GetRecord(600).encounterID)
		assert.equals("Updated:600", events[#events])
	end)

	it("sorts each player's choice from the loot history", function()
		wow.startRoll(1, 500, 60000)
		wow.setDrop(0, wow.Drop(500, { rollInfos = {
			wow.RollInfo("Alpha", "MAGE", State.NeedMainSpec),
			wow.RollInfo("Bravo", "ROGUE", State.NeedOffSpec),
			wow.RollInfo("Charlie", "DRUID", State.Greed),
			wow.RollInfo("Delta", "PALADIN", State.Pass),
			wow.RollInfo("Echo", "HUNTER", State.NoRoll),
		} }))
		wow.fire("LOOT_HISTORY_UPDATE_DROP", 0, 500)
		local choices = ns.Tracker:GetRecord(500).choices
		assert.same({ { name = "Alpha", class = "MAGE" }, { name = "Bravo", class = "ROGUE" } }, choices.need)
		assert.same({ { name = "Charlie", class = "DRUID" } }, choices.greed)
		assert.same({ { name = "Delta", class = "PALADIN" } }, choices.pass)
		assert.same({}, choices.transmog)
	end)

	it("resolves exactly once when a winner appears", function()
		wow.startRoll(1, 500, 60000)
		Win(500, 0, "Echo", "HUNTER", State.Greed, 92)
		wow.fire("LOOT_HISTORY_UPDATE_DROP", 0, 500)
		assert.equals(1, Count("Resolved"))
		assert.equals("Echo", ns.Tracker:GetRecord(500).winner.playerName)
	end)

	it("resolves when everyone passes", function()
		wow.startRoll(1, 500, 60000)
		wow.setDrop(0, wow.Drop(500, { allPassed = true }))
		wow.fire("LOOT_HISTORY_UPDATE_DROP", 0, 500)
		assert.equals(1, Count("Resolved"))
		assert.is_true(ns.Tracker:GetRecord(500).allPassed)
	end)

	it("keeps following a roll after you've rolled on it", function()
		wow.startRoll(1, 500, 60000)
		wow.cancelRoll(1)
		assert.is_true(ns.Tracker:GetRecord(500).closed)
		assert.same({}, ns.Tracker:GetOpenRecords())
		assert.is_nil(ns.Tracker:GetRecordByRollID(1))
		Win(500, 0, "Echo", "HUNTER", State.Greed, 92)
		assert.equals(1, Count("Closed"))
		assert.equals(1, Count("Resolved"))
	end)

	it("closes every open roll when Blizzard cancels them all", function()
		wow.startRoll(1, 500, 60000)
		wow.startRoll(2, 501, 60000)
		wow.fire("CANCEL_ALL_LOOT_ROLLS")
		assert.equals(2, Count("Closed"))
		assert.same({}, ns.Tracker:GetOpenRecords())
	end)

	it("keeps two identical items from the same boss apart", function()
		local link = "|cnIQ3:|Hitem:270227|h[Ephemeral Choker]|h|r"
		wow.setDrop(3493, wow.Drop(700, { link = link }))
		wow.setDrop(3493, wow.Drop(701, { link = link }))
		wow.startRoll(1, 700, 180000, nil, link)
		wow.startRoll(2, 701, 180000, nil, link)
		wow.setDrop(3493, wow.Drop(701, { link = link, rollInfos = { wow.RollInfo("Alpha", "MAGE", State.NeedMainSpec) } }))
		wow.fire("LOOT_HISTORY_UPDATE_DROP", 3493, 701)
		assert.same({}, ns.Tracker:GetRecord(700).choices.need)
		assert.equals(1, #ns.Tracker:GetRecord(701).choices.need)
		Win(700, 3493, "Bravo", "ROGUE", State.NeedMainSpec, 50)
		Win(701, 3493, "Alpha", "MAGE", State.NeedMainSpec, 80)
		assert.equals("Bravo", ns.Tracker:GetRecord(700).winner.playerName)
		assert.equals("Alpha", ns.Tracker:GetRecord(701).winner.playerName)
		assert.equals(2, Count("Resolved"))
	end)

	it("ignores history for drops it never saw start", function()
		wow.setDrop(0, wow.Drop(999))
		wow.fire("LOOT_HISTORY_UPDATE_DROP", 0, 999)
		assert.is_nil(ns.Tracker:GetRecord(999))
		assert.same({}, events)
	end)

	it("lists open rolls oldest first", function()
		wow.startRoll(1, 500, 60000)
		wow.advance(2)
		wow.startRoll(2, 501, 60000)
		local open = ns.Tracker:GetOpenRecords()
		assert.equals(500, open[1].key)
		assert.equals(501, open[2].key)
	end)
end)
