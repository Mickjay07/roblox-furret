--!strict
-- Card visual used by the reveal screen, backpack, stands and binder. When a card has no
-- artwork asset yet, the art area shows a placeholder: rarity gradient + species initials.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local CardArt = require(Shared.Logic.CardArt)
local Format = require(Shared.Util.Format)

local ArtDiagnostics = require(script.Parent.Parent.Lib.ArtDiagnostics)
local Components = require(script.Parent.Components)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

export type Options = {
	Variant: string?,
	Income: number?,
	IsNew: boolean?,
	OneIn: number?,
	OnStand: boolean?,
	Favorite: boolean?,
	Count: number?,
	Selected: boolean?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
}

local CardTile = {}

local function initials(species: string): string
	local out = ""
	for word in string.gmatch(species, "[%a]+") do
		out ..= string.sub(word, 1, 1)
	end
	return string.upper(out)
end

local function tag(parent: Instance, text: string, color: Color3, position: UDim2, anchor: Vector2)
	local frame = Create("Frame", {
		Name = "Tag",
		Size = UDim2.new(0.5, 0, 0.11, 0),
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = color,
		ZIndex = 3,
		Parent = parent,
	}, { Components.corner(UDim.new(0, 6)), Components.stroke(Theme.Colors.Border, 2) })
	local label = Components.label({
		Text = text,
		Size = UDim2.fromScale(0.9, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		StrokeThickness = 1.5,
		Parent = frame,
	})
	label.ZIndex = 4
end

-- Tile for cards whose uploaded artwork is a complete printed card (Config.Assets.FullCardArt):
-- the image is shown as-is (aspect preserved) with status tags on top. The printed income is
-- the base (Normal) income, so a "+N%" tag above it shows a variant or grade bonus.
local function fullArtTile(def: Types.CardDef, image: string, opts: Options, variant: Types.VariantDef): TextButton
	local tile: TextButton = Create("TextButton", {
		Name = def.Id,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(150, 225),
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
	}, {
		Create("UIAspectRatioConstraint", { AspectRatio = CardArt.aspect(def.Artwork) }),
		Create("ImageLabel", {
			Name = "Art",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = image,
			ScaleType = Enum.ScaleType.Fit,
		}),
	})
	if opts.Selected then
		Create("Frame", {
			Name = "Selection",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = tile,
		}, {
			Components.corner(UDim.new(0, 12)),
			Create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 5 }),
		})
	end
	if variant.Id ~= "Normal" then
		tag(tile, variant.DisplayName, variant.Color, UDim2.new(0.5, 0, 0.14, 0), Vector2.new(0.5, 0))
	end
	if opts.IsNew then
		tag(tile, "NEW!", Color3.fromRGB(255, 70, 90), UDim2.new(0.03, 0, 0.14, 0), Vector2.zero)
	end
	if opts.Favorite then
		tag(tile, "FAV", Color3.fromRGB(255, 200, 40), UDim2.new(0.97, 0, 0.14, 0), Vector2.new(1, 0))
	end
	if opts.OnStand then
		tag(tile, "ON STAND", Color3.fromRGB(64, 156, 255), UDim2.new(0.5, 0, 0.42, 0), Vector2.new(0.5, 0))
	end
	if opts.Count and opts.Count > 1 then
		tag(tile, `x{opts.Count}`, Theme.Colors.Panel, UDim2.new(0.97, 0, 0.3, 0), Vector2.new(1, 0))
	end
	local bonus = if opts.Income then Format.bonusPercent(opts.Income, def.BaseIncome) else nil
	if bonus then
		tag(
			tile,
			bonus,
			Theme.Colors.Cash:Lerp(Color3.new(0, 0, 0), 0.35),
			UDim2.new(0.5, 0, 0.7, 0),
			Vector2.new(0.5, 0)
		)
	end
	if opts.OnClick then
		local onClick = opts.OnClick
		tile.Activated:Connect(function()
			onClick()
		end)
	end
	return tile
end

