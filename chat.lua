local addonName, ns = ...
local L = ns.L

local Chat = {}
ns.Chat = Chat

local PREFIX = "|HlootHistory:"

-- Roll lines Blizzard forgot to tag with the loot history link. We'll catch 'em anyway!
local UNPREFIXED_ROLL_STRINGS = {
	"LOOT_ROLL_PASSED_AUTO", "LOOT_ROLL_PASSED_AUTO_FEMALE", "LOOT_ROLL_ROLLED_NEED_ROLE_BONUS",
}

local function EscapePattern(text)
	return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- Turn Blizzard's own (already translated!) format string into something we can match.
function Chat.BuildPattern(format)
	if type(format) ~= "string" or format == "" then return nil end
	local parts, position = { "^" }, 1
	while true do
		local first, last, kind = format:find("%%%d*%$?([sd])", position)
		if not first then break end
		parts[#parts + 1] = EscapePattern(format:sub(position, first - 1))
		parts[#parts + 1] = kind == "s" and "(.+)" or "(%d+)"
		position = last + 1
	end
	parts[#parts + 1] = EscapePattern(format:sub(position))
	parts[#parts + 1] = "$"
	return table.concat(parts)
end

local spamPatterns = {}
for _, name in ipairs(UNPREFIXED_ROLL_STRINGS) do
	local pattern = Chat.BuildPattern(_G[name])
	if pattern then
		spamPatterns[#spamPatterns + 1] = pattern
	end
end

function Chat.IsRollSpam(msg)
	if type(msg) ~= "string" then return false end
	if msg:find(PREFIX, 1, true) == 1 then return true end
	for _, pattern in ipairs(spamPatterns) do
		if msg:find(pattern) then return true end
	end
	return false
end

-- A bare false means "leave the message exactly as it was"!
local function Filter(_, _, msg)
	return Chat.IsRollSpam(msg)
end

local filterInstalled = false
function Chat.Refresh()
	local wanted = LootBeaconOptions and LootBeaconOptions.summariesEnabled
	if wanted and not filterInstalled then
		ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_LOOT", Filter)
		filterInstalled = true
	elseif not wanted and filterInstalled then
		ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_LOOT", Filter)
		filterInstalled = false
	end
end
Chat.Init = Chat.Refresh

-- A window nobody can see isn't much of an audience!
local function UsableWindow(index)
	local frame = _G["ChatFrame" .. index]
	if not frame then return nil end
	local _, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(index)
	if shown or docked then return frame end
end

function Chat.GetOutputFrame()
	local chosen = LootBeaconOptions and LootBeaconOptions.chatWindow or 0
	if chosen > 0 then
		local frame = UsableWindow(chosen)
		if frame then return frame end
	end
	for index = 1, NUM_CHAT_WINDOWS do
		local frame = UsableWindow(index)
		if frame then
			for _, messageType in pairs(frame.messageTypeList or {}) do
				if messageType == "LOOT" then return frame end
			end
		end
	end
	return DEFAULT_CHAT_FRAME
end

-- Every roll wears its own color!
local TAG_COLORS = {
	need = "ffff2020", greed = "ffffff00", allPassed = "ff9d9d9d",
}
local ROLL_ICONS = { need = "lootroll-icon-need", greed = "lootroll-icon-greed" }

-- {curly} placeholders let translators put the words in whatever order they like!
local function Fill(template, values)
	return (template:gsub("{(%a+)}", function(key) return values[key] or "" end))
end

local function Tag(colorKey, text, record)
	return ("|c%s|Haddon:%s:%s:%s|h[%s]|h|r"):format(TAG_COLORS[colorKey], addonName,
		tostring(record.encounterID or 0), tostring(record.key), text)
end

function Chat.FormatSummary(record)
	local item = record.link or UNKNOWN
	local winner = record.winner
	if record.allPassed or not winner then
		return Tag("allPassed", LOOT_HISTORY_ALL_PASSED, record) .. " " .. item
	end
	local choice = ns.ChoiceForState(winner.state) or "greed"
	local label = Fill(L["{roll} - {value}"], { roll = choice == "need" and NEED or GREED, value = tostring(winner.roll or "?") })
	return Fill(L["{tag} {name} won {item}"], {
		tag = Tag(choice, label, record),
		name = ns.ClassColoredName(winner.playerName, winner.playerClass),
		item = item,
	})
end

function Chat.FormatTimeout(record)
	local label = "[" .. L["Roll result unavailable"] .. "]"
	if type(record.key) == "number" then
		label = ("|c%s|HlootHistory:%d|h%s|h|r"):format(TAG_COLORS.allPassed, record.key, label)
	end
	return label .. " " .. (record.link or UNKNOWN)
end

local function Announce(text)
	if LootBeaconOptions and LootBeaconOptions.summariesEnabled then
		Chat.GetOutputFrame():AddMessage(text)
	end
end

ns.Tracker:RegisterCallback("Resolved", function(record) Announce(Chat.FormatSummary(record)) end)
ns.Tracker:RegisterCallback("TimedOut", function(record) Announce(Chat.FormatTimeout(record)) end)

-- Click the tag to see who was in the running!
local shownKey

local function TitleFromLink(link)
	if not link then return UNKNOWN end
	return (link:gsub("|H.-|h%[(.-)%]|h", "%1"))
end

local function RollLine(roll, choice)
	local line = CreateAtlasMarkup(ROLL_ICONS[choice], 14, 14) .. " " .. (roll.roll and tostring(roll.roll) or "")
		.. "  " .. ns.ClassColoredName(roll.playerName, roll.playerClass)
	if roll.isWinner then
		line = line .. " " .. CreateAtlasMarkup("lootroll-icon-checkmark", 14, 14)
	end
	return line
end

-- Long title? Slide it clear of the close button, just like an item link does!
local function MakeRoomForCloseButton(tooltip)
	local title, close = tooltip:GetLeftLine(1), tooltip.CloseButton
	local right, left = title and title:GetRight(), close and close:GetLeft()
	if right and left and right > left then
		tooltip:SetPadding(16, 0)
	end
end

-- The winner up top, then the best of the rest!
local function HighestFirst(a, b)
	if a.isWinner or b.isWinner then return a.isWinner and not b.isWinner end
	return (a.roll or 0) > (b.roll or 0)
end

-- Only the rolls that had a shot: any Need beats every Greed, and a pass never wins!
local function Contenders(info)
	local rolls = { need = {}, greed = {} }
	for _, roll in ipairs(info.rollInfos or {}) do
		local choice = ns.ChoiceForState(roll.state)
		if rolls[choice] then table.insert(rolls[choice], roll) end
	end
	local choice = #rolls.need > 0 and "need" or "greed"
	table.sort(rolls[choice], HighestFirst)
	return rolls[choice], choice
end

-- Click once to look, click again to put it away!
local function ShowTooltip(key, info, link)
	local tooltip = ItemRefTooltip
	if info and info.allPassed then return end -- nobody rolled, so nothing to show
	if tooltip:IsShown() and shownKey == key then
		tooltip:Hide()
		return
	end
	tooltip:ClearHandlerInfo()
	tooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
	tooltip:SetPadding(0, 0)
	tooltip:AddLine(TitleFromLink((info and info.itemHyperlink) or link))
	if not info then
		tooltip:AddLine(L["Roll details are no longer available."], 1, 1, 1, true)
	else
		local rolls, choice = Contenders(info)
		for _, roll in ipairs(rolls) do
			tooltip:AddLine(RollLine(roll, choice), 1, 1, 1)
		end
	end
	tooltip:Show()
	MakeRoomForCloseButton(tooltip)
	shownKey = key
end

function Chat.ShowRollTooltip(encounterID, key)
	local record = ns.Tracker:GetRecord(key)
	ShowTooltip(key, C_LootHistory.GetSortedInfoForDrop(encounterID, key), record and record.link)
end

-- Closed, or taken over by an item link? Then it isn't ours any more!
local function Forget() shownKey = nil end
ItemRefTooltip:HookScript("OnHide", Forget)
ItemRefTooltip:HookScript("OnTooltipCleared", Forget)

-- Dress rehearsal! Who rolled what (the first one wins), shaped just like the loot history's own.
local SAMPLES = {
	{ itemID = 19019, rolls = { { "Bravo", "ROGUE", "need", 87 }, { "Foxtrot", "WARRIOR", "need", 42 },
		{ "Delta", "PALADIN", "greed", 95 }, { "Alpha", "MAGE", "pass" } } },
	{ itemID = 2073, rolls = { { "Alpha", "MAGE", "greed", 64 }, { "Charlie", "DRUID", "greed", 12 },
		{ "Delta", "PALADIN", "pass" } } },
	{ itemID = 13136, allPassed = true, rolls = { { "Alpha", "MAGE", "pass" }, { "Bravo", "ROGUE", "pass" },
		{ "Charlie", "DRUID", "pass" } } },
	{ itemID = 21615, timedOut = true },
}
local SAMPLE_WAIT_SECONDS, SAMPLE_TRIES = 0.2, 10
local State = Enum.EncounterLootDropRollState
local CHOICE_STATES = { need = State.NeedMainSpec, greed = State.Greed, pass = State.Pass }
local sampleInfos = {}

local function SampleInfo(sample)
	local info = { itemHyperlink = select(2, C_Item.GetItemInfo(sample.itemID)), allPassed = sample.allPassed, rollInfos = {} }
	for index, roll in ipairs(sample.rolls or {}) do
		info.rollInfos[index] = {
			playerName = roll[1], playerClass = roll[2], state = CHOICE_STATES[roll[3]], roll = roll[4],
			isWinner = index == 1 and not sample.allPassed,
		}
	end
	info.winner = not sample.allPassed and info.rollInfos[1] or nil
	return info
end

local function PrintSamples()
	local frame = Chat.GetOutputFrame()
	for index, sample in ipairs(SAMPLES) do
		local info = SampleInfo(sample)
		sampleInfos[index] = info
		local record = { key = index, encounterID = "sample", link = info.itemHyperlink, winner = info.winner,
			allPassed = info.allPassed }
		if sample.timedOut then
			record.key = 0
			frame:AddMessage(Chat.FormatTimeout(record))
		else
			frame:AddMessage(Chat.FormatSummary(record))
		end
	end
end

-- Items still on their way? Give them a moment before we go on!
local function PrintSamplesWhenReady(tries)
	local waiting = false
	for _, sample in ipairs(SAMPLES) do
		if not C_Item.GetItemInfo(sample.itemID) then
			waiting = true
			C_Item.RequestLoadItemDataByID(sample.itemID)
		end
	end
	if waiting and tries > 1 then
		C_Timer.After(SAMPLE_WAIT_SECONDS, function() PrintSamplesWhenReady(tries - 1) end)
	else
		PrintSamples()
	end
end

-- Show off every kind of summary line, summaries switched on or not!
function Chat.ShowSamples()
	PrintSamplesWhenReady(SAMPLE_TRIES)
end

-- Open Blizzard's Loot Rolls window and scroll it right to this item!
function Chat.OpenLootHistory(encounterID, key)
	SetLootHistoryFrameToEncounter(encounterID)
	C_Timer.After(0, function() -- give a freshly opened list a frame to lay itself out
		local frame = GroupLootHistoryFrame
		if not (frame and frame:IsShown() and frame.ScrollBox) or frame:GetSelectedEncounterID() ~= encounterID then return end
		frame.ScrollBox:ScrollToElementDataByPredicate(function(data) return data.lootListKey == key end)
	end)
end

local function OnSetItemRef(_, link)
	link = tostring(link)
	local sample = tonumber(link:match("^addon:" .. addonName .. ":sample:(%d+)$"))
	if sample then
		if sampleInfos[sample] then ShowTooltip("sample:" .. sample, sampleInfos[sample]) end
		return
	end
	local encounterID, key = link:match("^addon:" .. addonName .. ":(%d+):(%d+)$")
	if not encounterID then return end
	encounterID, key = tonumber(encounterID), tonumber(key)
	if IsShiftKeyDown() then
		Chat.OpenLootHistory(encounterID, key)
	else
		Chat.ShowRollTooltip(encounterID, key)
	end
end

EventRegistry:RegisterCallback("SetItemRef", OnSetItemRef, Chat)
