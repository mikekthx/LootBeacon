local _, ns = ...
local L = ns.L

local Bars = {}
ns.Bars = Bars

-- Get in here, Globals!
local GetLootRollTimeLeft = GetLootRollTimeLeft
local GetTime = GetTime

-- Panel layout, in panel units. The panel is Blizzard's own DefaultPanelFlatTemplate --
-- the same metal-framed panel the Loot Rolls window uses.
local PANEL_WIDTH = 320
local CONTENT_LEFT, CONTENT_RIGHT = 12, 8
local HEADER_HEIGHT, EDGE_PADDING = 26, 10 -- room for the title band, or for a plain metal edge
local ROW_HEIGHT, ROW_GAP = 46, 6
local ROW_WIDTH = PANEL_WIDTH - CONTENT_LEFT - CONTENT_RIGHT
local ICON_SIZE = 37 -- the ItemButton's own size, same as the character sheet's slots
local ICON_INSET = (ROW_HEIGHT - ICON_SIZE) / 2
local BUTTON_SIZE, BUTTON_GAP = 24, 2
local BUTTON_AREA = 4 * BUTTON_SIZE + 3 * BUTTON_GAP -- always room for Need, Greed, Disenchant and Pass
local TIMER_HEIGHT, TIMER_INSET = 13, 2 -- Blizzard's own Loot Rolls timer track and fill inset
local BASE_LAYOUT = "ButtonFrameTemplateNoPortrait" -- Blizzard's no-portrait panel frame, as this client draws it
local DEMO_DURATION = 60000
local QUESTION_MARK_ICON = 134400

-- Blizzard's own roll-button art, plus the old Disenchant files since there's no new one!
local BUTTON_ART = {
	need = { atlas = "lootroll-toast-icon-need" },
	greed = { atlas = "lootroll-toast-icon-greed" },
	disenchant = { file = "Interface\\Buttons\\UI-GroupLoot-DE" },
	pass = { atlas = "lootroll-toast-icon-pass" },
}

-- Right to left, the way the buttons line up on the row.
local BUTTON_ORDER = { "pass", "disenchant", "greed", "need" }

local function ChoiceLabel(choice)
	if choice == "need" then return NEED end
	if choice == "greed" then return GREED end
	if choice == "disenchant" then return ROLL_DISENCHANT end
	return PASS
end

local function IneligibleReason(index)
	if not index or index == 0 then return nil end
	return _G["LOOT_ROLL_INELIGIBLE_REASON" .. index]
end

-- One tidy panel to hold every roll!
local panel = CreateFrame("Frame", "LootBeaconPanel", UIParent, "DefaultPanelFlatTemplate")
panel:SetSize(PANEL_WIDTH, EDGE_PADDING + ROW_HEIGHT + EDGE_PADDING)
panel:SetFrameStrata("HIGH")
panel:SetMovable(true)
panel:SetClampedToScreen(true)
panel:EnableMouse(false)
panel:RegisterForDrag("LeftButton")
panel:SetTitle(LOOT_ROLLS)
panel:Hide()
Bars._panel = panel

local pool, barsByRecord = {}, {}
local pendingConfirms = {} -- rollID -> roll type we promised to confirm
local shownRecords = {}
local demoMode, demoRecords = false, {}
local unlocked = false
local lastEnabled, lastGrowUp, wasActive
local Layout -- defined further down; everything needs it!

function Bars.IsActive()
	return (LootBeaconOptions and LootBeaconOptions.barsEnabled and not InputUtil.IsGamepadUIEnabled()) and true or false
end

local function GrowsUp()
	return LootBeaconOptions ~= nil and LootBeaconOptions.growDirection == "up"
end

-- Same job as Blizzard's own piece setup, plus the option to turn a piece upside down!
local function SetupPieceVisuals(_, piece, _, pieceLayout)
	if pieceLayout.flipVertical then
		piece:SetTexCoord(0, 1, 1, 0)
	else
		piece:SetTexCoord(0, 1, 0, 1)
	end
	local info = C_Texture.GetAtlasInfo(pieceLayout.atlas)
	piece:SetHorizTile(info and info.tilesHorizontally or false)
	piece:SetVertTile(info and info.tilesVertically or false)
	if info then
		piece:SetAtlas(pieceLayout.atlas, true)
	end
end

local function FlippedPiece(from)
	return { layer = from.layer, atlas = from.atlas, x = from.x, y = from.y and -from.y, flipVertical = true }
end

