--!strict
-- Pixel analysis for HUD artwork (pure; unit-tested under Lune).
--
-- Images uploaded to Roblox often carry transparent margins of different sizes, so two
-- icons drawn in equal slots can look different in size. opaqueBounds finds the visible
-- art so the UI can crop to it (ImageRectOffset / ImageRectSize). greenArea finds the
-- empty green field of the currency bar, where the money text belongs.
--
-- Callers pass readers instead of a pixel format, so these work on EditableImage buffers in
-- the game and on synthetic images in tests.

export type Bounds = { MinX: number, MinY: number, MaxX: number, MaxY: number }
-- Fractions of the bounds' width / height (0..1), measured from each edge.
export type Insets = { Left: number, Right: number, Top: number, Bottom: number }

local AlphaBounds = {}

-- Smallest rectangle containing every pixel with alpha > threshold (0-255), or nil when the
-- image is fully transparent. `step` > 1 samples a coarse grid first, then refines the
-- edges exactly, so large images stay cheap.
function AlphaBounds.opaqueBounds(
	width: number,
	height: number,
	alphaAt: (x: number, y: number) -> number,
	threshold: number?,
	step: number?
): Bounds?
	local limit = threshold or 8
	local stride = math.max(1, step or 1)
	local minX, minY, maxX, maxY = width, height, -1, -1
	for y = 0, height - 1, stride do
		for x = 0, width - 1, stride do
			if alphaAt(x, y) > limit then
				if x < minX then
					minX = x
				end
				if x > maxX then
					maxX = x
				end
				if y < minY then
					minY = y
				end
				if y > maxY then
					maxY = y
				end
			end
		end
	end
	if maxX < 0 then
		return nil
	end
	if stride > 1 then
		-- Refine each edge within one stride of the coarse result.
		local function columnHas(x: number): boolean
			for y = 0, height - 1 do
				if alphaAt(x, y) > limit then
					return true
				end
			end
			return false
		end
		local function rowHas(y: number): boolean
			for x = 0, width - 1 do
				if alphaAt(x, y) > limit then
					return true
				end
			end
			return false
		end
		for x = math.max(0, minX - stride + 1), minX do
			if columnHas(x) then
				minX = x
				break
			end
		end
		for x = math.min(width - 1, maxX + stride - 1), maxX, -1 do
			if columnHas(x) then
				maxX = x
				break
			end
		end
		for y = math.max(0, minY - stride + 1), minY do
			if rowHas(y) then
				minY = y
				break
			end
		end
		for y = math.min(height - 1, maxY + stride - 1), maxY, -1 do
			if rowHas(y) then
				maxY = y
				break
			end
		end
	end
	return { MinX = minX, MinY = minY, MaxX = maxX, MaxY = maxY }
end

local function isGreen(r: number, g: number, b: number, a: number): boolean
	return a > 200 and g >= 90 and g > r * 1.15 and g > b * 1.15
end

-- The bar's green field inside `bounds`, as insets of the bounds. It follows the longest
-- run of green pixels along the bar's middle row, then extends up and down from the run's
-- centre. Returns nil when no run covers at least `minWidth` (default 25%) of the bar.
function AlphaBounds.greenArea(
	bounds: Bounds,
	rgbaAt: (x: number, y: number) -> (number, number, number, number),
	minWidth: number?
): Insets?
	local w = bounds.MaxX - bounds.MinX + 1
	local h = bounds.MaxY - bounds.MinY + 1
	local midY = bounds.MinY + h // 2
	local bestStart, bestLength = -1, 0
	local runStart, runLength = -1, 0
	for x = bounds.MinX, bounds.MaxX do
		local r, g, b, a = rgbaAt(x, midY)
		if isGreen(r, g, b, a) then
			if runLength == 0 then
				runStart = x
			end
			runLength += 1
			if runLength > bestLength then
				bestStart, bestLength = runStart, runLength
			end
		else
			runLength = 0
		end
	end
	if bestLength < w * (minWidth or 0.25) then
		return nil
	end
	local centerX = bestStart + bestLength // 2
	local top, bottom = midY, midY
	while top > bounds.MinY do
		local r, g, b, a = rgbaAt(centerX, top - 1)
		if not isGreen(r, g, b, a) then
			break
		end
		top -= 1
	end
	while bottom < bounds.MaxY do
		local r, g, b, a = rgbaAt(centerX, bottom + 1)
		if not isGreen(r, g, b, a) then
			break
		end
		bottom += 1
	end
	return {
		Left = (bestStart - bounds.MinX) / w,
		Right = (bounds.MaxX - (bestStart + bestLength - 1)) / w,
		Top = (top - bounds.MinY) / h,
		Bottom = (bounds.MaxY - bottom) / h,
	}
end

return AlphaBounds
