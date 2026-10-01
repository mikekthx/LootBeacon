local _, ns = ...

-- Missing a word? Just say the key out loud!
local L = setmetatable({}, {
	__index = function(t, k)
		local v = tostring(k)
		rawset(t, k, v)
		return v
	end
})
ns.L = L

-- Supported locales: enUS, enGB, deDE, esES, esMX, frFR, itIT, koKR, ptBR, ptPT, ruRU, zhCN, zhTW
local lang = GetLocale()

-- Do you speak English?
if lang == "enUS" or lang == "enGB" then
	L["BoP"] = "BoP"
	L["BoE"] = "BoE"
	L["Shift-click to skip the confirmation."] = "Shift-click to skip the confirmation."
	L["LootBeacon: drag to move, right-click to lock"] = "LootBeacon: drag to move, right-click to lock"
	L["Sample roll: nothing was rolled."] = "Sample roll: nothing was rolled."
	L["Showing sample roll bars. Type /lb test again to hide them."] = "Showing sample roll bars. Type /lb test again to hide them."
	L["{roll} - {value}"] = "{roll} - {value}"
	L["{tag} {name} won {item}"] = "{tag} {name} won {item}"
	L["Roll result unavailable"] = "Roll result unavailable"
	L["Roll details are no longer available."] = "Roll details are no longer available."
	L["Roll Bars"] = "Roll Bars"
	L["Enable roll bars"] = "Enable roll bars"
	L["Replaces Blizzard's loot roll windows with compact bars. Each button shows how many players chose it; point at a button to see who."] =
	"Replaces Blizzard's loot roll windows with compact bars. Each button shows how many players chose it; point at a button to see who."
	L["Scale"] = "Scale"
	L["Size of the roll bars."] = "Size of the roll bars."
	L["Stack direction"] = "Stack direction"
	L["Which way new roll bars stack from the anchor."] = "Which way new roll bars stack from the anchor."
	L["Up"] = "Up"
	L["Down"] = "Down"
	L["Move bars"] = "Move bars"
	L["Move"] = "Move"
	L["Shows the anchor and sample bars so you can drag them into place. Right-click the anchor to lock it."] =
	"Shows the anchor and sample bars so you can drag them into place. Right-click the anchor to lock it."
	L["Chat"] = "Chat"
	L["Enable roll summaries"] = "Enable roll summaries"
	L["Hides the per-player roll messages in chat and prints one line per item showing who won. Click the line to see everyone's rolls."] =
	"Hides the per-player roll messages in chat and prints one line per item showing who won. Click the line to see everyone's rolls."
	L["Output window"] = "Output window"
	L["The chat window roll summaries are printed to. Automatic uses the first window that shows loot messages."] =
	"The chat window roll summaries are printed to. Automatic uses the first window that shows loot messages."
	L["Automatic"] = "Automatic"
	return
end
