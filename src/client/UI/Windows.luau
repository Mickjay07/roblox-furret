--!strict
-- Modal window manager. Features register a window by name; HUD navigation opens them.
-- Only one window is open at a time.

local Players = game:GetService("Players")

local Components = require(script.Parent.Components)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

export type WindowSpec = {
	Title: string,
	Accent: string?,
	-- Width / height in offset pixels before UI scaling.
	Size: Vector2?,
	-- Builds the content once; may return an onOpen callback run each time it opens.
	Build: (content: Frame) -> (() -> ())?,
}

type Window = { frame: Frame, scale: UIScale, onOpen: (() -> ())? }

local Windows = {}

local gui: ScreenGui = Create("ScreenGui", {
	Name = "Windows",
	ResetOnSpawn = false,
	DisplayOrder = 10,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
})
Windows.gui = gui

local specs: { [string]: WindowSpec } = {}
local built: { [string]: Window } = {}
local current: string? = nil

function Windows.register(name: string, spec: WindowSpec)
	specs[name] = spec
end

function Windows.has(name: string): boolean
	return specs[name] ~= nil
end

local function build(name: string): Window
	local spec = specs[name]
	local size = spec.Size or Vector2.new(720, 460)
	local accent = Theme.Buttons[spec.Accent or "Green"] or Theme.Buttons.Green
	local scale = Create("UIScale", { Scale = 1 })
	local frame: Frame = Create("Frame", {
		Name = name,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		Parent = gui,
	}, {
		Components.corner(UDim.new(0, 16)),
		Components.stroke(Theme.Colors.Border, 4),
		scale,
	})
	local header = Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.Colors.PanelHeader,
		Parent = frame,
	}, { Components.corner(UDim.new(0, 16)) })
	Components.label({
		Text = string.upper(spec.Title),
		Size = UDim2.new(1, -120, 0, 40),
		Position = UDim2.new(0, 24, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = accent[1],
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		Parent = header,
	})
	Components.button({
		Name = "Close",
		Text = "X",
		Style = "Red",
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.new(1, 14, 0, -14),
		AnchorPoint = Vector2.new(1, 0),
		Parent = frame,
		OnClick = function()
			Windows.close()
		end,
	})
	local content: Frame = Create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -32, 1, -88),
		Position = UDim2.fromOffset(16, 76),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	local onOpen = spec.Build(content)
	local window = { frame = frame, scale = scale, onOpen = onOpen }
	built[name] = window
	return window
end

function Windows.open(name: string)
	if not specs[name] then
		return
	end
	if current and current ~= name then
		Windows.close()
	end
	local window = built[name] or build(name)
	current = name
	window.frame.Visible = true
	local target = Components.screenScale()
	window.scale.Scale = target * 0.85
	Components.tween(window.scale, 0.15, { Scale = target }, Enum.EasingStyle.Back)
	if window.onOpen then
		window.onOpen()
	end
end

function Windows.close()
	if current then
		local window = built[current]
		if window then
			window.frame.Visible = false
		end
		current = nil
	end
end

function Windows.toggle(name: string)
	if current == name then
		Windows.close()
	else
		Windows.open(name)
	end
end

function Windows.isOpen(name: string): boolean
	return current == name
end

return Windows
