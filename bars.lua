local _, ns = ...
local L = ns.L

local Bars = {}
ns.Bars = Bars

-- Get in here, Globals!
local GetLootRollTimeLeft = GetLootRollTimeLeft
local GetTime = GetTime

-- Measure twice, cut once! Everything's in panel units.
local PANEL_WIDTH = 330
local CONTENT_LEFT, CONTENT_RIGHT = 16, 14 -- the left metal edge is the thicker one
local HEADER_HEIGHT, EDGE_PADDING = 29, 11 -- the title band, or a plain metal edge
local ROW_HEIGHT, ROW_GAP = 44, 17
local ROW_WIDTH = PANEL_WIDTH - CONTENT_LEFT - CONTENT_RIGHT
local ICON_SIZE = ROW_HEIGHT -- as tall as the button grid
local BUTTON_SIZE, BUTTON_GAP = 21, 2
local BUTTON_AREA = 2 * BUTTON_SIZE + BUTTON_GAP
local BUTTON_GRID = { need = { 1, 1 }, pass = { 2, 1 }, greed = { 1, 2 } } -- column, row; bottom right stays empty
local PASS_NUDGE = 2 -- Pass's art has a wide margin on its right
local CONTENT_GAP = 8
local NAME_GAP = 2

-- Blizzard's timer, on a diet! Rounded ends keep their shape and the middle stretches.
local TIMER_ART_HEIGHT, TIMER_HEIGHT = 13, 10
local TIMER_SCALE = TIMER_HEIGHT / TIMER_ART_HEIGHT
local TIMER_INSET = 2 * TIMER_SCALE
local TIMER_CAP, TIMER_FILL_CAP = 7, 5 -- the ends' widths in the art
local TIMER_FILL_END = TIMER_FILL_CAP * TIMER_SCALE
local TIMER_RAISE = 3 -- clears the icon border's cut corner

-- Borrow the quest tracker's header art and stitch its top and bottom rods into one! Columns and rows of the art.
local ROD_ATLAS, ROD_ART_WIDTH, ROD_ART_HEIGHT = "ui-questtracker-primary-objective-header", 300, 40
local ROD_LEFT, ROD_CAP = 9.7, 16.45 -- the left diamond, tip to bar
local ROD_FADE = { 200, 277 } -- gone before the right diamond starts
local ROD_OVERHANG = 3 -- past the icon, short of the metal edge
local ROD_UPPER = { 2.9, 7.07 }
local ROD_LOWER = { ROD_UPPER[2] + 27.47, 38.6 } -- 27.47 keeps the diamonds whole (the bar is only 26.93 apart)

local BASE_LAYOUT = "ButtonFrameTemplateNoPortrait"
local BUTTON_ATLAS = "lootroll-toast-icon-" -- then the choice, then its state
local DEMO_DURATION = 60000
local MAX_DEMO_ROLLS = 20
local QUESTION_MARK_ICON = 134400

local CHOICE_LABELS = { need = NEED, greed = GREED, pass = PASS }

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
	local flip = pieceLayout.flipVertical
	piece:SetTexCoord(0, 1, flip and 1 or 0, flip and 0 or 1)
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

-- Give one side of the frame the `from` side's art, flipped over if asked!
local function SetSide(layout, base, side, from, flip)
	for _, part in ipairs({ "LeftCorner", "RightCorner", "Edge" }) do
		local piece = base[from .. part]
		layout[side .. part] = flip and FlippedPiece(piece) or piece
	end
end

-- The title band only shows while you're moving the panel, on whichever side stays pinned!
local function BuildFrameLayout(header)
	local base = NineSliceLayouts[BASE_LAYOUT]
	local layout = {
		disableSharpening = base.disableSharpening,
		setupPieceVisualsFunction = SetupPieceVisuals,
		LeftEdge = base.LeftEdge,
		RightEdge = base.RightEdge,
	}
	local top, bottom = header == "top", header == "bottom"
	SetSide(layout, base, "Top", top and "Top" or "Bottom", not top)
	SetSide(layout, base, "Bottom", bottom and "Top" or "Bottom", bottom)
	return layout
end

local header      -- "top", "bottom" or nil
local frameLayout -- the layout ApplyFrameStyle last put on the panel

