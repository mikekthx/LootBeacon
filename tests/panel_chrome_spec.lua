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
		assert.same({ "TOPLEFT", ns.Bars._panel, "TOPLEFT", 16, -8 }, BarFor(500)._points[1])
		assert.equals(8 + 39 + 8, ns.Bars._panel:GetHeight())
	end)

	it("make room for the header while unlocked", function()
		Load()
		ns.Bars.SetAnchorShown(true)
		local first = ns.Bars.GetBar(ns.Bars.GetShownRecords()[1])
		assert.same({ "TOPLEFT", ns.Bars._panel, "TOPLEFT", 16, -26 }, first._points[1])
		assert.equals(26 + 4 * 39 + 3 * 8 + 8, ns.Bars._panel:GetHeight())
	end)

	it("leave the header room at the bottom when stacking up", function()
		Load({ growDirection = "up" })
		ns.Bars.SetAnchorShown(true)
		assert.equals(8 + 4 * 39 + 3 * 8 + 26, ns.Bars._panel:GetHeight())
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

describe("pixel-perfect lines", function()
	before_each(function()
		Load()
		wow.startRoll(1, 500, 60000)
		wow.advance(1)
		wow.startRoll(2, 501, 60000)
	end)

	it("divides rows with the objective tracker's metal rod, cropped from its header art", function()
		local divider = BarFor(500).divider
		assert.equals("ui-questtracker-primary-objective-header", divider:GetAtlas())
		local top, bottom = divider._texCoord[3], divider._texCoord[4]
		assert.same({ 0, 1 }, { divider._texCoord[1], divider._texCoord[2] })
		assert.is_true(top >= 0 and bottom > top and bottom <= 1)
		-- shown at the art's native size: 300 wide, and as tall as the rows it crops
		assert.equals(300, divider:GetWidth())
		assert.equals((bottom - top) * 40, divider:GetHeight())
	end)

	it("centres the rod in the gap between rows and scales it smoothly", function()
		local divider = BarFor(500).divider
		local point, relativeTo, relativePoint, x, y = divider:GetPoint(1)
		assert.same({ "CENTER", BarFor(500), "BOTTOM", 0, -4 }, { point, relativeTo, relativePoint, x, y })
		assert.is_false(divider._snapToPixelGrid)
		assert.equals(0, divider._texelSnappingBias)
	end)

	it("snaps rows and the panel to whole screen pixels", function()
		assert.is_true(BarFor(500)._pixelSnapped)
		assert.is_true(BarFor(501)._pixelSnapped)
		assert.is_true(ns.Bars._panel._pixelSnapped)
	end)

	it("keeps the icon a whole unit from the row's edges", function()
		local _, _, _, _, y = BarFor(500).icon:GetPoint(1)
		assert.equals(math.floor(y), y)
		local timer = BarFor(500).timer
		for index = 1, 2 do
			local _, _, _, x, ty = timer:GetPoint(index)
			assert.equals(math.floor(x), x)
			assert.equals(math.floor(ty), ty)
		end
	end)

	it("leaves even room between the frame's edges and the row", function()
		local row = BarFor(500)
		assert.equals(300, row:GetWidth())
		assert.equals(330, ns.Bars._panel:GetWidth())
	end)
end)
