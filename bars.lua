local _, ns = ...
local L = ns.L

local Bars = {}
ns.Bars = Bars

-- Get in here, Globals!
local GetLootRollTimeLeft = GetLootRollTimeLeft
local GetTime = GetTime

local BAR_WIDTH, BAR_HEIGHT, BAR_SPACING = 300, 44, 4
local ICON_SIZE, BUTTON_SIZE = 34, 28
local DEMO_DURATION = 60000
local QUESTION_MARK_ICON = 134400

-- Blizzard's own roll-button art, plus the old Disenchant files since there's no new one!
local BUTTON_ART = {
	need = { atlas = "lootroll-toast-icon-need" },
	greed = { atlas = "lootroll-toast-icon-greed" },
	transmog = { atlas = "lootroll-toast-icon-transmog" },
	disenchant = { file = "Interface\\Buttons\\UI-GroupLoot-DE" },
	pass = { atlas = "lootroll-toast-icon-pass" },
}

-- Right to left, the way the buttons line up on the bar.
local BUTTON_ORDER = { "pass", "transmog", "greed", "disenchant", "need" }

local function ChoiceLabel(choice)
	if choice == "need" then return NEED end
	if choice == "greed" then return GREED end
	if choice == "transmog" then return TRANSMOGRIFICATION end
	if choice == "disenchant" then return ROLL_DISENCHANT end
	return PASS
end

local function IneligibleReason(index)
	if not index or index == 0 then return nil end
	return _G["LOOT_ROLL_INELIGIBLE_REASON" .. index]
end

-- Everybody hangs out here!
local root = CreateFrame("Frame", "LootBeaconRoot", UIParent)
root:SetSize(BAR_WIDTH, BAR_HEIGHT)
root:SetMovable(true)
root:SetClampedToScreen(true)
Bars._root = root

local anchor = CreateFrame("Frame", nil, root)
anchor:SetAllPoints(root)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")
anchor.background = anchor:CreateTexture(nil, "BACKGROUND")
anchor.background:SetAllPoints(anchor)
anchor.background:SetAtlas("lootroll-itementry-background")
anchor.label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
anchor.label:SetPoint("CENTER")
anchor.label:SetText(L["LootBeacon: drag to move, right-click to lock"])
anchor:Hide()
Bars._anchor = anchor

local pool, barsByRecord = {}, {}
local pendingConfirms = {} -- rollID -> roll type we promised to confirm
local shownRecords = {}
local demoMode, demoRecords = false, {}
local lastEnabled, wasActive
local Layout -- defined further down; everything needs it!

function Bars.IsActive()
	return (LootBeaconOptions and LootBeaconOptions.barsEnabled and not InputUtil.IsGamepadUIEnabled()) and true or false
end

-- Blizzard asks to show a roll window; while we're on duty, we'll take it from here!
local blizzardAddRoll = GroupLootContainer_AddRoll
GroupLootContainer_AddRoll = function(rollID, rollTime)
	local record = ns.Tracker:GetRecordByRollID(rollID)
	-- Blizzard's already got this one (e.g. pulled from its own waiting line)? Let it finish the job!
	if Bars.IsActive() and not (record and record.blizzardOwned) then
		Bars.Refresh() -- e.g. returning from Gamepad style: Blizzard's RefreshRolls lands here, so wake the bars
		return
	end
	if record then record.blizzardOwned = true end
	if blizzardAddRoll then
		return blizzardAddRoll(rollID, rollTime)
	end
end

local function TimeLeft(record)
	if record.demo then
		local left = record.duration - (GetTime() - record.startTime) * 1000
		if left <= 0 then
			record.startTime = GetTime() -- the show must go on!
			left = record.duration
		end
		return left
	end
	return GetLootRollTimeLeft(record.rollID) or 0
end

local function UpdateTimer(bar)
	local record = bar.record
	if not record then return end
	local fraction = 0
	if record.duration and record.duration > 0 then
		fraction = math.min(1, math.max(0, TimeLeft(record) / record.duration))
	end
	bar.timer.fill:SetWidth(math.max(1, bar.timer:GetWidth() * fraction))
end

local function HideTooltip()
	GameTooltip:Hide()
end

local function OnRollClick(button)
	local record = button.bar.record
	if not record then return end
	if record.demo then
		ns.Print(L["Sample roll: nothing was rolled."])
		return
	end
	RollOnLoot(record.rollID, button.rollType)
	-- Shift means "yes, I'm sure" -- we'll answer the game's "are you sure?" when it asks!
	if IsShiftKeyDown() and button.choice ~= "pass" then
		pendingConfirms[record.rollID] = button.rollType
	end
end

