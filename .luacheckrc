std = "lua51"
max_line_length = false
exclude_files = { "tests/fixtures/", ".vscode/" }

globals = {
	"LootBeaconOptions", "GroupLootContainer_AddRoll",
	"SlashCmdList", "SLASH_LOOTBEACON1", "SLASH_LOOTBEACON2",
}

read_globals = {
	"C_ClassColor", "C_Loot", "C_LootHistory", "C_Timer", "ChatFrameUtil", "ColorManager",
	"ConfirmLootRoll", "CreateAtlasMarkup", "CreateFrame", "CreateSettingsButtonInitializer",
	"CreateSettingsListSectionHeaderInitializer", "CursorOnUpdate", "DEFAULT_CHAT_FRAME", "Enum",
	"EventRegistry", "EventUtil", "GameTooltip", "GameTooltip_AddErrorLine", "GameTooltip_SetTitle",
	"GetActiveLootRollIDs", "GetChatWindowInfo", "GetLocale", "GetLootRollItemInfo",
	"GetLootRollItemLink", "GetLootRollTimeLeft", "GetTime", "GREED", "HandleModifiedItemClick",
	"InputUtil", "IsShiftKeyDown", "ItemRefTooltip", "LOOT_HISTORY_ALL_PASSED", "LOOT_HISTORY_PASSED",
	"MinimalSliderWithSteppersMixin", "NEED", "NUM_CHAT_WINDOWS", "PASS", "ResetCursor",
	"RETRIEVING_ITEM_INFO", "ROLL_DISENCHANT", "RollOnLoot", "SetLootHistoryFrameToEncounter",
	"Settings", "StaticPopup_Hide", "UIParent", "UNKNOWN", "LOOT_ROLLS",
	"SetItemButtonTexture", "SetItemButtonQuality", "SetItemButtonCount",
}

-- Specs and the fake client set and read globals freely; that's their whole job.
files["tests/"] = {
	std = "+busted",
	ignore = { "111", "112", "113", "121", "122", "142", "143" },
}
