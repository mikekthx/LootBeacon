-- A small fake of the WoW client API: just enough for LootBeacon's specs.
local M = {}

local unpack = unpack or table.unpack

local function Noop() end

-- Widgets: real state for the bits the addon reads back, no-ops for everything else.
local methods = {}
local WidgetMT = {
	__index = function(_, key)
		local method = methods[key]
		if method then return method end
		if type(key) == "string" and key:find("^%u") then return Noop end
	end,
}

local function NewWidget(kind, name, parent)
	return setmetatable({
		_kind = kind, _name = name, _parent = parent,
		_shown = true, _enabled = true, _scripts = {}, _points = {}, _events = {},
		_lines = {}, _messages = {}, _width = 0, _height = 0, _scale = 1,
	}, WidgetMT)
end
M.NewWidget = NewWidget

function methods:Show() self._shown = true end
function methods:Hide()
	local wasShown = self._shown
	self._shown = false
	if wasShown and self._scripts.OnHide then self._scripts.OnHide(self) end
end
function methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
function methods:IsShown() return self._shown end
function methods:SetScript(name, fn) self._scripts[name] = fn end
function methods:GetScript(name) return self._scripts[name] end
function methods:HookScript(name, fn)
	local old = self._scripts[name]
	self._scripts[name] = function(...)
		if old then old(...) end
		fn(...)
	end
end
function methods:SetText(text) self._text = text end
function methods:GetText() return self._text end
function methods:Enable() self._enabled = true end
function methods:Disable() self._enabled = false end
function methods:SetEnabled(enabled) self._enabled = enabled and true or false end
function methods:IsEnabled() return self._enabled end
function methods:SetAlpha(alpha) self._alpha = alpha end
function methods:GetAlpha() return self._alpha or 1 end
function methods:SetDesaturated(desaturated) self._desaturated = desaturated end
function methods:SetAtlas(atlas) self._atlas = atlas end
function methods:GetAtlas() return self._atlas end
function methods:SetTexture(texture) self._texture = texture end
function methods:GetTexture() return self._texture end
function methods:GetNormalTexture()
	self._normal = self._normal or NewWidget("Texture", nil, self)
	return self._normal
end
function methods:SetNormalAtlas(atlas) self:GetNormalTexture():SetAtlas(atlas) end
function methods:SetNormalTexture(texture) self:GetNormalTexture():SetTexture(texture) end
function methods:CreateTexture() return NewWidget("Texture", nil, self) end
function methods:CreateFontString() return NewWidget("FontString", nil, self) end
function methods:SetPoint(...) table.insert(self._points, { ... }) end
function methods:ClearAllPoints() self._points = {} end
function methods:GetPoint(index)
	local point = self._points[index or 1]
	if point then return unpack(point, 1, 5) end
end
function methods:SetSize(width, height) self._width, self._height = width, height end
function methods:SetWidth(width) self._width = width end
function methods:SetHeight(height) self._height = height end
function methods:GetWidth() return self._width end
function methods:GetHeight() return self._height end
function methods:SetScale(scale) self._scale = scale end
function methods:GetScale() return self._scale end
function methods:GetEffectiveScale() return self._scale end
function methods:GetName() return self._name end
function methods:GetParent() return self._parent end
function methods:RegisterEvent(event)
	self._events[event] = true
	if not self._listening then
		self._listening = true
		table.insert(M.eventFrames, self)
	end
end
function methods:UnregisterEvent(event) self._events[event] = nil end
function methods:AddLine(text) table.insert(self._lines, text) end
function methods:ClearLines() self._lines = {} end
function methods:SetOwner(owner) self._owner = owner; self._lines = {} end
function methods:IsOwned(owner) return self._owner == owner end
function methods:ClearHandlerInfo() self._lines = {} end
function methods:SetLootRollItem(rollID) self._lootRollItem = rollID end
function methods:SetHyperlink(link) self._hyperlink = link end
function methods:AddMessage(text) table.insert(self._messages, text) end
function methods:SetTitle(text) self._title = text end
function methods:CreateMaskTexture() return NewWidget("MaskTexture", nil, self) end
function methods:AddMaskTexture(mask)
	self._masks = self._masks or {}
	table.insert(self._masks, mask)
end
function methods:SetTexCoord(...) self._texCoord = { ... } end
function methods:SetSnapToPixelGrid(snap) self._snapToPixelGrid = snap end
function methods:SetTexelSnappingBias(bias) self._texelSnappingBias = bias end

local function Recorder(name)
	return function(...)
		M.calls[name] = M.calls[name] or {}
		table.insert(M.calls[name], { ... })
	end
end

