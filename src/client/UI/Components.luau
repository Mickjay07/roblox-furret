--!strict
-- Reusable UI building blocks in the game's style.

local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local Components = {}

-- UI layouts are authored for a 1280x760 viewport and scaled to fit the real screen.
function Components.screenScale(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end
	local size = camera.ViewportSize
	return math.clamp(math.min(size.X / 1280, size.Y / 760), 0.5, 1.25)
end

-- Adds a UIScale to `target` that follows the viewport size.
function Components.autoScale(target: GuiObject): UIScale
	local scale = Instance.new("UIScale")
	scale.Scale = Components.screenScale()
	scale.Parent = target
	local function hook()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				scale.Scale = Components.screenScale()
			end)
		end
	end
	hook()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook)
	return scale
end

-- Set from the player's ReducedMotion setting; skips decorative tweens.
Components.reducedMotion = false

function Components.tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	if Components.reducedMotion then
		for key, value in goal do
			(instance :: any)[key] = value
		end
		return
	end
	TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), goal):Play()
end

function Components.corner(radius: UDim?): Instance
	return Create("UICorner", { CornerRadius = radius or Theme.Corner })
end

function Components.stroke(color: Color3?, thickness: number?): Instance
	return Create("UIStroke", {
		Color = color or Theme.Colors.Border,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

export type LabelProps = {
	Text: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	XAlign: Enum.TextXAlignment?,
	StrokeThickness: number?,
	Name: string?,
	LayoutOrder: number?,
	Parent: Instance?,
}

-- Outlined, auto-scaling text in the game font.
function Components.label(props: LabelProps): TextLabel
	return Create("TextLabel", {
		Name = props.Name or "Label",
		Text = props.Text,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = props.Color or Theme.Colors.Text,
		TextScaled = true,
		TextXAlignment = props.XAlign or Enum.TextXAlignment.Center,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	}, {
		Create("UIStroke", {
			Color = Theme.Colors.TextStroke,
			Thickness = props.StrokeThickness or 2.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}),
	})
end

export type ButtonProps = {
	Text: string,
	Style: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Name: string?,
	LayoutOrder: number?,
	Parent: Instance?,
	OnClick: (() -> ())?,
}

-- Pill button with a darker border, light gradient and press bounce.
function Components.button(props: ButtonProps): TextButton
	local palette = Theme.Buttons[props.Style or "Green"] or Theme.Buttons.Green
	local scale = Create("UIScale", { Scale = 1 })
	local button = Create("TextButton", {
		Name = props.Name or props.Text,
		Text = "",
		AutoButtonColor = false,
		Size = props.Size or UDim2.fromOffset(180, 56),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = palette[1],
		LayoutOrder = props.LayoutOrder or 0,
	}, {
		Components.corner(UDim.new(0, 14)),
		Components.stroke(palette[2], 3),
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
		}),
		scale,
	})
	Components.label({
		Name = "Text",
		Text = props.Text,
		Size = UDim2.new(1, -16, 0.7, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = button,
	})
	button.MouseEnter:Connect(function()
		Components.tween(scale, 0.08, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		Components.tween(scale, 0.08, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		Components.tween(scale, 0.05, { Scale = 0.94 })
	end)
	button.MouseButton1Up:Connect(function()
		Components.tween(scale, 0.08, { Scale = 1.05 })
	end)
	if props.OnClick then
		local onClick = props.OnClick
		button.Activated:Connect(function()
			onClick()
		end)
	end
	if props.Parent then
		button.Parent = props.Parent
	end
	return button
end

export type IconButtonProps = {
	Image: string,
	Caption: string?,
	Size: number,
	Name: string?,
	LayoutOrder: number?,
	Parent: Instance?,
	OnClick: (() -> ())?,
}

-- Image button for custom HUD artwork: the ImageButton itself takes the click; the image
-- keeps its own aspect ratio (ScaleType.Fit) inside a square slot; the optional caption is
-- a plain TextLabel, which never takes input.
function Components.iconButton(props: IconButtonProps): ImageButton
	local scale = Create("UIScale", { Scale = 1 })
	-- Square slot for the art; the caption (if any) hangs just below it.
	local button: ImageButton = Create("ImageButton", {
		Name = props.Name or props.Caption or "Icon",
		Image = props.Image,
		ScaleType = Enum.ScaleType.Fit,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(props.Size, props.Size),
		LayoutOrder = props.LayoutOrder or 0,
	}, { scale })
	if props.Caption then
		local captionHeight = math.floor(props.Size * 0.24)
		local caption = Components.label({
			Name = "Caption",
			Text = props.Caption,
			Size = UDim2.new(1.3, 0, 0, captionHeight),
			Position = UDim2.new(0.5, 0, 1, -math.floor(captionHeight * 0.35)),
			AnchorPoint = Vector2.new(0.5, 0),
			StrokeThickness = 2,
			Parent = button,
		})
		caption.Active = false
	end
	button.MouseEnter:Connect(function()
		Components.tween(scale, 0.08, { Scale = 1.06 })
	end)
	button.MouseLeave:Connect(function()
		Components.tween(scale, 0.08, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		Components.tween(scale, 0.05, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		Components.tween(scale, 0.08, { Scale = 1.06 })
	end)
	if props.OnClick then
		local onClick = props.OnClick
		button.Activated:Connect(function()
			onClick()
		end)
	end
	if props.Parent then
		button.Parent = props.Parent
	end
	return button
end

function Components.setButtonText(button: TextButton, text: string)
	local label = button:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

function Components.setButtonStyle(button: TextButton, style: string)
	local palette = Theme.Buttons[style] or Theme.Buttons.Green
	button.BackgroundColor3 = palette[1]
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = palette[2]
	end
end

-- Rounded square "icon" with a glyph, used where art assets do not exist yet.
function Components.badge(text: string, color: Color3, size: UDim2?): Frame
	local frame = Create("Frame", {
		Name = "Badge",
		Size = size or UDim2.fromOffset(44, 44),
		BackgroundColor3 = color,
	}, {
		Components.corner(UDim.new(0, 10)),
		Components.stroke(Theme.Colors.Border, 3),
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
		}),
	})
	Components.label({
		Text = text,
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = frame,
	})
	return frame
end

-- Horizontal progress bar; returns the frame and a setter taking 0..1.
function Components.progressBar(color: Color3, size: UDim2?): (Frame, (number) -> ())
	local fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
	}, { Components.corner(UDim.new(1, 0)) })
	local frame = Create("Frame", {
		Name = "ProgressBar",
		Size = size or UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = Theme.Colors.PanelInset,
	}, { Components.corner(UDim.new(1, 0)), Components.stroke(Theme.Colors.Border, 2), fill })
	return frame,
		function(alpha: number)
			Components.tween(fill, 0.2, { Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1) })
		end
end

return Components