local function OnConfirmRequest(_, _, rollID, rollType)
	if pendingConfirms[rollID] ~= rollType then return end
	pendingConfirms[rollID] = nil
	ConfirmLootRoll(rollID, rollType)
	StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollID)
	-- Blizzard might pop its box up right after us, so swat it again next frame!
	C_Timer.After(0, function() StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollID) end)
end

local confirmWatcher = CreateFrame("Frame")
confirmWatcher:RegisterEvent("CONFIRM_LOOT_ROLL")
confirmWatcher:RegisterEvent("CONFIRM_DISENCHANT_ROLL")
confirmWatcher:SetScript("OnEvent", OnConfirmRequest)

local function OnRollEnter(button)
	local record = button.bar.record
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip_SetTitle(GameTooltip, ChoiceLabel(button.choice))
	if not button:IsEnabled() and button.reason then
		GameTooltip_AddErrorLine(GameTooltip, button.reason, true)
	end
	for _, player in ipairs(record and record.choices[button.choice] or {}) do
		GameTooltip:AddLine(ns.ClassColoredName(player.name, player.class))
	end
	if button.choice ~= "pass" then
		GameTooltip:AddLine(L["Shift-click to skip the confirmation."], 0.5, 0.5, 0.5, true)
	end
	GameTooltip:Show()
end

local function ShowItemTooltip(icon)
	local record = icon.bar.record
	if not record then return end
	GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
	if record.demo then
		GameTooltip:SetHyperlink(record.link)
	else
		GameTooltip:SetLootRollItem(record.rollID)
	end
	GameTooltip:Show()
end

local function CreateRollButton(bar, choice)
	local button = CreateFrame("Button", nil, bar)
	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	button.bar = bar
	button.choice = choice
	button.rollType = ns.ROLL[choice]
	local art = BUTTON_ART[choice]
	if art.atlas then
		button:SetNormalAtlas(art.atlas .. "-up")
		button:SetPushedAtlas(art.atlas .. "-down")
		button:SetHighlightAtlas(art.atlas .. "-highlight", "ADD")
	else
		button:SetNormalTexture(art.file .. "-Up")
		button:SetPushedTexture(art.file .. "-Down")
		button:SetHighlightTexture(art.file .. "-Highlight", "ADD")
	end
	button:SetMotionScriptsWhileDisabled(true)
	button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
	button:SetScript("OnClick", OnRollClick)
	button:SetScript("OnEnter", OnRollEnter)
	button:SetScript("OnLeave", HideTooltip)
	return button
end

local function CreateBar()
	local bar = CreateFrame("Frame", nil, root)
	bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	bar.background = bar:CreateTexture(nil, "BACKGROUND")
	bar.background:SetAllPoints(bar)
	bar.background:SetAtlas("lootroll-itementry-background")

	local icon = CreateFrame("Button", nil, bar)
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetPoint("LEFT", bar, "LEFT", 8, 0)
	icon.bar = bar
	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints(icon)
	icon.border = icon:CreateTexture(nil, "OVERLAY")
	icon.border:SetSize(42, 42)
	icon.border:SetPoint("CENTER", icon, "CENTER", 0, -2)
	icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
	icon:SetScript("OnEnter", ShowItemTooltip)
	icon:SetScript("OnLeave", function()
		GameTooltip:Hide()
		ResetCursor()
	end)
	icon:SetScript("OnUpdate", function(self)
		if GameTooltip:IsOwned(self) then ShowItemTooltip(self) end
		CursorOnUpdate(self)
	end)
	icon:SetScript("OnClick", function(self)
		local record = self.bar.record
		if record and record.link then HandleModifiedItemClick(record.link) end
	end)
	bar.icon = icon

	bar.name = bar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	bar.name:SetJustifyH("LEFT")
	bar.name:SetWordWrap(false)

	bar.buttons = {}
	for _, choice in ipairs(ns.CHOICES) do
		bar.buttons[choice] = CreateRollButton(bar, choice)
	end

	-- The same three-piece timer Blizzard's Loot Rolls window uses!
	local timer = CreateFrame("Frame", nil, bar)
	timer:SetHeight(8)
	timer.background = timer:CreateTexture(nil, "BACKGROUND")
	timer.background:SetAllPoints(timer)
	timer.background:SetAtlas("lootroll-timer-background")
	timer.fill = timer:CreateTexture(nil, "ARTWORK")
	timer.fill:SetAtlas("lootroll-timer-fill")
	timer.fill:SetPoint("TOPLEFT", timer, "TOPLEFT")
	timer.fill:SetPoint("BOTTOMLEFT", timer, "BOTTOMLEFT")
	timer.border = timer:CreateTexture(nil, "OVERLAY")
	timer.border:SetAllPoints(timer)
	timer.border:SetAtlas("lootroll-timer-border")
	bar.timer = timer

	bar:SetScript("OnUpdate", UpdateTimer)
	return bar
end

