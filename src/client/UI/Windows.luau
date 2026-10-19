--!strict
-- Modal window manager. Features register a window by name; HUD navigation opens them.
-- Only one window is open at a time.
--
-- Every window shares the Ferret Frenzy frame: forest-green body with a gold rim, a gold
-- ribbon header carrying the window's icon (Config.Assets key) and title, a round close
-- button, faint paw-print decoration, and a dimmed backdrop (click it to close). Windows are
-- scaled to fit the screen (Logic/UiLayout.fitScale), so they never extend past its edges.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardArt = require(Shared.Logic.CardArt)
local UiLayout = require(Shared.Logic.UiLayout)

local Components = require(script.Parent.Components)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

export type WindowSpec = {
	Title: string,
	Accent: string?,
	-- Config.Assets key of the header icon (e.g. "ui.icon.backpack").
	Icon: string?,
	-- Width / height in offset pixels before UI scaling.
	Size: Vector2?,
	-- Builds the content once; may return an onOpen callback run each time it opens.
	Build: (content: Frame) -> (() -> ())?,
	-- Called whenever the window closes.
	OnClose: (() -> ())?,
}

type Window = { frame: Frame, scale: UIScale, size: Vector2, onOpen: (() -> ())? }

local Windows = {}

local MARGIN = 12

local gui: ScreenGui = Create("ScreenGui", {
	Name = "Windows",
	ResetOnSpawn = false,
	DisplayOrder = 10,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
})
Windows.gui = gui

-- Dimmed backdrop behind the open window; clicking it closes the window.
local backdrop: TextButton = Create("TextButton", {
	Name = "Backdrop",
	Text = "",
	AutoButtonColor = false,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(4, 14, 8),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 0,
	Parent = gui,
})

local specs: { [string]: WindowSpec } = {}
local built: { [string]: Window } = {}
local current: string? = nil

function Windows.register(name: string, spec: WindowSpec)
	specs[name] = spec
end

function Windows.has(name: string): boolean
	return specs[name] ~= nil
end

local function targetScale(size: Vector2): number
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 760)
	return UiLayout.fitScale(viewport, size, Components.screenScale(), MARGIN)
end

local function header(frame: Frame, spec: WindowSpec)
	local ribbon = Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, -96, 0, 58),
		Position = UDim2.fromOffset(16, 12),
		BackgroundColor3 = Theme.Colors.Gold,
		ZIndex = 3,
		Parent = frame,
	}, {
		Components.corner(UDim.new(0, 16)),
		Components.stroke(Theme.Colors.BrownDark, 3),
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.Colors.GoldLight),
				ColorSequenceKeypoint.new(0.55, Theme.Colors.Gold),
				ColorSequenceKeypoint.new(1, Theme.Colors.GoldDark),
			}),
		}),
	})
	-- Leaves tucked behind the ribbon's right end.
	Components.leaf(ribbon, UDim2.new(1, -18, 0, 4), 40, -30, 0.1).ZIndex = 2
	Components.leaf(ribbon, UDim2.new(1, -4, 1, -8), 34, 25, 0.2).ZIndex = 2

	local icon = if spec.Icon then CardArt.image(spec.Icon) else nil
	local textLeft = 22
	if icon then
		Create("ImageLabel", {
			Name = "Icon",
			Size = UDim2.fromOffset(78, 78),
			Position = UDim2.new(0, -14, 0.5, -2),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = icon,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 5,
			Parent = ribbon,
		})
		textLeft = 74
	end
	Create("TextLabel", {
		Name = "Title",
		Text = string.upper(spec.Title),
		Size = UDim2.new(1, -textLeft - 16, 0, 38),
		Position = UDim2.new(0, textLeft, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
		Parent = ribbon,
	}, {
		Create("UIStroke", {
			Color = Theme.Colors.BrownDark,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}),
	})
end

local function build(name: string): Window
	local spec = specs[name]
	local size = spec.Size or Vector2.new(720, 460)
	local scale = Create("UIScale", { Scale = 1 })
	local frame: Frame = Create("Frame", {
		Name = name,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		Active = true, -- clicks inside the window never reach the backdrop
		ZIndex = 1,
		Parent = gui,
	}, {
		Components.corner(UDim.new(0, 22)),
		Create("UIStroke", { Color = Theme.Colors.Gold, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 165, 150)),
		}),
		scale,
	})
	-- Inner brown rim line, like a card frame.
	Create("Frame", {
		Name = "Rim",
		Size = UDim2.new(1, -12, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Active = false,
		Parent = frame,
	}, {
		Components.corner(UDim.new(0, 18)),
		Create("UIStroke", { Color = Theme.Colors.BrownDark, Thickness = 2, Transparency = 0.35 }),
	})
	-- Faint paw prints in two corners (decoration only, behind the content).
	Components.paw(frame, UDim2.new(1, -46, 1, -42), 54, Theme.Colors.Gold, 0.86, 18)
	Components.paw(frame, UDim2.new(1, -96, 1, -78), 34, Theme.Colors.Gold, 0.9, -8)
	Components.paw(frame, UDim2.new(0, 34, 1, -36), 30, Theme.Colors.Gold, 0.9, -24)

	header(frame, spec)
	local close = Components.button({
		Name = "Close",
		Text = "X",
		Style = "Red",
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.new(1, -16, 0, 15),
		AnchorPoint = Vector2.new(1, 0),
		Parent = frame,
		OnClick = function()
			Windows.close()
		end,
	})
	close.ZIndex = 6
	local corner = close:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(1, 0)
	end
	local content: Frame = Create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -32, 1, -100),
		Position = UDim2.fromOffset(16, 84),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = frame,
	})
	local onOpen = spec.Build(content)
	local window = { frame = frame, scale = scale, size = size, onOpen = onOpen }
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
	backdrop.Visible = true
	backdrop.BackgroundTransparency = 1
	Components.tween(backdrop, 0.15, { BackgroundTransparency = 0.45 })
	local target = targetScale(window.size)
	window.scale.Scale = target * 0.85
	Components.tween(window.scale, 0.18, { Scale = target }, Enum.EasingStyle.Back)
	if window.onOpen then
		window.onOpen()
	end
end

function Windows.close()
	if current then
		local name = current
		local window = built[name]
		if window then
			window.frame.Visible = false
		end
		current = nil
		backdrop.Visible = false
		local spec = specs[name]
		if spec and spec.OnClose then
			spec.OnClose()
		end
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

backdrop.Activated:Connect(function()
	Windows.close()
end)

-- Keep the open window fitted when the screen size or orientation changes.
local function watchViewport()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local name = current
			local window = if name then built[name] else nil
			if window then
				window.scale.Scale = targetScale(window.size)
			end
		end)
	end
end
watchViewport()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport)

return Windows
