local addonName, ns = ... -- luacheck: ignore 211
local L = ns.L -- luacheck: ignore 211

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
