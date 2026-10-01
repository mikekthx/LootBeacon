local wow = require("tests.mock.wow")

local FILES = { "locale.lua", "config.lua", "core.lua", "bars.lua", "chat.lua" }
local ns

local function Load(saved)
	wow.reset()
	_G.LootBeaconOptions = saved
	ns = wow.loadAddon(FILES)
	wow.fireAddonLoaded()
end

local function BarFor(key)
	return ns.Bars.GetBar(ns.Tracker:GetRecord(key))
end

local function LastLayout()
	local calls = wow.calls.ApplyLayout
	return calls[#calls][2], calls[#calls][1]
end

describe("the panel's frame", function()
	it("has no header while locked: a plain metal top, flipped from the bottom edge", function()
		Load()
		local layout, container = LastLayout()
		assert.equals(ns.Bars._panel.NineSlice, container)
		assert.equals("_UI-Frame-Metal-EdgeBottom", layout.TopEdge.atlas)
		assert.is_true(layout.TopEdge.flipVertical)
		assert.equals("UI-Frame-Metal-CornerBottomLeft", layout.TopLeftCorner.atlas)
		assert.equals(8, layout.TopLeftCorner.y)
		assert.equals("_UI-Frame-Metal-EdgeBottom", layout.BottomEdge.atlas)
		assert.is_falsy(layout.BottomEdge.flipVertical)
		assert.is_false(ns.Bars._panel.TitleContainer:IsShown())
	end)

	it("shows the header on top while unlocked and stacking down", function()
		Load()
		ns.Bars.SetAnchorShown(true)
		local layout = LastLayout()
		assert.equals("_UI-Frame-Metal-EdgeTop", layout.TopEdge.atlas)
		assert.is_falsy(layout.TopEdge.flipVertical)
		assert.is_true(ns.Bars._panel.TitleContainer:IsShown())
		assert.equals("TOPLEFT", (ns.Bars._panel.TitleContainer:GetPoint(1)))
	end)

	it("moves the header to the bottom while unlocked and stacking up", function()
		Load({ growDirection = "up" })
		ns.Bars.SetAnchorShown(true)
		local layout = LastLayout()
		assert.equals("_UI-Frame-Metal-EdgeTop", layout.BottomEdge.atlas)
		assert.is_true(layout.BottomEdge.flipVertical)
		assert.equals("UI-Frame-Metal-CornerTopLeft", layout.BottomLeftCorner.atlas)
		assert.equals(-16, layout.BottomLeftCorner.y)
		assert.equals("_UI-Frame-Metal-EdgeBottom", layout.TopEdge.atlas)
		assert.equals("BOTTOMLEFT", (ns.Bars._panel.TitleContainer:GetPoint(1)))
	end)

	it("hides the header again when locked", function()
		Load()
		ns.Bars.SetAnchorShown(true)
		ns.Bars.SetAnchorShown(false)
		assert.equals("_UI-Frame-Metal-EdgeBottom", LastLayout().TopEdge.atlas)
		assert.is_false(ns.Bars._panel.TitleContainer:IsShown())
	end)

	it("flips a piece's art upside down when asked", function()
		Load()
		local layout = LastLayout()
		local piece = wow.NewWidget("Texture")
		layout.setupPieceVisualsFunction(nil, piece, {}, layout.TopEdge)
		assert.same({ 0, 1, 1, 0 }, piece._texCoord)
		assert.equals("_UI-Frame-Metal-EdgeBottom", piece:GetAtlas())
		local plain = wow.NewWidget("Texture")
		layout.setupPieceVisualsFunction(nil, plain, {}, layout.BottomEdge)
		assert.same({ 0, 1, 0, 1 }, plain._texCoord)
	end)
end)

describe("rows inside the frame", function()
	it("start just under a plain top while locked", function()
		Load()
		wow.startRoll(1, 500, 60000)
		assert.same({ "TOPLEFT", ns.Bars._panel, "TOPLEFT", 12, -10 }, BarFor(500)._points[1])
		assert.equals(10 + 46 + 10, ns.Bars._panel:GetHeight())
	end)

	it("make room for the header while unlocked", function()
		Load()
		ns.Bars.SetAnchorShown(true)
		local first = ns.Bars.GetBar(ns.Bars.GetShownRecords()[1])
		assert.same({ "TOPLEFT", ns.Bars._panel, "TOPLEFT", 12, -26 }, first._points[1])
		assert.equals(26 + 3 * 46 + 2 * 6 + 10, ns.Bars._panel:GetHeight())
	end)

	it("leave the header room at the bottom when stacking up", function()
		Load({ growDirection = "up" })
		ns.Bars.SetAnchorShown(true)
		assert.equals(10 + 3 * 46 + 2 * 6 + 26, ns.Bars._panel:GetHeight())
	end)
end)

describe("row details", function()
	before_each(function()
		Load()
		wow.startRoll(1, 500, 60000, wow.ItemInfo({ bop = true }))
	end)

	it("tucks BoP right into the icon's corner", function()
		local icon = BarFor(500).icon
		assert.same({ "BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0 }, icon.bind._points[1])
	end)

	it("masks the icon's corners like Blizzard's item buttons", function()
		local icon = BarFor(500).icon
		assert.equals("Interface\\Common\\common-iconmask", icon.iconMask:GetTexture())
		assert.same({ icon.iconMask }, icon.icon._masks)
	end)

	it("keeps the timer fill inside its track", function()
		local timer = BarFor(500).timer
		assert.same({ "LEFT", timer, "LEFT", 2, 0 }, timer.fill._points[1])
		timer:SetWidth(200)
		wow.advance(30)
		BarFor(500):GetScript("OnUpdate")(BarFor(500), 0)
		assert.equals(98, timer.fill:GetWidth())
	end)

	it("scales the roll buttons smoothly instead of snapping them to pixels", function()
		local normal = BarFor(500).buttons.need:GetNormalTexture()
		assert.is_false(normal._snapToPixelGrid)
		assert.equals(0, normal._texelSnappingBias)
	end)
end)