-- The title band only shows while you're moving the panel, on whichever side stays pinned!
local function BuildFrameLayout(header)
	local base = NineSliceLayouts[BASE_LAYOUT]
	local layout = {
		disableSharpening = base.disableSharpening,
		setupPieceVisualsFunction = SetupPieceVisuals,
		LeftEdge = base.LeftEdge, RightEdge = base.RightEdge,
	}
	if header == "top" then
		layout.TopLeftCorner, layout.TopRightCorner, layout.TopEdge = base.TopLeftCorner, base.TopRightCorner, base.TopEdge
	else
		layout.TopLeftCorner = FlippedPiece(base.BottomLeftCorner)
		layout.TopRightCorner = FlippedPiece(base.BottomRightCorner)
		layout.TopEdge = FlippedPiece(base.BottomEdge)
	end
	if header == "bottom" then
		layout.BottomLeftCorner = FlippedPiece(base.TopLeftCorner)
		layout.BottomRightCorner = FlippedPiece(base.TopRightCorner)
		layout.BottomEdge = FlippedPiece(base.TopEdge)
	else
		layout.BottomLeftCorner, layout.BottomRightCorner, layout.BottomEdge = base.BottomLeftCorner, base.BottomRightCorner, base.BottomEdge
	end
	return layout
end

local header -- "top", "bottom" or nil

local function ApplyFrameStyle()
	header = unlocked and (GrowsUp() and "bottom" or "top") or nil
	NineSliceUtil.ApplyLayout(panel.NineSlice, BuildFrameLayout(header))
	panel.Bg:ClearAllPoints()
	panel.Bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, header == "top" and -20 or -2)
	panel.Bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, header == "bottom" and 20 or 2)
	local title = panel.TitleContainer
	title:ClearAllPoints()
	if header == "bottom" then
		title:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 30, 1)
		title:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 1)
	else
		title:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, -1)
		title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -1)
	end
	title:SetShown(header ~= nil)
end

-- Blizzard asks to show a roll window; while we're on duty, we'll take it from here!
local blizzardAddRoll = GroupLootContainer_AddRoll
GroupLootContainer_AddRoll = function(rollID, rollTime)
	local record = ns.Tracker:GetRecordByRollID(rollID)
	-- Blizzard's already got this one (e.g. pulled from its own waiting line)? Let it finish the job!
	if Bars.IsActive() and not (record and record.blizzardOwned) then
		Bars.Refresh() -- e.g. returning from Gamepad style: Blizzard's RefreshRolls lands here, so wake the rows
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

local function UpdateTimer(row)
	local record = row.record
	if not record then return end
	local fraction = 0
	if record.duration and record.duration > 0 then
		fraction = math.min(1, math.max(0, TimeLeft(record) / record.duration))
	end
	row.timer.fill:SetWidth(math.max(1, (row.timer:GetWidth() - 2 * TIMER_INSET) * fraction))
end

local function HideTooltip()
	GameTooltip:Hide()
end

local function OnRollClick(button)
	local record = button.row.record
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
	local record = button.row.record
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
	local record = icon.row.record
	if not record then return end
	GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
	if record.demo then
		GameTooltip:SetHyperlink(record.link)
	else
		GameTooltip:SetLootRollItem(record.rollID)
	end
	GameTooltip:Show()
end

local function CreateRollButton(row, choice)
	local button = CreateFrame("Button", nil, row)
	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	button.row = row
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
	-- Let the art scale smoothly instead of snapping to whole pixels!
	for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture() }) do
		texture:SetSnapToPixelGrid(false)
		texture:SetTexelSnappingBias(0)
	end
	button:SetMotionScriptsWhileDisabled(true)
	-- Tucked inside the button's corner, so it never crowds the next one!
	button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 1)
	button:SetScript("OnClick", OnRollClick)
	button:SetScript("OnEnter", OnRollEnter)
	button:SetScript("OnLeave", HideTooltip)
	return button
end