local function SetButtonUsable(button, usable, reason)
	usable = usable and true or false
	button:SetEnabled(usable)
	button:SetAlpha(usable and 1 or 0.35)
	button:GetNormalTexture():SetDesaturated(not usable)
	button.reason = (not usable) and reason or nil
end

local function UpdateBar(bar, record)
	bar.record = record
	local icon = bar.icon
	icon.texture:SetTexture(record.texture or QUESTION_MARK_ICON)
	icon.border:SetAtlas(ColorManager.GetAtlasDataForLootBorderItemQuality(record.quality or Enum.ItemQuality.Uncommon)
		or ColorManager.GetAtlasDataForLootBorderItemQuality(Enum.ItemQuality.Uncommon))
	icon.count:SetText((record.count or 1) > 1 and tostring(record.count) or "")

	local ready = not record.pending
	if ready then
		local tag = record.bindOnPickUp and ("|cffff4d1a" .. L["BoP"] .. "|r ") or ("|cff4dff4d" .. L["BoE"] .. "|r ")
		bar.name:SetText(tag .. (record.name or UNKNOWN))
		local color = ColorManager.GetColorDataForItemQuality(record.quality)
		if color then bar.name:SetTextColor(color.r, color.g, color.b) end
	else
		bar.name:SetText(RETRIEVING_ITEM_INFO)
		bar.name:SetTextColor(0.6, 0.6, 0.6)
	end

	local buttons = bar.buttons
	buttons.transmog:SetShown(ready and record.canTransmog or false)
	buttons.greed:SetShown(not buttons.transmog:IsShown())
	buttons.disenchant:SetShown(ready and record.canDisenchant or false)
	SetButtonUsable(buttons.need, ready and record.canNeed, ready and IneligibleReason(record.reasonNeed) or nil)
	SetButtonUsable(buttons.greed, ready and record.canGreed, ready and IneligibleReason(record.reasonGreed) or nil)
	SetButtonUsable(buttons.transmog, true)
	SetButtonUsable(buttons.disenchant, true)
	SetButtonUsable(buttons.pass, true)

	for choice, button in pairs(buttons) do
		local count = #(record.choices[choice] or {})
		button.count:SetText(count > 0 and tostring(count) or "")
	end

	local leftmost
	for _, choice in ipairs(BUTTON_ORDER) do
		local button = buttons[choice]
		if button:IsShown() then
			button:ClearAllPoints()
			if leftmost then
				button:SetPoint("RIGHT", leftmost, "LEFT", -2, 0)
			else
				button:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
			end
			leftmost = button
		end
	end
	bar.name:ClearAllPoints()
	bar.name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
	bar.name:SetPoint("TOPRIGHT", leftmost, "TOPLEFT", -6, 1)
	bar.timer:ClearAllPoints()
	bar.timer:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 2)
	bar.timer:SetPoint("BOTTOMRIGHT", leftmost, "BOTTOMLEFT", -6, -1)
	UpdateTimer(bar)
end

-- Gamepad mode can flip at any time; keep an eye out while bars are up!
local function CheckActive()
	if Bars.IsActive() ~= wasActive then
		Layout()
	end
end