-- Blizzard's corners are tall, so on a short panel trim each pair to meet halfway!
local CORNER_SIDES = {
	TopLeftCorner = "top",
	TopRightCorner = "top",
	BottomLeftCorner = "bottom",
	BottomRightCorner = "bottom",
}
local CORNER_REACH = 42 -- the post has a notch about 44 in; the plain edge takes over from there

local function FitCorners(height)
	for name, side in pairs(CORNER_SIDES) do
		local pieceLayout, piece = frameLayout[name], panel.NineSlice[name]
		local info = C_Texture.GetAtlasInfo(pieceLayout.atlas)
		if piece and info then
			local shown = math.min(info.height, math.abs(pieceLayout.y or 0) + math.min(height / 2, CORNER_REACH))
			local first, last = 0, 1 -- the art's rows, from the piece's top to its bottom
			if pieceLayout.flipVertical then first, last = 1, 0 end
			local span = (last - first) * shown / info.height
			if side == "top" then
				piece:SetTexCoord(0, 1, first, first + span)
			else
				piece:SetTexCoord(0, 1, last - span, last)
			end
			piece:SetHeight(shown)
		end
	end
end

local function ApplyFrameStyle()
	header = unlocked and (GrowsUp() and "bottom" or "top") or nil
	frameLayout = BuildFrameLayout(header)
	NineSliceUtil.ApplyLayout(panel.NineSlice, frameLayout)
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
	local width = math.max(1, (row.timer:GetWidth() - 2 * TIMER_INSET) * fraction)
	row.timer.fill:SetWidth(width)
	-- Nearly empty? Then the fill's two ends share what's left.
	local cap = math.min(TIMER_FILL_END, width / 2)
	row.timer.fillArt.left:SetWidth(cap)
	row.timer.fillArt.right:SetWidth(cap)
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
	-- Shift means "yes, I'm sure!" Noted before rolling, in case the game asks straight away.
	pendingConfirms[record.rollID] = (IsShiftKeyDown() and button.choice ~= "pass") and button.rollType or nil
	RollOnLoot(record.rollID, button.rollType)
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
confirmWatcher:SetScript("OnEvent", OnConfirmRequest)

local function OnRollEnter(button)
	local record = button.row.record
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip_SetTitle(GameTooltip, CHOICE_LABELS[button.choice])
	if not button:IsEnabled() and button.reason then
		GameTooltip_AddErrorLine(GameTooltip, button.reason, true)
	end
	for _, player in ipairs(record and record.choices[button.choice] or {}) do
		GameTooltip:AddLine(ns.ClassColoredName(player.name, player.class))
	end
	GameTooltip:Show()
end

local function ShowItemTooltip(icon)
	local record = icon.row.record
	if not record then return end
	GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
	if record.demo then
		GameTooltip:SetHyperlink("item:" .. record.itemID) -- works even before the item's details arrive
	else
		GameTooltip:SetLootRollItem(record.rollID)
	end
	GameTooltip:Show()
end

-- Let the art scale smoothly instead of snapping to whole pixels!
local function SmoothScaling(texture)
	texture:SetSnapToPixelGrid(false)
	texture:SetTexelSnappingBias(0)
end

-- Shave off the atlas neighbours bleeding in round the edges!
local ATLAS_EDGE_TRIM = 1.5 -- texels; measured in-game: 1 still bleeds, 2 crops the art

local function TrimAtlasEdges(texture)
	local info = C_Texture.GetAtlasInfo(texture:GetAtlas())
	if not info then return end
	local x, y = ATLAS_EDGE_TRIM / info.width, ATLAS_EDGE_TRIM / info.height
	texture:SetTexCoord(x, 1 - x, y, 1 - y)
end

local function CreateRollButton(row, choice)
	local button = CreateFrame("Button", nil, row)
	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	button.row = row
	button.choice = choice
	button.rollType = ns.ROLL[choice]
	local atlas = BUTTON_ATLAS .. choice
	button:SetNormalAtlas(atlas .. "-up")
	button:SetPushedAtlas(atlas .. "-down")
	button:SetHighlightAtlas(atlas .. "-highlight", "ADD")
	for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture() }) do
		SmoothScaling(texture)
		TrimAtlasEdges(texture)
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