local function CreateRow()
	local row = CreateFrame("Frame", nil, panel)
	row:SetSize(ROW_WIDTH, ROW_HEIGHT)

	-- A real item button: icon plus quality border, just like the character sheet!
	local icon = CreateFrame("ItemButton", nil, row)
	icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	icon:ClearNormalTexture()
	icon.row = row
	-- Round off the icon's corners so they never peek past the border!
	icon.iconMask = icon:CreateMaskTexture()
	icon.iconMask:SetTexture("Interface\\Common\\common-iconmask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	icon.iconMask:SetAllPoints(icon.icon)
	icon.icon:AddMaskTexture(icon.iconMask)
	icon.bind = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	icon.bind:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
	icon.bind:SetTextColor(1, 0.3, 0.1)
	icon.bind:SetText(L["BoP"])
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
		local record = self.row.record
		if record and record.link then HandleModifiedItemClick(record.link) end
	end)
	row.icon = icon

	-- Top line: the name gets the whole width!
	row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
	row.name:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -ICON_INSET - 1)

	-- Bottom line: timer on the left, buttons on the right.
	row.buttons = {}
	for _, choice in ipairs(ns.CHOICES) do
		row.buttons[choice] = CreateRollButton(row, choice)
	end

	-- The same three-piece timer Blizzard's Loot Rolls window uses!
	local timerLift = (BUTTON_SIZE - TIMER_HEIGHT) / 2 -- centred on the buttons beside it
	local timer = CreateFrame("Frame", nil, row)
	timer:SetHeight(TIMER_HEIGHT)
	timer:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, timerLift)
	timer:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -(BUTTON_AREA + 8), ICON_INSET + timerLift)
	timer.background = timer:CreateTexture(nil, "BACKGROUND")
	timer.background:SetAllPoints(timer)
	timer.background:SetAtlas("lootroll-timer-background")
	-- Native-height fill, inset like Blizzard's, so it stays inside the track!
	timer.fill = timer:CreateTexture(nil, "ARTWORK")
	timer.fill:SetAtlas("lootroll-timer-fill", true)
	timer.fill:SetPoint("LEFT", timer, "LEFT", TIMER_INSET, 0)
	timer.border = timer:CreateTexture(nil, "OVERLAY")
	timer.border:SetAllPoints(timer)
	timer.border:SetAtlas("lootroll-timer-border")
	row.timer = timer

	-- A faint line between rows.
	row.divider = row:CreateTexture(nil, "BACKGROUND")
	row.divider:SetColorTexture(1, 1, 1, 0.08)
	row.divider:SetHeight(1)
	row.divider:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -ROW_GAP / 2)
	row.divider:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -ROW_GAP / 2)

	row:SetScript("OnUpdate", UpdateTimer)
	return row
end

local function SetButtonUsable(button, usable, reason)
	usable = usable and true or false
	button:SetEnabled(usable)
	button:SetAlpha(usable and 1 or 0.35)
	button:GetNormalTexture():SetDesaturated(not usable)
	button.reason = (not usable) and reason or nil
end

local function UpdateRow(row, record)
	row.record = record
	local ready = not record.pending
	local icon = row.icon
	SetItemButtonTexture(icon, record.texture or QUESTION_MARK_ICON)
	SetItemButtonQuality(icon, record.quality, record.link)
	SetItemButtonCount(icon, record.count or 1)
	icon.bind:SetShown(ready and record.bindOnPickUp or false)

	if ready then
		row.name:SetText(record.name or UNKNOWN)
		local color = ColorManager.GetColorDataForItemQuality(record.quality)
		if color then row.name:SetTextColor(color.r, color.g, color.b) end
	else
		row.name:SetText(RETRIEVING_ITEM_INFO)
		row.name:SetTextColor(0.6, 0.6, 0.6)
	end

	local buttons = row.buttons
	buttons.disenchant:SetShown(ready and record.canDisenchant or false)
	SetButtonUsable(buttons.need, ready and record.canNeed, ready and IneligibleReason(record.reasonNeed) or nil)
	SetButtonUsable(buttons.greed, ready and record.canGreed, ready and IneligibleReason(record.reasonGreed) or nil)
	SetButtonUsable(buttons.disenchant, true)
	SetButtonUsable(buttons.pass, true)

	for choice, button in pairs(buttons) do
		local count = #(record.choices[choice] or {})
		button.count:SetText(count > 0 and tostring(count) or "")
	end

	-- Right-aligned in a fixed-width area, so every timer lines up!
	local previous
	for _, choice in ipairs(BUTTON_ORDER) do
		local button = buttons[choice]
		if button:IsShown() then
			button:ClearAllPoints()
			if previous then
				button:SetPoint("RIGHT", previous, "LEFT", -BUTTON_GAP, 0)
			else
				button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, ICON_INSET)
			end
			previous = button
		end
	end
	UpdateTimer(row)
end

