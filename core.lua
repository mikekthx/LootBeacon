local _, ns = ...

-- Round up the usual suspects!
local C_LootHistory = C_LootHistory
local C_Timer = C_Timer
local GetLootRollItemInfo = GetLootRollItemInfo
local GetLootRollItemLink = GetLootRollItemLink
local GetLootRollTimeLeft = GetLootRollTimeLeft
local GetActiveLootRollIDs = GetActiveLootRollIDs
local GetTime = GetTime
local State = Enum.EncounterLootDropRollState

local RETRY_SECONDS = 0.5
local WATCHDOG_GRACE_SECONDS = 15
local RESOLVED_LIFETIME_SECONDS = 60
local TIMED_OUT_LIFETIME_SECONDS = 300
local RELOAD_MATCH_MS = 1000

-- RollOnLoot and the loot history speak different dialects, so keep a phrasebook!
ns.ROLL = { pass = 0, need = 1, greed = 2, disenchant = 3, transmog = 4 }
ns.CHOICES = { "need", "greed", "transmog", "disenchant", "pass" }

local STATE_TO_CHOICE = {
	[State.NeedMainSpec] = "need",
	[State.NeedOffSpec] = "need",
	[State.Transmog] = "transmog",
	[State.Greed] = "greed",
	[State.Pass] = "pass",
}

function ns.ChoiceForState(state, canDisenchant)
	if state == State.NoRoll then return nil end
	local choice = STATE_TO_CHOICE[state]
	if choice then return choice end
	-- Disenchant has no documented state; if the roll offered it, that's our best guess!
	if canDisenchant and type(state) == "number" then return "disenchant" end
	return nil
end

function ns.NewChoices()
	return { need = {}, greed = {}, transmog = {}, disenchant = {}, pass = {} }
end

function ns.ClassColoredName(name, class)
	local color = class and C_ClassColor.GetClassColor(class)
	if color then return color:WrapTextInColorCode(name) end
	return name
end

-- Say it loud, say it proud!
function ns.Print(msg)
	print("|cff33ff99LootBeacon|r: " .. msg)
end

local Tracker = { records = {}, callbacks = {} }
ns.Tracker = Tracker

function Tracker:RegisterCallback(event, fn)
	self.callbacks[event] = self.callbacks[event] or {}
	table.insert(self.callbacks[event], fn)
end

local function Fire(event, record)
	for _, fn in ipairs(Tracker.callbacks[event] or {}) do
		fn(record)
	end
end

function Tracker:GetRecord(key)
	return self.records[key]
end

function Tracker:GetRecordByRollID(rollID)
	for _, record in pairs(self.records) do
		if record.rollID == rollID and not record.closed then return record end
	end
end