-- A slice of the rod, at the art's own size!
local function RodPiece(divider, left, right, rows)
	local piece = divider:CreateTexture(nil, "BACKGROUND")
	piece:SetAtlas(ROD_ATLAS)
	piece:SetTexCoord(left / ROD_ART_WIDTH, right / ROD_ART_WIDTH, rows[1] / ROD_ART_HEIGHT, rows[2] / ROD_ART_HEIGHT)
	piece:SetSize(right - left, rows[2] - rows[1])
	SmoothScaling(piece)
	return piece
end

-- Diamond, bar, then fade away to nothing! `edge` is the side that sits on the divider's centre.
local function RodHalf(divider, rows, edge)
	local half = {
		cap = RodPiece(divider, ROD_LEFT, ROD_CAP, rows),
		bar = RodPiece(divider, ROD_CAP, ROD_FADE[1], rows),
		fade = RodPiece(divider, ROD_FADE[1], ROD_FADE[2], rows),
	}
	half.cap:SetPoint(edge .. "LEFT", divider, "LEFT", -ROD_OVERHANG, 0)
	half.bar:SetPoint(edge .. "LEFT", half.cap, edge .. "RIGHT")
	half.fade:SetPoint(edge .. "LEFT", half.bar, edge .. "RIGHT")
	half.fade:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 0))
	return half
end

local function Slice(owner, layer, atlas, left, right)
	local slice = owner:CreateTexture(nil, layer)
	slice:SetAtlas(atlas)
	slice:SetTexCoord(left, right, 0, 1)
	SmoothScaling(slice) -- snapped separately, the pieces could part by a pixel
	return slice
end

-- Two ends that keep their shape and a middle that stretches, all scaled with the timer!
local function ThreeSlice(owner, region, layer, atlas, cap)
	local info = C_Texture.GetAtlasInfo(atlas)
	local edge = cap / (info and info.width or TIMER_ART_HEIGHT)
	cap = cap * TIMER_SCALE
	local slices = {
		left = Slice(owner, layer, atlas, 0, edge),
		middle = Slice(owner, layer, atlas, edge, 1 - edge),
		right = Slice(owner, layer, atlas, 1 - edge, 1),
	}
	slices.left:SetPoint("TOPLEFT", region, "TOPLEFT")
	slices.left:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT")
	slices.left:SetWidth(cap)
	slices.right:SetPoint("TOPRIGHT", region, "TOPRIGHT")
	slices.right:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT")
	slices.right:SetWidth(cap)
	slices.middle:SetPoint("TOPLEFT", slices.left, "TOPRIGHT")
	slices.middle:SetPoint("BOTTOMRIGHT", slices.right, "BOTTOMLEFT")
	return slices
end