-- Gamepad mode can flip at any time; keep an eye out while rolls are up!
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
	for record, row in pairs(barsByRecord) do
		if not wanted[record] then
			row:Hide()
			row.record = nil
			barsByRecord[record] = nil
			pool[#pool + 1] = row
		end
	end

	-- Stacking up? The newest roll sits on top, farthest from the pinned edge.
	local ordered = records
	if GrowsUp() then
		ordered = {}
		for index = #records, 1, -1 do ordered[#ordered + 1] = records[index] end
	end

	local previous
	for index, record in ipairs(ordered) do
		local row = barsByRecord[record]
		if not row then
			row = table.remove(pool) or CreateRow()
			barsByRecord[record] = row
		end
		UpdateRow(row, record)
		row:ClearAllPoints()
		if previous then
			row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -ROW_GAP)
		else
			row:SetPoint("TOPLEFT", panel, "TOPLEFT", CONTENT_LEFT, -(header == "top" and HEADER_HEIGHT or EDGE_PADDING))
		end
		row.divider:SetShown(index < #ordered)
		row:Show()
		previous = row
	end

	local count = #ordered
	if count > 0 then
		local topRoom = header == "top" and HEADER_HEIGHT or EDGE_PADDING
		local bottomRoom = header == "bottom" and HEADER_HEIGHT or EDGE_PADDING
		panel:SetHeight(topRoom + count * ROW_HEIGHT + (count - 1) * ROW_GAP + bottomRoom)
	end
	panel:SetShown(count > 0)
	shownRecords = records
	panel:SetScript("OnUpdate", count > 0 and CheckActive or nil)
end

-- How many screen units one panel unit is.
local function ScreenRatio()
	return panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

-- Pin the panel's top edge (stacking down) or bottom edge (stacking up) to the saved spot!
local function ApplyPosition()
	local saved = LootBeaconOptions.anchor
	local scale = panel:GetScale()
	panel:ClearAllPoints()
	panel:SetPoint(GrowsUp() and "BOTTOM" or "TOP", UIParent, "CENTER", saved.x / scale, saved.y / scale)
end

local function SavePosition()
	local left, right, top, bottom = panel:GetLeft(), panel:GetRight(), panel:GetTop(), panel:GetBottom()
	if not (left and right and top and bottom) then return end
	local ratio = ScreenRatio()
	LootBeaconOptions.anchor = {
		x = (left + right) / 2 * ratio - UIParent:GetWidth() / 2,
		y = (GrowsUp() and bottom or top) * ratio - UIParent:GetHeight() / 2,
	}
	ApplyPosition()
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

	-- Flipped the stacking direction? Pin the other edge without moving the panel!
	local growUp = GrowsUp()
	if lastGrowUp ~= nil and growUp ~= lastGrowUp then
		local height = panel:GetHeight() * ScreenRatio()
		local anchor = LootBeaconOptions.anchor
		anchor.y = growUp and (anchor.y - height) or (anchor.y + height)
	end
	lastGrowUp = growUp

	panel:SetScale(LootBeaconOptions.scale)
	ApplyFrameStyle()
	ApplyPosition()
	Layout()
end

local function IsOnScreen()
	local left, bottom, width, height = panel:GetRect()
	if not left then return true end
	local ratio = ScreenRatio()
	left, bottom, width, height = left * ratio, bottom * ratio, width * ratio, height * ratio
	return left + width > 0 and bottom + height > 0 and left < UIParent:GetWidth() and bottom < UIParent:GetHeight()
end

function Bars.Init()
	lastEnabled = LootBeaconOptions.barsEnabled
	lastGrowUp = GrowsUp()
	panel:SetScale(LootBeaconOptions.scale)
	ApplyPosition()
	-- Lost somewhere past the edge of the screen? Come on home!
	if not IsOnScreen() then
		LootBeaconOptions.anchor = ns.CopyAnchor(ns.defaults.anchor)
		ApplyPosition()
	end
	Bars.Refresh()
end

panel:SetScript("OnDragStart", function()
	if unlocked then panel:StartMoving() end
end)
panel:SetScript("OnDragStop", function()
	panel:StopMovingOrSizing()
	SavePosition()
end)
panel:SetScript("OnMouseUp", function(_, button)
	if unlocked and button == "RightButton" then
		Bars.SetAnchorShown(false)
	end
end)

-- Pretend rolls, for lining things up without a group!
local function DemoRecord(key, o)
	local record = {
		key = key, demo = true, startTime = GetTime(), duration = DEMO_DURATION,
		texture = o.texture, name = o.name, link = o.link, count = 1, quality = o.quality,
		bindOnPickUp = o.bop, canNeed = o.canNeed, canGreed = true,
		canDisenchant = o.canDisenchant or false,
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
			quality = Enum.ItemQuality.Epic, bop = true, canNeed = true, canDisenchant = true,
			choices = {
				need = { { name = "Echo", class = "HUNTER" } },
				disenchant = { { name = "Alpha", class = "MAGE" } },
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
	return unlocked
end

-- Unlocked: grab the panel anywhere to drag it, right-click to lock it again.
function Bars.SetAnchorShown(shown)
	unlocked = shown and true or false
	panel:EnableMouse(unlocked)
	panel:SetTitle(unlocked and L["LootBeacon: drag to move, right-click to lock"] or LOOT_ROLLS)
	ApplyFrameStyle()
	Bars.SetDemo(unlocked)
	Layout() -- the header moved, so the rows shift too
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
	local row = barsByRecord[record]
	if row then UpdateRow(row, record) end
end)
ns.Tracker:RegisterCallback("Closed", function()
	Layout()
end)
