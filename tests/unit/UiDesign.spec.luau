-- GUI redesign helpers: artwork measurement (transparent margins, currency bar green field),
-- window fit-to-screen scaling, upgrade wording and insufficient-funds labels.
local roblox = require("@lune/roblox")
local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local AlphaBounds = Loader.require("src/shared/Logic/AlphaBounds")
local UiLayout = Loader.require("src/shared/Logic/UiLayout")

-- Synthetic RGBA image: `paint(x, y)` returns r, g, b, a for each pixel.
local function image(width: number, height: number, paint: (number, number) -> (number, number, number, number))
	local pixels = {}
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local r, g, b, a = paint(x, y)
			pixels[y * width + x] = { r, g, b, a }
		end
	end
	local function rgba(x: number, y: number)
		local p = pixels[y * width + x]
		return p[1], p[2], p[3], p[4]
	end
	local function alpha(x: number, y: number)
		return pixels[y * width + x][4]
	end
	return rgba, alpha
end

describe("AlphaBounds.opaqueBounds: icons with transparent margins", function()
	it("finds the visible art inside uneven transparent margins", function()
		-- 100x100 icon whose art occupies x 30..79, y 20..59 (big transparent margins).
		local _, alpha = image(100, 100, function(x, y)
			if x >= 30 and x <= 79 and y >= 20 and y <= 59 then
				return 200, 120, 60, 255
			end
			return 0, 0, 0, 0
		end)
		local bounds = AlphaBounds.opaqueBounds(100, 100, alpha, 8, 1)
		expect(bounds.MinX).toBe(30)
		expect(bounds.MaxX).toBe(79)
		expect(bounds.MinY).toBe(20)
		expect(bounds.MaxY).toBe(59)
	end)

	it("gives the exact same edges when sampling coarsely (large images)", function()
		local _, alpha = image(97, 61, function(x, y)
			if x >= 13 and x <= 70 and y >= 7 and y <= 52 then
				return 0, 0, 0, 255
			end
			return 0, 0, 0, 0
		end)
		local exact = AlphaBounds.opaqueBounds(97, 61, alpha, 8, 1)
		for _, step in { 2, 3, 4 } do
			local coarse = AlphaBounds.opaqueBounds(97, 61, alpha, 8, step)
			expect(coarse.MinX).toBe(exact.MinX)
			expect(coarse.MaxX).toBe(exact.MaxX)
			expect(coarse.MinY).toBe(exact.MinY)
			expect(coarse.MaxY).toBe(exact.MaxY)
		end
	end)

	it("ignores faint anti-aliasing below the threshold and reports fully transparent images", function()
		local _, alpha = image(20, 20, function(x, y)
			if x == 0 then
				return 0, 0, 0, 5 -- faint halo
			elseif x >= 5 and x <= 9 then
				return 0, 0, 0, 255
			end
			return 0, 0, 0, 0
		end)
		expect(AlphaBounds.opaqueBounds(20, 20, alpha, 8, 1).MinX).toBe(5)
		local _, empty = image(8, 8, function()
			return 0, 0, 0, 0
		end)
		expect(AlphaBounds.opaqueBounds(8, 8, empty, 8, 1)).toBeNil()
	end)
end)

describe("AlphaBounds.greenArea: currency bar text field", function()
	-- 200x50 bar: transparent 10 px border, a brown coin icon on the left (x 10..59) and a
	-- green field (x 70..189, y 15..34) inside a dark frame.
	local rgba, alpha = image(200, 50, function(x, y)
		if x < 10 or x > 189 or y < 5 or y > 44 then
			return 0, 0, 0, 0
		elseif x <= 59 then
			return 150, 100, 40, 255
		elseif x >= 70 and y >= 15 and y <= 34 then
			return 60, 190, 70, 255
		end
		return 30, 40, 30, 255
	end)

	it("locates the green field relative to the visible bar", function()
		local bounds = AlphaBounds.opaqueBounds(200, 50, alpha, 8, 1)
		expect(bounds.MinX).toBe(10)
		expect(bounds.MaxX).toBe(189)
		local green = AlphaBounds.greenArea(bounds, rgba)
		expect(green ~= nil).toBe(true)
		-- Visible bar: x 10..189 (180 px), y 5..44 (40 px).
		expect(green.Left).toBeNear(60 / 180, 1e-9)
		expect(green.Right).toBeNear(0, 1e-9)
		expect(green.Top).toBeNear(10 / 40, 1e-9)
		expect(green.Bottom).toBeNear(10 / 40, 1e-9)
	end)

	it("returns nil when there is no sizeable green field", function()
		local noGreen, noGreenAlpha = image(60, 20, function()
			return 200, 60, 60, 255
		end)
		local bounds = AlphaBounds.opaqueBounds(60, 20, noGreenAlpha, 8, 1)
		expect(AlphaBounds.greenArea(bounds, noGreen)).toBeNil()
	end)
end)

describe("UiLayout.fitScale: windows never leave the screen", function()
	it("uses the normal UI scale when the window fits", function()
		expect(UiLayout.fitScale(roblox.Vector2.new(1920, 1080), roblox.Vector2.new(980, 600), 1, 12)).toBe(1)
	end)

	it("shrinks a window to fit a phone in portrait and landscape", function()
		local size = roblox.Vector2.new(980, 600)
		local portrait = UiLayout.fitScale(roblox.Vector2.new(390, 844), size, 0.5, 12)
		expect(size.X * portrait <= 390 - 24 + 1e-6).toBe(true)
		local landscape = UiLayout.fitScale(roblox.Vector2.new(844, 390), size, 0.6, 12)
		expect(size.Y * landscape <= 390 - 24 + 1e-6).toBe(true)
		expect(size.X * landscape <= 844 - 24 + 1e-6).toBe(true)
	end)
end)

describe("UiLayout: upgrade and price wording", function()
	it("describes every configured upgrade's effect", function()
		for _, def in Config.Upgrades.List do
			expect(UiLayout.upgradeEffect(def.Id, 1) ~= "").toBe(true)
		end
		expect(UiLayout.upgradeEffect("IncomeBoost", 3)).toBe("+30% income")
		expect(UiLayout.upgradeEffect("DisplaySlots", 1)).toBe("+1 stand")
		expect(UiLayout.upgradeEffect("DisplaySlots", 2)).toBe("+2 stands")
		expect(UiLayout.upgradeEffect("BackpackSpace", 2)).toBe("+100 card slots")
		expect(UiLayout.upgradeEffect("nope", 1)).toBe("")
	end)

	it("shows how much money is missing, or nothing when affordable", function()
		expect(UiLayout.shortfall(500, 1500)).toBe("NEED $1,000")
		expect(UiLayout.shortfall(1500, 1500)).toBeNil()
		expect(UiLayout.shortfall(0, 2500000)).toBe("NEED $2.5M")
	end)
end)