local function CreateRow()
	local row = CreateFrame("Frame", nil, panel)
	row:SetSize(ROW_WIDTH, ROW_HEIGHT)

	-- A real item button, quality border and all, just like the character sheet!
	local icon = CreateFrame("ItemButton", nil, row)
	icon:ClearNormalTexture()
	icon.row = row
	-- Lay the art right over the button, not its own 37x37 centred on a half pixel!
	icon.icon:ClearAllPoints()
	icon.icon:SetAllPoints(icon)
	icon.IconBorder:ClearAllPoints()
	icon.IconBorder:SetAllPoints(icon)
	-- Round off the icon's corners so they never peek past the border!
	icon.iconMask = icon:CreateMaskTexture()
	icon.iconMask:SetTexture("Interface\\Common\\common-iconmask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	icon.iconMask:SetAllPoints(icon.icon)
	icon.icon:AddMaskTexture(icon.iconMask)
	icon.bind = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	icon.bind:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 2, 1) -- just inside the quality border
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

	-- Roll buttons, two by two on the right!
	row.buttons = {}
	for _, choice in ipairs(ns.CHOICES) do
		local button = CreateRollButton(row, choice)
		local column, line = BUTTON_GRID[choice][1], BUTTON_GRID[choice][2]
		local x = -(2 - column) * (BUTTON_SIZE + BUTTON_GAP)
		if choice == "pass" then x = x + PASS_NUDGE end
		if line == 1 then
			button:SetPoint("TOPRIGHT", row, "TOPRIGHT", x, 0)
		else
			button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", x, 0)
		end
		row.buttons[choice] = button
	end

	-- The timer runs along the bottom, between the icon and the buttons!
	local timer = CreateFrame("Frame", nil, row)
	timer:SetHeight(TIMER_HEIGHT)
	timer:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", CONTENT_GAP, TIMER_RAISE)
	timer:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -(BUTTON_AREA + CONTENT_GAP), TIMER_RAISE)
	timer.background = ThreeSlice(timer, timer, "BACKGROUND", "lootroll-timer-background", TIMER_CAP)
	-- Inset like Blizzard's, so the fill stays inside the track! UpdateTimer sizes it and the art follows.
	local fillInfo = C_Texture.GetAtlasInfo("lootroll-timer-fill")
	timer.fill = timer:CreateTexture(nil, "ARTWORK")
	timer.fill:SetHeight((fillInfo and fillInfo.height or TIMER_ART_HEIGHT - 4) * TIMER_SCALE)
	timer.fill:SetPoint("LEFT", timer, "LEFT", TIMER_INSET, 0)
	SmoothScaling(timer.fill) -- so its end slides between pixels instead of ticking from one to the next
	timer.fillArt = ThreeSlice(timer, timer.fill, "ARTWORK", "lootroll-timer-fill", TIMER_FILL_CAP)
	timer.border = ThreeSlice(timer, timer, "OVERLAY", "lootroll-timer-border", TIMER_CAP)
	row.timer = timer

	-- Up to two lines of name above the timer!
	row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	row.name:SetJustifyH("LEFT")
	row.name:SetJustifyV("MIDDLE")
	row.name:SetWordWrap(true)
	row.name:SetMaxLines(2)
	row.name:SetPoint("TOPLEFT", icon, "TOPRIGHT", CONTENT_GAP, 0)
	row.name:SetPoint("BOTTOMRIGHT", timer, "TOPRIGHT", 0, NAME_GAP)

	-- A metal rod between rows, its two halves meeting in the middle!
	row.divider = CreateFrame("Frame", nil, row)
	row.divider:SetSize(ROW_WIDTH, 1)
	row.divider.upper = RodHalf(row.divider, ROD_UPPER, "BOTTOM")
	row.divider.lower = RodHalf(row.divider, ROD_LOWER, "TOP")

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
	SetButtonUsable(buttons.need, ready and record.canNeed, ready and IneligibleReason(record.reasonNeed) or nil)
	SetButtonUsable(buttons.greed, ready and record.canGreed, ready and IneligibleReason(record.reasonGreed) or nil)
	SetButtonUsable(buttons.pass, true)

	for choice, button in pairs(buttons) do
		local count = #(record.choices[choice] or {})
		button.count:SetText(count > 0 and tostring(count) or "")
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

	-- Snap everything to whole pixels, every time, since the scale moves them. Every row looks the same!
	local top = header == "top" and HEADER_HEIGHT or EDGE_PADDING
	for index, record in ipairs(ordered) do
		local row = barsByRecord[record]
		if not row then
			row = table.remove(pool) or CreateRow()
			barsByRecord[record] = row
		end
		UpdateRow(row, record)
		row:ClearAllPoints()
		PixelUtil.SetPoint(row, "TOPLEFT", panel, "TOPLEFT", CONTENT_LEFT, -(top + (index - 1) * (ROW_HEIGHT + ROW_GAP)))
		PixelUtil.SetSize(row.icon, ICON_SIZE, ICON_SIZE)
		row.icon:ClearAllPoints()
		PixelUtil.SetPoint(row.icon, "TOPLEFT", row, "TOPLEFT", 0, 0)
		row.divider:ClearAllPoints()
		PixelUtil.SetPoint(row.divider, "CENTER", row, "TOP", 0, -(ROW_HEIGHT + ROW_GAP / 2))
		row.divider:SetShown(index < #ordered)
		row:Show()
	end

	local count = #ordered
	if count > 0 then
		local bottom = header == "bottom" and HEADER_HEIGHT or EDGE_PADDING
		local height = top + count * ROW_HEIGHT + (count - 1) * ROW_GAP + bottom
		panel:SetHeight(height)
		FitCorners(height)
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
	PixelUtil.SetPoint(panel, GrowsUp() and "BOTTOM" or "TOP", UIParent, "CENTER", saved.x / scale, saved.y / scale)
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
	if not left then
		-- Still hidden, with no position worked out yet? Then judge the saved spot itself.
		local anchor = LootBeaconOptions.anchor
		return math.abs(anchor.x) <= UIParent:GetWidth() / 2 and math.abs(anchor.y) <= UIParent:GetHeight() / 2
	end
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

-- Pretend rolls, for lining things up without a group! Every quality, a two-line name and Bind on Pickup.
local DEMO_ITEMS = {
	{
		itemID = 2073, -- Dwarven Hatchet
		choices = {
			need = { { name = "Charlie", class = "DRUID" } },
			greed = { { name = "Alpha", class = "MAGE" }, { name = "Bravo", class = "ROGUE" } },
		},
	},
	{
		itemID = 13136, -- Lil Timmy's Peashooter
		choices = { pass = { { name = "Delta", class = "PALADIN" } } },
	},
	{
		itemID = 21615, -- Don Rigoberto's Lost Hat
		choices = {
			need = { { name = "Echo", class = "HUNTER" }, { name = "Golf", class = "PRIEST" } },
			greed = { { name = "Alpha", class = "MAGE" } },
		},
	},
	{
		itemID = 19019, -- Thunderfury, Blessed Blade of the Windseeker
		choices = {
			need = { { name = "Bravo", class = "ROGUE" }, { name = "Foxtrot", class = "WARRIOR" }, { name = "Echo", class = "HUNTER" } },
			greed = { { name = "Delta", class = "PALADIN" } },
			pass = { { name = "Alpha", class = "MAGE" } },
		},
	},
}

-- Raid the item cache! False if the client hasn't got it yet.
local function FillDemoRecord(record)
	local name, link, quality, _, _, _, _, _, _, texture, _, _, _, bindType = C_Item.GetItemInfo(record.itemID)
	if not name then return false end
	record.name, record.link, record.quality, record.texture = name, link, quality, texture
	record.bindOnPickUp = bindType == Enum.ItemBind.OnAcquire
	record.pending = false
	return true
end

local function DemoRecord(key, item)
	local record = {
		key = key,
		demo = true,
		itemID = item.itemID,
		startTime = GetTime(),
		duration = DEMO_DURATION,
		count = 1,
		canNeed = true,
		canGreed = true,
		reasonNeed = 0,
		reasonGreed = 0,
		pending = true,
		choices = ns.NewChoices(),
	}
	for choice, players in pairs(item.choices) do
		record.choices[choice] = players
	end
	if not FillDemoRecord(record) then
		C_Item.RequestLoadItemDataByID(record.itemID) -- the row says "Retrieving item information" until it lands
	end
	return record
end

local function BuildDemoRecords(count)
	local records = {}
	for index = 1, count do
		records[index] = DemoRecord("demo:" .. index, DEMO_ITEMS[(index - 1) % #DEMO_ITEMS + 1])
	end
	return records
end

-- Special delivery for any sample still waiting on its item!
local itemLoader = CreateFrame("Frame")
itemLoader:RegisterEvent("ITEM_DATA_LOAD_RESULT")
itemLoader:SetScript("OnEvent", function(_, _, itemID, success)
	if not success then return end
	for _, record in ipairs(demoRecords) do
		if record.pending and record.itemID == itemID and FillDemoRecord(record) then
			local row = barsByRecord[record]
			if row then UpdateRow(row, record) end
		end
	end
end)

function Bars.IsDemo()
	return demoMode
end

-- Show `count` sample rolls (all four items if you don't say), or put them away.
function Bars.SetDemo(on, count)
	on = on and true or false
	count = on and math.max(1, math.min(MAX_DEMO_ROLLS, math.floor(count or #DEMO_ITEMS))) or 0
	if on == demoMode and count == #demoRecords then return end
	demoMode = on
	demoRecords = on and BuildDemoRecords(count) or {}
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
ns.Tracker:RegisterCallback("Closed", function(record)
	-- Roll IDs get recycled, so don't pass this promise on to the next roll with this number!
	if record.rollID then pendingConfirms[record.rollID] = nil end
	Layout()
end)