function Tracker:GetOpenRecords()
	local list = {}
	for _, record in pairs(self.records) do
		if not record.closed then list[#list + 1] = record end
	end
	table.sort(list, function(a, b)
		if a.startTime ~= b.startTime then return a.startTime < b.startTime end
		return tostring(a.key) < tostring(b.key)
	end)
	return list
end

-- Done rolling? Close the book, once!
local function Close(record)
	if record.closed then return end
	record.closed = true
	Fire("Closed", record)
end

-- Out of sight, out of mind... eventually!
local function Forget(record, delay)
	C_Timer.After(delay, function()
		if Tracker.records[record.key] == record then
			Tracker.records[record.key] = nil
		end
	end)
end

local function ReadItemInfo(record)
	local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant,
		reasonNeed, reasonGreed, reasonDisenchant, deSkillRequired, canTransmog = GetLootRollItemInfo(record.rollID)
	if not name then
		record.pending = true
		return false
	end
	record.pending = false
	record.texture, record.name, record.count, record.quality = texture, name, count, quality
	record.bindOnPickUp = bindOnPickUp
	record.canNeed, record.canGreed, record.canDisenchant, record.canTransmog = canNeed, canGreed, canDisenchant, canTransmog
	record.reasonNeed, record.reasonGreed = reasonNeed, reasonGreed
	record.reasonDisenchant, record.deSkillRequired = reasonDisenchant, deSkillRequired
	record.link = GetLootRollItemLink(record.rollID)
	return true
end

-- Item still on its way? Keep checking, but only while the roll's still open!
local function RetryItemInfo(record)
	C_Timer.After(RETRY_SECONDS, function()
		if record.closed or Tracker.records[record.key] ~= record then return end
		if (GetLootRollTimeLeft(record.rollID) or 0) <= 0 then return end
		if ReadItemInfo(record) then
			Fire("Updated", record)
		else
			RetryItemInfo(record)
		end
	end)
end

-- If the history never tells us who won, say so instead of staying quiet!
local function StartWatchdog(record, timeLeftMs)
	C_Timer.After(timeLeftMs / 1000 + WATCHDOG_GRACE_SECONDS, function()
		if Tracker.records[record.key] ~= record or record.resolved or record.timedOut then return end
		record.timedOut = true
		Fire("TimedOut", record)
		Close(record)
		Forget(record, TIMED_OUT_LIFETIME_SECONDS)
	end)
end

local function AllEncounterIDs()
	local ids = {}
	for _, info in ipairs(C_LootHistory.GetAllEncounterInfos() or {}) do
		ids[#ids + 1] = info.encounterID
	end
	return ids
end

local function FindEncounter(record, encounterIDs)
	for _, encounterID in ipairs(encounterIDs) do
		for _, drop in ipairs(C_LootHistory.GetSortedDropsForEncounter(encounterID) or {}) do
			if drop.lootListKey == record.key then
				record.encounterID = encounterID
				return true
			end
		end
	end
	return false
end

local function RefreshFromHistory(record)
	if not record.encounterID then return end
	local info = C_LootHistory.GetSortedInfoForDrop(record.encounterID, record.key)
	if not info then return end
	local choices = ns.NewChoices()
	for _, roll in ipairs(info.rollInfos or {}) do
		local choice = ns.ChoiceForState(roll.state, record.canDisenchant)
		if choice then
			table.insert(choices[choice], { name = roll.playerName, class = roll.playerClass })
		end
	end
	record.choices = choices
	record.winner = info.winner
	record.allPassed = info.allPassed and true or false
	record.link = record.link or info.itemHyperlink
	Fire("Updated", record)
	if (record.winner or record.allPassed) and not record.resolved then
		record.resolved = true
		Fire("Resolved", record)
		Close(record) -- decided before you rolled? No bar should hang around!
		Forget(record, RESOLVED_LIFETIME_SECONDS)
	end
end

local function NewRecord(key, rollID, durationMs)
	return {
		key = key, rollID = rollID, duration = durationMs, startTime = GetTime(),
		choices = ns.NewChoices(), allPassed = false,
		pending = false, closed = false, resolved = false, timedOut = false,
	}
end

local function AddRecord(record, timeLeftMs)
	Tracker.records[record.key] = record
	if not ReadItemInfo(record) then
		RetryItemInfo(record)
	end
	if not record.encounterID then
		FindEncounter(record, AllEncounterIDs())
	end
	StartWatchdog(record, timeLeftMs)
	Fire("Started", record)
	RefreshFromHistory(record)
end

-- Back from a /reload mid-roll? Match each roll to its history entry by item AND end time!
local function MatchDrop(link, expectedEndMs)
	for _, encounterID in ipairs(AllEncounterIDs()) do
		for _, drop in ipairs(C_LootHistory.GetSortedDropsForEncounter(encounterID) or {}) do
			local key = drop.lootListKey
			if not Tracker.records[key] and not drop.winner and not drop.allPassed
				and drop.itemHyperlink == link
				and math.abs(drop.startTime + drop.duration - expectedEndMs) <= RELOAD_MATCH_MS then
				return key, encounterID
			end
		end
	end
end

local handlers = {}

function handlers.START_LOOT_ROLL(rollID, durationMs, key)
	if key == nil then key = "roll:" .. rollID end
	-- Already following this roll from a /reload guess? The real announcement wins!
	local stale = Tracker:GetRecordByRollID(rollID)
	if stale then
		Tracker.records[stale.key] = nil
		Close(stale)
	end
	AddRecord(NewRecord(key, rollID, durationMs), durationMs)
end

function handlers.LOOT_HISTORY_UPDATE_ENCOUNTER(encounterID)
	for _, record in pairs(Tracker.records) do
		if not record.encounterID and FindEncounter(record, { encounterID }) then
			RefreshFromHistory(record)
		end
	end
end

function handlers.LOOT_HISTORY_UPDATE_DROP(encounterID, key)
	local record = Tracker.records[key]
	if not record then
		-- No roll window for this one (auto-passed, dead, out of range)? Follow it anyway so the winner still gets announced!
		local info = C_LootHistory.GetSortedInfoForDrop(encounterID, key)
		if not info or info.winner or info.allPassed then return end
		record = NewRecord(key, nil, info.duration or 0)
		record.encounterID = encounterID
		record.closed = true
		record.link = info.itemHyperlink
		Tracker.records[key] = record
		StartWatchdog(record, math.max(0, (info.startTime or 0) + (info.duration or 0) - GetTime() * 1000))
		Fire("Started", record)
	end
	record.encounterID = encounterID
	RefreshFromHistory(record)
end

function handlers.LOOT_ROLLS_COMPLETE(key)
	local record = Tracker.records[key]
	if record then Close(record) end
end

function handlers.CANCEL_LOOT_ROLL(rollID)
	local record = Tracker:GetRecordByRollID(rollID)
	if record then Close(record) end
end

function handlers.CANCEL_ALL_LOOT_ROLLS()
	for _, record in ipairs(Tracker:GetOpenRecords()) do
		Close(record)
	end
end

function handlers.PLAYER_ENTERING_WORLD()
	for _, rollID in ipairs(GetActiveLootRollIDs() or {}) do
		if not Tracker:GetRecordByRollID(rollID) then
			local timeLeft = GetLootRollTimeLeft(rollID) or 0
			local key, encounterID = MatchDrop(GetLootRollItemLink(rollID), GetTime() * 1000 + timeLeft)
			local record = NewRecord(key or ("roll:" .. rollID), rollID, C_Loot.GetLootRollDuration(rollID) or timeLeft)
			record.encounterID = encounterID
			AddRecord(record, timeLeft)
		end
	end
end

local frame = CreateFrame("Frame")
for event in pairs(handlers) do
	frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...)
	handlers[event](...)
end)
