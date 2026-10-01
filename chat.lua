local addonName, ns = ...
local L = ns.L

local Chat = {}
ns.Chat = Chat

local PREFIX = "|HlootHistory:"

-- Roll lines Blizzard forgot to tag with the loot history link. We'll catch 'em anyway!
local UNPREFIXED_ROLL_STRINGS = {
	"LOOT_ROLL_PASSED_AUTO", "LOOT_ROLL_PASSED_AUTO_FEMALE", "LOOT_ROLL_DISENCHANT",
	"LOOT_ROLL_ROLLED_DE", "LOOT_ROLL_ROLLED_NEED_ROLE_BONUS",
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
	if Chat.IsRollSpam(msg) then return true end
	return false
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
	need = "ffff2020", greed = "ffffff00", disenchant = "ffff00ff", allPassed = "ff9d9d9d",
}
local ROLL_ICONS = {
	need = "lootroll-icon-need", greed = "lootroll-icon-greed",
	disenchant = "lootroll-icon-greed", pass = "lootroll-icon-pass",
}

local function RollWord(choice)
	if choice == "need" then return NEED end
	if choice == "disenchant" then return ROLL_DISENCHANT end
	return GREED
end

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
	local choice = ns.ChoiceForState(winner.state, record.canDisenchant) or "greed"
	local label = Fill(L["{roll} - {value}"], { roll = RollWord(choice), value = tostring(winner.roll or "?") })
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

-- Click the tag, get the whole story!
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

function Chat.ShowRollTooltip(encounterID, key)
	local tooltip = ItemRefTooltip
	if tooltip:IsShown() and shownKey == key then
		tooltip:Hide()
		return
	end
	local info = C_LootHistory.GetSortedInfoForDrop(encounterID, key)
	local record = ns.Tracker:GetRecord(key)
	tooltip:ClearHandlerInfo()
	tooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
	tooltip:AddLine(TitleFromLink((info and info.itemHyperlink) or (record and record.link)))
	if not info then
		tooltip:AddLine(L["Roll details are no longer available."], 1, 1, 1, true)
	else
		local passed = {}
		for _, roll in ipairs(info.rollInfos or {}) do
			local choice = ns.ChoiceForState(roll.state, true)
			if choice == "pass" then
				passed[#passed + 1] = roll
			elseif choice then
				tooltip:AddLine(RollLine(roll, choice), 1, 1, 1)
			end
		end
		if #passed > 0 then
			tooltip:AddLine(LOOT_HISTORY_PASSED)
			for _, roll in ipairs(passed) do
				tooltip:AddLine(RollLine(roll, "pass"), 1, 1, 1)
			end
		end
	end
	tooltip:Show()
	shownKey = key
end

ItemRefTooltip:HookScript("OnHide", function() shownKey = nil end)

local function OnSetItemRef(_, link)
	local encounterID, key = tostring(link):match("^addon:" .. addonName .. ":(%d+):(%d+)$")
	if not encounterID then return end
	encounterID, key = tonumber(encounterID), tonumber(key)
	if IsShiftKeyDown() then
		SetLootHistoryFrameToEncounter(encounterID)
	else
		Chat.ShowRollTooltip(encounterID, key)
	end
end

EventRegistry:RegisterCallback("SetItemRef", OnSetItemRef, Chat)