function Layout()
	wasActive = Bars.IsActive()
	local records = {}
	if wasActive then
		for _, record in ipairs(ns.Tracker:GetOpenRecords()) do
			if not record.blizzardOwned then records[#records + 1] = record end
		end
	end
	if demoMode then
		for _, record in ipairs(demoRecords) do records[#records + 1] = record end
	end

	local wanted = {}
	for _, record in ipairs(records) do wanted[record] = true end
	for record, bar in pairs(barsByRecord) do
		if not wanted[record] then
			bar:Hide()
			bar.record = nil
			barsByRecord[record] = nil
			pool[#pool + 1] = bar
		end
	end

	local growUp = LootBeaconOptions and LootBeaconOptions.growDirection == "up"
	local previous = root
	for _, record in ipairs(records) do
		local bar = barsByRecord[record]
		if not bar then
			bar = table.remove(pool) or CreateBar()
			barsByRecord[record] = bar
		end
		UpdateBar(bar, record)
		bar:ClearAllPoints()
		if growUp then
			bar:SetPoint("BOTTOM", previous, "TOP", 0, BAR_SPACING)
		else
			bar:SetPoint("TOP", previous, "BOTTOM", 0, -BAR_SPACING)
		end
		bar:Show()
		previous = bar
	end
	shownRecords = records
	root:SetScript("OnUpdate", #records > 0 and CheckActive or nil)
end

function Bars.Refresh()
	if not LootBeaconOptions then return end
	local enabled = LootBeaconOptions.barsEnabled
	-- Switched off mid-roll? Hand the open rolls back so nobody's left without a window!
	if lastEnabled and not enabled and not InputUtil.IsGamepadUIEnabled() then
		for _, record in ipairs(ns.Tracker:GetOpenRecords()) do
			if not record.blizzardOwned and record.rollID then
				record.blizzardOwned = true
				if blizzardAddRoll then
					blizzardAddRoll(record.rollID, C_Loot.GetLootRollDuration(record.rollID) or record.duration)
				end
			end
		end
	end
	lastEnabled = enabled
	root:SetScale(LootBeaconOptions.scale)
	Layout()
end

local function ApplyPosition()
	local saved = LootBeaconOptions.anchor
	root:ClearAllPoints()
	root:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x, saved.y)
end

local function IsOnScreen()
	local left, bottom, width, height = root:GetRect()
	if not left then return true end
	local scale = root:GetEffectiveScale() / UIParent:GetEffectiveScale()
	left, bottom, width, height = left * scale, bottom * scale, width * scale, height * scale
	return left + width > 0 and bottom + height > 0 and left < UIParent:GetWidth() and bottom < UIParent:GetHeight()
end

function Bars.Init()
	lastEnabled = LootBeaconOptions.barsEnabled
	root:SetScale(LootBeaconOptions.scale)
	ApplyPosition()
	-- Lost somewhere past the edge of the screen? Come on home!
	if not IsOnScreen() then
		LootBeaconOptions.anchor = ns.CopyAnchor(ns.defaults.anchor)
		ApplyPosition()
	end
	Bars.Refresh()
end

anchor:SetScript("OnDragStart", function()
	root:StartMoving()
end)
anchor:SetScript("OnDragStop", function()
	root:StopMovingOrSizing()
	local point, _, relativePoint, x, y = root:GetPoint(1)
	if point then
		LootBeaconOptions.anchor = { point = point, relativePoint = relativePoint, x = x, y = y }
	end
end)
anchor:SetScript("OnMouseUp", function(_, button)
	if button == "RightButton" then
		Bars.SetAnchorShown(false)
	end
end)

-- Pretend rolls, for lining things up without a group!
local function DemoRecord(key, o)
	local record = {
		key = key, demo = true, startTime = GetTime(), duration = DEMO_DURATION,
		texture = o.texture, name = o.name, link = o.link, count = 1, quality = o.quality,
		bindOnPickUp = o.bop, canNeed = o.canNeed, canGreed = true,
		canTransmog = o.canTransmog or false, canDisenchant = o.canDisenchant or false,
		reasonNeed = o.reasonNeed or 0, reasonGreed = 0, pending = false,
		choices = ns.NewChoices(),
	}
	for choice, players in pairs(o.choices or {}) do
		record.choices[choice] = players
	end
	return record
end

local function BuildDemoRecords()
	return {
		DemoRecord("demo:1", {
			texture = 132395, name = "Dwarven Hatchet of the Bear", link = "item:2073",
			quality = Enum.ItemQuality.Uncommon, bop = false, canNeed = true,
			choices = {
				need = { { name = "Charlie", class = "DRUID" } },
				greed = { { name = "Alpha", class = "MAGE" }, { name = "Bravo", class = "ROGUE" } },
			},
		}),
		DemoRecord("demo:2", {
			texture = 466975, name = "Ephemeral Choker", link = "item:270227",
			quality = Enum.ItemQuality.Rare, bop = true, canNeed = false, reasonNeed = 1,
			choices = { pass = { { name = "Delta", class = "PALADIN" } } },
		}),
		DemoRecord("demo:3", {
			texture = 132409, name = "Durgen's Crescent Axe", link = "item:270256",
			quality = Enum.ItemQuality.Epic, bop = true, canNeed = true, canTransmog = true, canDisenchant = true,
			choices = {
				need = { { name = "Echo", class = "HUNTER" } },
				transmog = { { name = "Alpha", class = "MAGE" } },
			},
		}),
	}
end

function Bars.IsDemo()
	return demoMode
end

function Bars.SetDemo(on)
	on = on and true or false
	if on == demoMode then return end
	demoMode = on
	demoRecords = on and BuildDemoRecords() or {}
	Layout()
end

function Bars.IsAnchorShown()
	return anchor:IsShown()
end

function Bars.SetAnchorShown(shown)
	anchor:SetShown(shown)
	Bars.SetDemo(shown)
end

function Bars.GetBar(record)
	return barsByRecord[record]
end

function Bars.GetShownRecords()
	return shownRecords
end

-- Listen in on the tracker!
ns.Tracker:RegisterCallback("Started", function(record)
	if LootBeaconOptions and not LootBeaconOptions.barsEnabled then
		record.blizzardOwned = true
	end
	Layout()
end)
ns.Tracker:RegisterCallback("Updated", function(record)
	local bar = barsByRecord[record]
	if bar then UpdateBar(bar, record) end
end)
ns.Tracker:RegisterCallback("Closed", function()
	Layout()
end)
