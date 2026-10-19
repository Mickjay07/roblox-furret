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

-- Chunky rounded button: coloured fill, darker border, a soft top shine and press bounce.
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
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 196, 196)),
		}),
		scale,
	})
	-- Glossy highlight on the upper half (decorative; never takes input).
	Create("Frame", {
		Name = "Shine",
		Size = UDim2.new(1, -10, 0.42, 0),
		Position = UDim2.fromOffset(5, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Active = false,
		Parent = button,
	}, { Components.corner(UDim.new(0, 10)) })
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

export type PanelProps = {
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Trim: Color3?,
	LayoutOrder: number?,
	Parent: Instance?,
}

-- Inset surface used inside windows: deep green with a thin gold trim and a soft gradient.
function Components.panel(props: PanelProps): Frame
	return Create("Frame", {
		Name = props.Name or "Panel",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.Color or Theme.Colors.PanelInset,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	}, {
		Components.corner(UDim.new(0, 14)),
		Create("UIStroke", {
			Color = props.Trim or Theme.Colors.GoldDark,
			Thickness = 2,
			Transparency = 0.25,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 210, 200)),
		}),
	})
end

-- Small rounded tag, e.g. "UNCOMMON", "x3", "OWNED".
function Components.chip(text: string, color: Color3, size: UDim2?, parent: Instance?): Frame
	local chip = Create("Frame", {
		Name = "Chip",
		Size = size or UDim2.fromOffset(110, 26),
		BackgroundColor3 = color,
		Parent = parent,
	}, {
		Components.corner(UDim.new(1, 0)),
		Components.stroke(color:Lerp(Color3.new(0, 0, 0), 0.55), 2),
	})
	Components.label({
		Name = "Text",
		Text = text,
		Size = UDim2.new(1, -14, 0.78, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		StrokeThickness = 2,
		Parent = chip,
	})
	return chip
end

function Components.setChipText(chip: Frame, text: string)
	local label = chip:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

-- A paw print (one pad, four toes) drawn from circles; decoration only.
function Components.paw(
	parent: Instance,
	position: UDim2,
	size: number,
	color: Color3,
	transparency: number,
	rotation: number?
): Frame
	local paw = Create("Frame", {
		Name = "Paw",
		Size = UDim2.fromOffset(size, size),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = rotation or 0,
		BackgroundTransparency = 1,
		Active = false,
		Parent = parent,
	})
	local function dot(x: number, y: number, w: number, h: number)
		Create("Frame", {
			Size = UDim2.fromScale(w, h),
			Position = UDim2.fromScale(x, y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			Parent = paw,
		}, { Components.corner(UDim.new(1, 0)) })
	end
	dot(0.5, 0.68, 0.5, 0.42)
	dot(0.18, 0.4, 0.2, 0.26)
	dot(0.38, 0.2, 0.2, 0.26)
	dot(0.62, 0.2, 0.2, 0.26)
	dot(0.82, 0.4, 0.2, 0.26)
	return paw
end

-- A single leaf (rotated rounded oval with a lighter tip); decoration only.
function Components.leaf(parent: Instance, position: UDim2, size: number, rotation: number, transparency: number): Frame
	return Create("Frame", {
		Name = "Leaf",
		Size = UDim2.fromOffset(size, size * 0.5),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = rotation,
		BackgroundColor3 = Theme.Colors.Leaf,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		Active = false,
		Parent = parent,
	}, {
		Components.corner(UDim.new(1, 0)),
		Create("UIGradient", {
			Color = ColorSequence.new(
				Theme.Colors.Leaf:Lerp(Color3.new(0, 0, 0), 0.25),
				Theme.Colors.Leaf:Lerp(Color3.new(1, 1, 1), 0.3)
			),
		}),
	})
end

-- Large section heading in gold, left-aligned.
function Components.sectionTitle(text: string, size: UDim2?, parent: Instance?, layoutOrder: number?): TextLabel
	return Components.label({
		Name = "Section",
		Text = text,
		Size = size or UDim2.new(1, 0, 0, 28),
		Color = Theme.Colors.Gold,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		LayoutOrder = layoutOrder,
		Parent = parent,
	})
end

-- Centred empty / loading state with an optional action button.
function Components.emptyState(
	parent: Instance,
	title: string,
	body: string?,
	action: string?,
	onAction: (() -> ())?
): Frame
	local holder = Create("Frame", {
		Name = "EmptyState",
		Size = UDim2.new(1, 0, 0, 220),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Components.paw(holder, UDim2.new(0.5, 0, 0, 40), 64, Theme.Colors.Gold, 0.35, -12)
	Components.label({
		Text = title,
		Size = UDim2.new(0.9, 0, 0, 38),
		Position = UDim2.new(0.5, 0, 0, 82),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Theme.Colors.Gold,
		StrokeThickness = 3,
		Parent = holder,
	})
	if body then
		Components.label({
			Text = body,
			Size = UDim2.new(0.9, 0, 0, 24),
			Position = UDim2.new(0.5, 0, 0, 124),
			AnchorPoint = Vector2.new(0.5, 0),
			Color = Theme.Colors.Muted,
			StrokeThickness = 1.5,
			Parent = holder,
		})
	end
	if action and onAction then
		Components.button({
			Text = action,
			Style = "Gold",
			Size = UDim2.fromOffset(220, 50),
			Position = UDim2.new(0.5, 0, 0, 160),
			AnchorPoint = Vector2.new(0.5, 0),
			Parent = holder,
			OnClick = onAction,
		})
	end
	return holder
end

-- Rounded search field. `onChanged` runs with the current text on every edit.
function Components.searchBox(placeholder: string, size: UDim2, parent: Instance, onChanged: (string) -> ()): TextBox
	local box: TextBox = Create("TextBox", {
		Name = "Search",
		Size = size,
		BackgroundColor3 = Theme.Colors.PanelDeep,
		Text = "",
		PlaceholderText = placeholder,
		PlaceholderColor3 = Theme.Colors.Muted,
		TextColor3 = Theme.Colors.Text,
		Font = Theme.Font,
		TextScaled = true,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	}, {
		Components.corner(UDim.new(1, 0)),
		Components.stroke(Theme.Colors.GoldDark, 2),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
	})
	box:GetPropertyChangedSignal("Text"):Connect(function()
		onChanged(box.Text)
	end)
	return box
end

-- Pill on/off switch. Returns the button and a setter for its displayed state.
function Components.toggle(size: UDim2, parent: Instance, onClick: () -> ()): (TextButton, (boolean) -> ())
	local button: TextButton = Create("TextButton", {
		Name = "Toggle",
		Text = "",
		AutoButtonColor = false,
		Size = size,
		BackgroundColor3 = Theme.Buttons.Gray[1],
		Parent = parent,
	}, { Components.corner(UDim.new(1, 0)), Components.stroke(Theme.Colors.Border, 3) })
	local knob = Create("Frame", {
		Name = "Knob",
		Size = UDim2.new(0, size.Y.Offset - 10, 1, -10),
		Position = UDim2.new(0, 5, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Colors.Text,
		Parent = button,
	}, { Components.corner(UDim.new(1, 0)), Components.stroke(Theme.Colors.Border, 2) })
	local label = Components.label({
		Text = "OFF",
		Size = UDim2.new(0.5, 0, 0.6, 0),
		Position = UDim2.fromScale(0.72, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		StrokeThickness = 2,
		Parent = button,
	})
	button.Activated:Connect(onClick)
	local function set(on: boolean)
		button.BackgroundColor3 = if on then Theme.Buttons.Green[1] else Theme.Buttons.Gray[1]
		label.Text = if on then "ON" else "OFF"
		label.Position = UDim2.fromScale(if on then 0.3 else 0.72, 0.5)
		Components.tween(knob, 0.15, {
			Position = if on then UDim2.new(1, -5, 0.5, 0) else UDim2.new(0, 5, 0.5, 0),
			AnchorPoint = if on then Vector2.new(1, 0.5) else Vector2.new(0, 0.5),
		})
	end
	return button, set
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
		Components.corner(UDim.new(0, 12)),
		Components.stroke(Theme.Colors.GoldDark, 3),
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
		BackgroundColor3 = Theme.Colors.PanelDeep,
	}, { Components.corner(UDim.new(1, 0)), Components.stroke(Theme.Colors.GoldDark, 2), fill })
	return frame,
		function(alpha: number)
			Components.tween(fill, 0.2, { Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1) })
		end
end

return Components