local function NewInitializer()
	local initializer = {}
	function initializer:SetParentInitializer(parent, predicate)
		self.parent, self.predicate = parent, predicate
		return self
	end
	initializer.AddSearchTags = function() end
	return initializer
end

function M.reset()
	M.now = 1000
	M.timers = {}
	M.eventFrames = {}
	M.onAddonLoaded = {}
	M.rolls = {}
	M.drops = {}
	M.encounterOrder = {}
	M.filters = {}
	M.itemRefCallbacks = {}
	M.calls = {}
	M.printed = {}
	M.settings = {}
	M.dropdowns = {}
	M.buttons = {}
	M.registeredCategory = nil
	M.gamepad = false
	M.shift = false
	M.locale = "enUS"
	M.chatWindowNames = { "General", "Combat Log", "Loot" }
	M.chatWindowShown = { true, true, true }

	local G = _G
	G.LootBeaconOptions = nil
	for key, value in pairs(require("tests.mock.globalstrings")) do G[key] = value end

	G.GetLocale = function() return M.locale end
	G.GetTime = function() return M.now end
	G.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
		table.insert(M.printed, table.concat(parts, " "))
	end
	G.C_Timer = {
		After = function(seconds, fn) table.insert(M.timers, { at = M.now + seconds, fn = fn }) end,
	}
	G.CreateFrame = function(kind, name, parent, template)
		local widget = NewWidget(kind, name, parent)
		if name then G[name] = widget end
		if kind == "ItemButton" then
			widget.icon = NewWidget("Texture", nil, widget) -- the intrinsic's parentKey="icon"
		end
		if template == "DefaultPanelFlatTemplate" then
			widget.NineSlice = NewWidget("Frame", nil, widget)
			widget.Bg = NewWidget("Frame", nil, widget)
			widget.TitleContainer = NewWidget("Frame", nil, widget)
		end
		return widget
	end
	-- Blizzard's no-portrait panel layout, as this client adjusts it (NineSliceLayoutOverrides).
	G.NineSliceLayouts = {
		ButtonFrameTemplateNoPortrait = {
			disableSharpening = true,
			TopLeftCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopLeft", x = -8, y = 16 },
			TopRightCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRight", x = 2, y = 16 },
			BottomLeftCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -8, y = -8 },
			BottomRightCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 2, y = -8 },
			TopEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop" },
			BottomEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom" },
			LeftEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft" },
			RightEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight" },
		},
	}
	G.NineSliceUtil = {
		ApplyLayout = function(container, layout)
			M.calls.ApplyLayout = M.calls.ApplyLayout or {}
			table.insert(M.calls.ApplyLayout, { container, layout })
		end,
	}
	-- Snaps to real screen pixels in the client; here it records the call and passes straight through.
	G.PixelUtil = {
		SetHeight = function(region, height)
			region._pixelHeight = height
			region:SetHeight(height)
		end,
		SetPoint = function(region, point, relativeTo, relativePoint, x, y)
			region._pixelSnapped = true
			region:SetPoint(point, relativeTo, relativePoint, x, y)
		end,
	}
	G.C_Texture = {
		GetAtlasInfo = function(atlas) return { tilesHorizontally = atlas:sub(1, 1) == "_", tilesVertically = atlas:sub(1, 1) == "!" } end,
	}
	G.UIParent = NewWidget("Frame", "UIParent")
	G.UIParent:SetSize(1920, 1080)
	G.GameTooltip = NewWidget("GameTooltip", "GameTooltip")
	G.ItemRefTooltip = NewWidget("GameTooltip", "ItemRefTooltip")
	G.ItemRefTooltip:Hide()
	G.GameTooltip_SetTitle = function(tooltip, text) tooltip:AddLine(text) end
	G.GameTooltip_AddErrorLine = function(tooltip, text) tooltip:AddLine(text) end
	G.EventUtil = {
		ContinueOnAddOnLoaded = function(_, fn) table.insert(M.onAddonLoaded, fn) end,
	}
	G.SlashCmdList = {}
	G.Enum = {
		EncounterLootDropRollState = { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 },
		ItemQuality = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 },
	}
	G.InputUtil = { IsGamepadUIEnabled = function() return M.gamepad end }
	G.IsShiftKeyDown = function() return M.shift end
	for _, name in ipairs({ "RollOnLoot", "ConfirmLootRoll", "StaticPopup_Hide", "SetLootHistoryFrameToEncounter",
		"HandleModifiedItemClick", "ResetCursor", "CursorOnUpdate", "GroupLootContainer_AddRoll",
		"SetItemButtonTexture", "SetItemButtonQuality", "SetItemButtonCount" }) do
		G[name] = Recorder(name)
	end
	G.CreateAtlasMarkup = function(atlas, width, height)
		return ("|A:%s:%d:%d|a"):format(atlas, height or 0, width or 0)
	end
	G.C_ClassColor = {
		GetClassColor = function(class)
			return { WrapTextInColorCode = function(_, text) return "<" .. class .. ">" .. text end }
		end,
	}
	G.ColorManager = {
		GetColorDataForItemQuality = function(quality) return { r = 1, g = 1, b = 1, quality = quality } end,
		GetAtlasDataForLootBorderItemQuality = function(quality) return "loottoast-itemborder-q" .. tostring(quality) end,
	}
	G.MinimalSliderWithSteppersMixin = { Label = { Right = "Right" } }

	G.NUM_CHAT_WINDOWS = 10
	G.GetChatWindowInfo = function(index)
		return M.chatWindowNames[index] or "", 14, 1, 1, 1, 1, M.chatWindowShown[index] or false, false, false
	end
	for index = 1, 10 do
		local frame = NewWidget("ScrollingMessageFrame", "ChatFrame" .. index)
		frame.messageTypeList = {}
		G["ChatFrame" .. index] = frame
	end
	G.ChatFrame1.messageTypeList = { "SAY", "PARTY" }
	G.ChatFrame3.messageTypeList = { "LOOT", "MONEY" }
	G.DEFAULT_CHAT_FRAME = G.ChatFrame1
	G.ChatFrameUtil = {
		AddMessageEventFilter = function(event, fn)
			M.filters[event] = M.filters[event] or {}
			for _, existing in ipairs(M.filters[event]) do
				if existing == fn then return end
			end
			table.insert(M.filters[event], fn)
		end,
		RemoveMessageEventFilter = function(event, fn)
			local list = M.filters[event] or {}
			for i = #list, 1, -1 do
				if list[i] == fn then table.remove(list, i) end
			end
		end,
	}
	G.EventRegistry = {
		RegisterCallback = function(_, event, fn, owner)
			if event == "SetItemRef" then table.insert(M.itemRefCallbacks, { fn = fn, owner = owner }) end
		end,
	}

	G.Settings = {
		VarType = { Boolean = "boolean", Number = "number", String = "string" },
		RegisterVerticalLayoutCategory = function(name)
			local category = { name = name }
			function category:GetID() return self.name end
			local layout = { initializers = {} }
			function layout:AddInitializer(initializer) table.insert(self.initializers, initializer) end
			return category, layout
		end,
		RegisterAddOnSetting = function(_, variable, key, tbl, varType, name, default)
			local setting = { variable = variable, key = key, tbl = tbl, varType = varType, name = name, default = default }
			function setting:GetValue() return self.tbl[self.key] end
			function setting:SetValue(value)
				self.tbl[self.key] = value
				if self.callback then self.callback(self, value) end
			end
			function setting:SetValueChangedCallback(fn) self.callback = fn end
			M.settings[variable] = setting
			return setting
		end,
		CreateCheckbox = function() return NewInitializer() end,
		CreateSlider = function() return NewInitializer() end,
		CreateSliderOptions = function(minValue, maxValue, step)
			local options = { minValue = minValue, maxValue = maxValue, step = step }
			function options:SetLabelFormatter(_, fn) self.formatter = fn end
			return options
		end,
		CreateDropdown = function(_, setting, options)
			M.dropdowns[setting.variable] = options
			return NewInitializer()
		end,
		CreateControlTextContainer = function()
			local container = { data = {} }
			function container:Add(value, label)
				local entry = { value = value, label = label }
				table.insert(self.data, entry)
				return entry
			end
			function container:GetData() return self.data end
			return container
		end,
		RegisterAddOnCategory = function(category) M.registeredCategory = category end,
		OpenToCategory = Recorder("OpenToCategory"),
	}
	G.CreateSettingsListSectionHeaderInitializer = function(name) return { header = name } end
	G.CreateSettingsButtonInitializer = function(name, buttonText, click, tooltip)
		local initializer = NewInitializer()
		initializer.buttonText, initializer.click, initializer.tooltip = buttonText, click, tooltip
		M.buttons[name] = initializer
		return initializer
	end

	G.GetLootRollItemInfo = function(rollID)
		local roll = M.rolls[rollID]
		if roll then return unpack(roll.info, 1, 13) end
	end
	G.GetLootRollItemLink = function(rollID)
		local roll = M.rolls[rollID]
		return roll and roll.link
	end
	G.GetLootRollTimeLeft = function(rollID)
		local roll = M.rolls[rollID]
		if not roll or not roll.active then return 0 end
		return math.max(0, roll.endTime - M.now * 1000)
	end
	G.GetActiveLootRollIDs = function()
		local ids = {}
		for id, roll in pairs(M.rolls) do
			if roll.active then ids[#ids + 1] = id end
		end
		table.sort(ids)
		return ids
	end
	G.C_Loot = {
		GetLootRollDuration = function(rollID)
			local roll = M.rolls[rollID]
			return roll and roll.duration
		end,
	}
	G.C_LootHistory = {
		GetSortedInfoForDrop = function(encounterID, key)
			local drop = M.drops[key]
			if drop and drop._encounterID == encounterID then return drop end
		end,
		GetSortedDropsForEncounter = function(encounterID)
			local list = {}
			for _, drop in pairs(M.drops) do
				if drop._encounterID == encounterID then list[#list + 1] = drop end
			end
			table.sort(list, function(a, b) return a.lootListKey < b.lootListKey end)
			return list
		end,
		GetAllEncounterInfos = function()
			local list = {}
			for _, encounterID in ipairs(M.encounterOrder) do
				list[#list + 1] = { encounterID = encounterID, encounterName = "Encounter " .. encounterID }
			end
			return list
		end,
	}
end

function M.loadAddon(files, ns)
	ns = ns or {}
	for _, file in ipairs(files) do
		local chunk = assert(loadfile(file))
		chunk("LootBeacon", ns)
	end
	M.ns = ns
	return ns
end

function M.fireAddonLoaded()
	for _, fn in ipairs(M.onAddonLoaded) do fn() end
end

function M.fire(event, ...)
	for _, frame in ipairs(M.eventFrames) do
		if frame._events[event] and frame._scripts.OnEvent then
			frame._scripts.OnEvent(frame, event, ...)
		end
	end
end

function M.advance(seconds)
	local target = M.now + seconds
	while true do
		local nextIndex
		for index, timer in ipairs(M.timers) do
			if timer.at <= target and (not nextIndex or timer.at < M.timers[nextIndex].at) then
				nextIndex = index
			end
		end
		if not nextIndex then break end
		local timer = table.remove(M.timers, nextIndex)
		M.now = timer.at
		timer.fn()
	end
	M.now = target
end

function M.advanceTo(time)
	if time > M.now then M.advance(time - M.now) end
end

function M.runChatFilters(event, msg)
	for _, fn in ipairs(M.filters[event] or {}) do
		if fn(_G.ChatFrame1, event, msg) then return true end
	end
	return false
end

function M.clickLink(link, button)
	for _, callback in ipairs(M.itemRefCallbacks) do
		callback.fn(callback.owner, link, "[link]", button or "LeftButton", _G.ChatFrame1)
	end
end

function M.ItemInfo(o)
	o = o or {}
	local name = o.name or "Test Item"
	if o.pending then name = nil end
	return {
		o.texture or 132395, name, o.count or 1, o.quality or 2, o.bop or false,
		o.canNeed ~= false, o.canGreed ~= false, o.canDisenchant or false,
		o.reasonNeed or 0, o.reasonGreed or 0, o.reasonDisenchant or 4, o.deSkill or 0,
		o.canTransmog or false,
	}
end

function M.addRoll(rollID, durationMs, info, link)
	M.rolls[rollID] = {
		info = info or M.ItemInfo(),
		link = link or "|cnIQ2:|Hitem:2073|h[Test Item]|h|r",
		duration = durationMs,
		endTime = M.now * 1000 + durationMs,
		active = true,
	}
end

function M.startRoll(rollID, key, durationMs, info, link)
	M.addRoll(rollID, durationMs, info, link)
	M.fire("START_LOOT_ROLL", rollID, durationMs, key)
end

function M.cancelRoll(rollID)
	if M.rolls[rollID] then M.rolls[rollID].active = false end
	M.fire("CANCEL_LOOT_ROLL", rollID)
end

function M.Drop(key, o)
	o = o or {}
	return {
		lootListKey = key,
		itemHyperlink = o.link or "|cnIQ2:|Hitem:2073|h[Test Item]|h|r",
		rollInfos = o.rollInfos or {},
		winner = o.winner,
		allPassed = o.allPassed or false,
		isTied = false,
		playerRollState = 4,
		startTime = o.startTime or 0,
		duration = o.duration or 60000,
	}
end

function M.RollInfo(name, class, state, roll, isWinner)
	return { playerName = name, playerClass = class, state = state, roll = roll, isWinner = isWinner or false, isSelf = false }
end

function M.setDrop(encounterID, drop)
	drop._encounterID = encounterID
	M.drops[drop.lootListKey] = drop
	for _, known in ipairs(M.encounterOrder) do
		if known == encounterID then return end
	end
	table.insert(M.encounterOrder, encounterID)
end

return M