-- Builds a card tile. Size is set by the caller's layout (aspect ratio 5:7 is enforced, or the
-- artwork's own aspect when uploaded art is shown).
function CardTile.new(def: Types.CardDef, options: Options?): GuiButton
	local opts: Options = options or {}
	local rarity = Config.Rarities.ById[def.Rarity]
	local variant = Config.Variants.ById[opts.Variant or "Normal"] or Config.Variants.ById.Normal
	-- Tiles show the art at ~150-200 px: use the small thumbnail when it is uploaded.
	local uploaded = CardArt.thumbnail(def.Artwork)
	if uploaded then
		ArtDiagnostics.watch("CardTile", def.Artwork, uploaded)
	else
		ArtDiagnostics.fallback("CardTile", def.Artwork)
	end
	if uploaded and Config.Assets.FullCardArt then
		return fullArtTile(def, uploaded, opts, variant)
	end
	local rarityColor = if rarity then rarity.Color else Theme.Colors.Muted

	local tile: TextButton = Create("TextButton", {
		Name = def.Id,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(150, 210),
		BackgroundColor3 = rarityColor,
		LayoutOrder = opts.LayoutOrder or 0,
	}, {
		Components.corner(UDim.new(0, 12)),
		Create("UIStroke", {
			Color = if opts.Selected then Color3.new(1, 1, 1) else Theme.Colors.Border,
			Thickness = if opts.Selected then 5 else 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Create("UIAspectRatioConstraint", { AspectRatio = 5 / 7 }),
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
		}),
	})

	local art = Create("Frame", {
		Name = "Art",
		Size = UDim2.new(0.86, 0, 0.5, 0),
		Position = UDim2.new(0.07, 0, 0.06, 0),
		BackgroundColor3 = Color3.fromRGB(250, 240, 220),
		ClipsDescendants = true,
		Parent = tile,
	}, { Components.corner(UDim.new(0, 8)), Components.stroke(Theme.Colors.Border, 2) })
	if uploaded then
		Create("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = uploaded,
			ScaleType = Enum.ScaleType.Crop,
			Parent = art,
		})
	else
		Create("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new(rarityColor:Lerp(Color3.new(1, 1, 1), 0.6), rarityColor),
			Parent = art,
		})
		Components.label({
			Text = initials(def.Species),
			Size = UDim2.fromScale(0.7, 0.6),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			StrokeThickness = 3,
			Parent = art,
		})
	end

	Components.label({
		Name = "CardName",
		Text = string.upper(def.Name),
		Size = UDim2.new(0.9, 0, 0.12, 0),
		Position = UDim2.new(0.05, 0, 0.58, 0),
		StrokeThickness = 2,
		Parent = tile,
	})
	Components.label({
		Name = "Rarity",
		Text = if rarity then rarity.DisplayName else def.Rarity,
		Size = UDim2.new(0.8, 0, 0.08, 0),
		Position = UDim2.new(0.1, 0, 0.71, 0),
		Color = rarityColor:Lerp(Color3.new(1, 1, 1), 0.35),
		StrokeThickness = 2,
		Parent = tile,
	})
	Components.label({
		Name = "Income",
		Text = `+{Format.short(opts.Income or def.BaseIncome)}/S`,
		Size = UDim2.new(0.86, 0, 0.11, 0),
		Position = UDim2.new(0.07, 0, 0.81, 0),
		Color = Theme.Colors.Cash,
		StrokeThickness = 2,
		Parent = tile,
	})

	if variant.Id ~= "Normal" then
		tag(tile, variant.DisplayName, variant.Color, UDim2.new(0.97, 0, 0.03, 0), Vector2.new(1, 0))
	end
	if opts.IsNew then
		tag(tile, "NEW!", Color3.fromRGB(255, 70, 90), UDim2.new(0.03, 0, 0.03, 0), Vector2.zero)
	end
	if opts.Favorite then
		tag(tile, "FAV", Color3.fromRGB(255, 200, 40), UDim2.new(0.03, 0, 0.03, 0), Vector2.zero)
	end
	if opts.OnStand then
		tag(tile, "ON STAND", Color3.fromRGB(64, 156, 255), UDim2.new(0.5, 0, 0.42, 0), Vector2.new(0.5, 0))
	end
	if opts.Count and opts.Count > 1 then
		tag(tile, `x{opts.Count}`, Theme.Colors.Panel, UDim2.new(0.97, 0, 0.42, 0), Vector2.new(1, 0))
	end
	if opts.OnClick then
		local onClick = opts.OnClick
		tile.Activated:Connect(function()
			onClick()
		end)
	end
	return tile
end

-- A face-down tile for cards not discovered yet: the shared card back (dimmed) with the
-- card's collection number, or a drawn back when the image isn't uploaded.
function CardTile.unknown(layoutOrder: number?, number: number?): Frame
	local back = CardArt.back()
	local frame: Frame = Create("Frame", {
		Name = "Unknown",
		Size = UDim2.fromOffset(120, 180),
		BackgroundColor3 = Theme.Colors.PanelInset,
		BackgroundTransparency = if back then 1 else 0,
		LayoutOrder = layoutOrder or 0,
	}, {
		Components.corner(UDim.new(0, 12)),
		Create("UIAspectRatioConstraint", { AspectRatio = 2 / 3 }),
	})
	if back then
		Create("ImageLabel", {
			Name = "Back",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = back,
			ImageColor3 = Color3.fromRGB(110, 120, 110),
			ImageTransparency = 0.15,
			ScaleType = Enum.ScaleType.Fit,
			Parent = frame,
		})
	else
		Components.stroke(Theme.Colors.GoldDark, 3).Parent = frame
	end
	Components.label({
		Text = "?",
		Size = UDim2.fromScale(0.42, 0.3),
		Position = UDim2.fromScale(0.5, 0.46),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Colors.GoldLight,
		StrokeThickness = 3,
		Parent = frame,
	})
	if number then
		Components.label({
			Text = string.format("#%03d", number),
			Size = UDim2.fromScale(0.6, 0.12),
			Position = UDim2.fromScale(0.5, 0.86),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = Theme.Colors.Muted,
			StrokeThickness = 2,
			Parent = frame,
		})
	end
	return frame
end

return CardTile
