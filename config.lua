local addonName, ns = ...
local L = ns.L

-- Fresh out of the box!
ns.defaults = {
	barsEnabled = true,
	scale = 1,
	growDirection = "down", -- "down", "up"
	summariesEnabled = true,
	chatWindow = 0, -- 0 = Automatic
	anchor = { x = 0, y = 200 }, -- the pinned edge, in screen units from the middle of the screen
}

-- Only the approved flavors, please!
local validChoices = {
	growDirection = { down = true, up = true },
}

local function IsFiniteNumber(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Tables love to get shared by accident, so hand out copies!
function ns.CopyAnchor(anchor)
	return { x = anchor.x, y = anchor.y }
end

-- Whatever's in the saved file, make it something we can trust!
function ns.ValidateOptions(saved)
	local options = type(saved) == "table" and saved or {}
	for key, default in pairs(ns.defaults) do
		if type(options[key]) ~= type(default) then
			options[key] = key == "anchor" and ns.CopyAnchor(default) or default
		end
	end
	for key, choices in pairs(validChoices) do
		if not choices[options[key]] then
			options[key] = ns.defaults[key]
		end
	end
	if options.scale ~= options.scale then -- NaN never equals itself!
		options.scale = ns.defaults.scale
	end
	options.scale = math.min(2, math.max(0.5, options.scale))
	local window = options.chatWindow
	if window ~= math.floor(window) or window < 0 or window > NUM_CHAT_WINDOWS then
		options.chatWindow = ns.defaults.chatWindow
	end
	local anchor = options.anchor
	-- Old point-based saves (anything with a "point") meant something else, so start over!
	if anchor.point ~= nil or not IsFiniteNumber(anchor.x) or not IsFiniteNumber(anchor.y) then
		options.anchor = ns.CopyAnchor(ns.defaults.anchor)
	end
	return options
end

-- Who you gonna call?
function ns.HandleSlash(msg)
	local command = (msg or ""):match("^%s*(%S*)"):lower()
	if command == "move" then
		ns.Bars.SetAnchorShown(not ns.Bars.IsAnchorShown())
	elseif command == "test" then
		-- "/lb test 2" always shows that many; a bare "/lb test" flips them on and off
		local count = tonumber((msg:match("^%s*%S+%s+(%d+)")))
		local showing = count ~= nil or not ns.Bars.IsDemo()
		ns.Bars.SetDemo(showing, count)
		if showing then
			ns.Print(L["Showing sample roll bars. Type /lb test again to hide them."])
		end
	elseif command == "chat" then
		ns.Chat.ShowSamples()
	else
		Settings.OpenToCategory(ns.settingsCategory:GetID())
	end
end

-- Saved settings don't show up until the client's done loading us, so hold your horses!
EventUtil.ContinueOnAddOnLoaded(addonName, function()
	-- Unpack the saved stuff, and if it's a mess in there, tidy up!
	LootBeaconOptions = ns.ValidateOptions(LootBeaconOptions)

	-- Roll out the red carpet!
	local category, layout = Settings.RegisterVerticalLayoutCategory("LootBeacon")
	ns.settingsCategory = category

	-- A few little helpers to cut down on the paperwork!
	local function Header(name)
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(name))
	end

	local function Register(variable, key, varType, name, onChange)
		local setting = Settings.RegisterAddOnSetting(category, variable, key, LootBeaconOptions,
			varType, name, ns.defaults[key])
		if onChange then
			setting:SetValueChangedCallback(onChange)
		end
		return setting
	end

	local function RefreshBars() ns.Bars.Refresh() end

	-- Bars first!
	Header(L["Roll Bars"])
	local barsSetting = Register("LOOTBEACON_BARS_ENABLED", "barsEnabled", Settings.VarType.Boolean,
		L["Enable roll bars"], RefreshBars)
	local barsInit = Settings.CreateCheckbox(category, barsSetting,
		L["Replaces Blizzard's loot roll windows with compact bars. Each button shows how many players chose it; point at a button to see who."])
	local function BarsOn() return barsSetting:GetValue() end

	local scaleSetting = Register("LOOTBEACON_SCALE", "scale", Settings.VarType.Number, L["Scale"], RefreshBars)
	local scaleOptions = Settings.CreateSliderOptions(0.5, 2, 0.05)
	scaleOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return ("%.2f"):format(value)
	end)
	Settings.CreateSlider(category, scaleSetting, scaleOptions, L["Size of the roll bars."])
		:SetParentInitializer(barsInit, BarsOn)

	local growSetting = Register("LOOTBEACON_GROW_DIRECTION", "growDirection", Settings.VarType.String,
		L["Stack direction"], RefreshBars)
	local function GetGrowOptions()
		local container = Settings.CreateControlTextContainer()
		container:Add("down", L["Down"])
		container:Add("up", L["Up"])
		return container:GetData()
	end
	Settings.CreateDropdown(category, growSetting, GetGrowOptions, L["Which way new roll bars stack from the anchor."])
		:SetParentInitializer(barsInit, BarsOn)

	local moveInit = CreateSettingsButtonInitializer(L["Move bars"], L["Move"],
		function() ns.Bars.SetAnchorShown(true) end,
		L["Shows the anchor and sample bars so you can drag them into place. Right-click the anchor to lock it."], true)
	moveInit:SetParentInitializer(barsInit, BarsOn)
	layout:AddInitializer(moveInit)

	-- Now for the chatter!
	Header(L["Chat"])
	local summarySetting = Register("LOOTBEACON_SUMMARIES_ENABLED", "summariesEnabled", Settings.VarType.Boolean,
		L["Enable roll summaries"], function() ns.Chat.Refresh() end)
	local summaryInit = Settings.CreateCheckbox(category, summarySetting,
		L["Hides the per-player roll messages in chat and prints one line per item showing who won. Click the line to see the Need rolls, or the Greed rolls if nobody needed."])
	local function SummariesOn() return summarySetting:GetValue() end

	-- Chat windows come and go, so ask again every time the list opens!
	local windowSetting = Register("LOOTBEACON_CHAT_WINDOW", "chatWindow", Settings.VarType.Number, L["Output window"])
	local function GetWindowOptions()
		local container = Settings.CreateControlTextContainer()
		container:Add(0, L["Automatic"])
		for index = 1, NUM_CHAT_WINDOWS do
			local name = GetChatWindowInfo(index)
			if name and name ~= "" then
				container:Add(index, name)
			end
		end
		return container:GetData()
	end
	Settings.CreateDropdown(category, windowSetting, GetWindowOptions,
		L["The chat window roll summaries are printed to. Automatic uses the first window that shows loot messages."])
		:SetParentInitializer(summaryInit, SummariesOn)

	-- And now... the main event!
	Settings.RegisterAddOnCategory(category)

	-- Knock knock!
	SLASH_LOOTBEACON1 = "/lootbeacon"
	SLASH_LOOTBEACON2 = "/lb"
	SlashCmdList.LOOTBEACON = ns.HandleSlash

	-- Everybody up!
	ns.Bars.Init()
	ns.Chat.Init()
end)
