--!strict
-- Measures HUD artwork at runtime so it can be cropped to its visible pixels.
--
-- Uploaded images can have different transparent margins: equal ImageLabels then show the
-- art at different visual sizes, and a bar drawn with ScaleType.Fit in a box of the wrong
-- aspect is letterboxed (empty space on its left). For each image this reads the pixels
-- once through EditableImage (Logic/AlphaBounds) and returns:
--   Size   - the image's pixel size
--   Bounds - the visible (non-transparent) rectangle, for ImageRectOffset / ImageRectSize
--   Green  - for the currency bar: its empty green field, as insets of Bounds
--
-- Precedence: Config.Visuals.Hud.ImageBounds[key] (values measured once and written into
-- config) > runtime measurement > nil (callers keep their config fallback). Reading pixels
-- needs EditableImage access to the asset; when it isn't allowed the measurement is nil
-- and Studio logs why. In Studio every successful measurement is printed in config form.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AlphaBounds = require(Shared.Logic.AlphaBounds)

export type Measurement = {
	Size: Vector2,
	Bounds: AlphaBounds.Bounds,
	Green: AlphaBounds.Insets?,
}

local ImageBounds = {}

local IS_STUDIO = RunService:IsStudio()
local cache: { [string]: Measurement | false } = {}
local pending: { [string]: { (Measurement?) -> () } } = {}

local function fromConfig(key: string): Measurement?
	local hud = (Config.Visuals :: any).Hud
	local entry = if hud and hud.ImageBounds then hud.ImageBounds[key] else nil
	if type(entry) ~= "table" then
		return nil
	end
	return {
		Size = Vector2.new(entry.Width, entry.Height),
		Bounds = { MinX = entry.MinX, MinY = entry.MinY, MaxX = entry.MaxX, MaxY = entry.MaxY },
		Green = entry.Green,
	}
end

local function measureNow(key: string, contentId: string, findGreen: boolean): Measurement?
	local ok, result = pcall(function()
		return AssetService:CreateEditableImageAsync(Content.fromUri(contentId))
	end)
	if not ok then
		if IS_STUDIO then
			warn(`[Art] could not measure {key} ({result}); using Config.Visuals.Hud values`)
		end
		return nil
	end
	local editable: EditableImage = result
	local size = editable.Size
	local readOk, pixels = pcall(function()
		return editable:ReadPixelsBuffer(Vector2.zero, size)
	end)
	editable:Destroy()
	if not readOk then
		return nil
	end
	local width, height = size.X, size.Y
	local function alphaAt(x: number, y: number): number
		return buffer.readu8(pixels, (y * width + x) * 4 + 3)
	end
	local function rgbaAt(x: number, y: number): (number, number, number, number)
		local i = (y * width + x) * 4
		return buffer.readu8(pixels, i),
			buffer.readu8(pixels, i + 1),
			buffer.readu8(pixels, i + 2),
			buffer.readu8(pixels, i + 3)
	end
	local step = if width * height > 512 * 512 then 2 else 1
	local bounds = AlphaBounds.opaqueBounds(width, height, alphaAt, 16, step)
	if not bounds then
		return nil
	end
	local green = if findGreen then AlphaBounds.greenArea(bounds, rgbaAt) else nil
	if IS_STUDIO then
		local greenText = if green
			then string.format(
				", Green = { Left = %.3f, Right = %.3f, Top = %.3f, Bottom = %.3f }",
				green.Left,
				green.Right,
				green.Top,
				green.Bottom
			)
			else ""
		print(
			`[Art] measured {key}: ["{key}"] = \{ Width = {width}, Height = {height}, MinX = {bounds.MinX}, MinY = {bounds.MinY}, MaxX = {bounds.MaxX}, MaxY = {bounds.MaxY}{greenText} \}`
		)
	end
	return { Size = size, Bounds = bounds, Green = green }
end

-- Calls `callback` with the measurement (or nil) - immediately when known, otherwise once
-- it has been measured in the background. Each image is measured at most once.
function ImageBounds.get(key: string, contentId: string, findGreen: boolean, callback: (Measurement?) -> ())
	local configured = fromConfig(key)
	if configured then
		callback(configured)
		return
	end
	local cached = cache[key]
	if cached ~= nil then
		callback(if cached == false then nil else cached :: Measurement)
		return
	end
	local waiting = pending[key]
	if waiting then
		table.insert(waiting, callback)
		return
	end
	pending[key] = { callback }
	task.spawn(function()
		local measurement = measureNow(key, contentId, findGreen)
		cache[key] = measurement or false
		local callbacks: { (Measurement?) -> () } = pending[key] or {}
		pending[key] = nil
		for _, cb in callbacks do
			task.spawn(cb, measurement)
		end
	end)
end

-- Crops an image object to the measured visible rectangle (aspect stays the art's own).
function ImageBounds.crop(image: GuiObject, measurement: Measurement)
	local b = measurement.Bounds
	-- ImageLabel and ImageButton share these properties.
	local target = image :: any
	target.ImageRectOffset = Vector2.new(b.MinX, b.MinY)
	target.ImageRectSize = Vector2.new(b.MaxX - b.MinX + 1, b.MaxY - b.MinY + 1)
end

-- Width / height of the visible art.
function ImageBounds.aspect(measurement: Measurement): number
	local b = measurement.Bounds
	return (b.MaxX - b.MinX + 1) / (b.MaxY - b.MinY + 1)
end

return ImageBounds
