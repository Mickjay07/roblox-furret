--!strict
-- Premium Shop (Robux only). Top to bottom:
--   1. Featured pack: the pack the Robux pack products grant (Config.Monetization
--      .PremiumPackId) - pack art, a horizontally scrolling row of its cards, the chase card
--      highlighted on the right and the 1 / 3 / 10 pack purchase buttons. A LIMITED TIME
--      badge appears only when a configured limited bundle is on sale.
--   2. Passes: VIP, 2x AFK Time Cash, Open 3 / Open 6 at Once, Open All.
--   3. Limited-time offers (Config.Monetization.LimitedBundles), visually separate.
--   4. Robux packs: three aligned cards for 1, 3 and 10 packs.
--   5. While the Promo Ferret Pack isn't on sale yet: a "coming soon" row of its card art.
--
-- Card states come from Logic/ShopView. Prices and sale state come only from the server
-- (ReplicatedStorage.ProductInfo). Buttons ask the server to prompt the purchase
-- (PromptGamePass / PromptProduct); success is never shown by the client: pass ownership
-- appears once the server confirmed it with Roblox, and packs are granted (and announced)
-- only after the server processed the receipt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local CardArt = require(Shared.Logic.CardArt)
local CardRegistry = require(Shared.Logic.CardRegistry)
local Entitlements = require(Shared.Logic.Entitlements)
local Products = require(Shared.Logic.Products)
local ShopView = require(Shared.Logic.ShopView)
local UiLayout = require(Shared.Logic.UiLayout)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent.UI
local CardTile = require(UI.CardTile)
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Windows = require(UI.Windows)
local Coalesce = require(script.Parent.Parent.Lib.Coalesce)
local PackOpening = require(script.Parent.Parent.Lib.PackOpening)
local Request = require(script.Parent.Parent.Lib.Request)
local DataController = require(script.Parent.DataController)

local PremiumShopController = {}

local WINDOW = Vector2.new(1100, 700)
-- Content is WINDOW.X - 32 wide. The list's scroll bar sits in its own inset column
-- (SCROLL_BAR) and the cards keep LIST_PAD from both edges, so the bar never touches them.
local CONTENT_W = WINDOW.X - 32
local SCROLL_BAR = 8
local LIST_PAD = 6
local INNER_W = CONTENT_W - SCROLL_BAR - 2 * LIST_PAD
local GRID_GAP = 12
local COLUMN_W = math.floor((INNER_W - 2 * GRID_GAP) / 3)
local PACK_CARD_H = 300
-- Smallest on-screen text (px) and card width (px) before the grid drops a column.
local MIN_SCREEN_TEXT = 13
local MIN_CARD_PX = 260
local FEATURED_H = 318
local PREVIEW_W, PREVIEW_H = 112, 168
local LIMITED_COLOR = Color3.fromRGB(214, 64, 84)

local list: ScrollingFrame
local limitedChip: Frame
-- Set in Start: re-renders once per frame.
local requestRender: () -> () = function() end
-- Text size of the last render, to re-render only when the window scale changes it.
local renderedBody = 0
local lastColumns = 0

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function localPlayer(): Player
	return Players.LocalPlayer
end

local function passCheck(): ShopView.PassCheck
	return {
		Checked = localPlayer():GetAttribute("GamePassesChecked") == true,
		Verified = localPlayer():GetAttribute("GamePassesVerified") == true,
	}
end

local function info(key: string): ShopView.Info
	local available, price = PackOpening.productState(key)
	return { Available = available, Price = price }
end

local function restricted(): boolean
	return localPlayer():GetAttribute("PaidRandomItemsRestricted") ~= false
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Text and card metrics for the current window scale. Text never drops below
-- MIN_SCREEN_TEXT on-screen pixels: when the window is scaled down, text sizes grow in
-- layout units and the grid uses fewer columns (UiLayout.gridColumns) instead.
type Metrics = {
	scale: number,
	columns: number,
	cardW: number,
	body: number,
	title: number,
	small: number,
	pad: number,
	icon: number,
	action: number,
	passH: number,
}

local function metrics(): Metrics
	local width = list.AbsoluteSize.X
	local scale = if width > 0 then math.max(0.25, width / CONTENT_W) else 1
	local body = math.max(16, math.ceil(MIN_SCREEN_TEXT / scale))
	local title = body + 6
	local small = math.max(14, body - 2)
	local pad = 14
	local icon = math.max(72, math.floor(body * 4.2))
	local action = math.max(40, math.floor(body * 2.4))
	local columns = UiLayout.gridColumns(INNER_W * scale, MIN_CARD_PX, GRID_GAP * scale, 3)
	local cardW = math.floor((INNER_W - (columns - 1) * GRID_GAP) / columns)
	-- Title, two lines of description and the status line, next to the icon.
	local textH = math.ceil(title * 1.25) + 4 + math.ceil(body * 1.3) * 2 + 4 + math.ceil(small * 1.4)
	local passH = pad + math.max(icon, textH) + 10 + action + pad
	return {
		scale = scale,
		columns = columns,
		cardW = cardW,
		body = body,
		title = title,
		small = small,
		pad = pad,
		icon = icon,
		action = action,
		passH = passH,
	}
end

-- Fixed-size text (not TextScaled), so descriptions stay readable at every column count.
local function text(props: {
	Text: string,
	Size: UDim2,
	Position: UDim2,
	TextSize: number,
	Color: Color3?,
	XAlign: Enum.TextXAlignment?,
	Wrap: boolean?,
	Parent: Instance,
	AnchorPoint: Vector2?,
}): TextLabel
	local label = Components.label({
		Text = props.Text,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Color = props.Color,
		XAlign = props.XAlign or Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		Parent = props.Parent,
	})
	label.TextScaled = false
	label.TextSize = props.TextSize
	label.TextWrapped = props.Wrap == true
	label.TextTruncate = if props.Wrap then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd
	label.TextYAlignment = Enum.TextYAlignment.Top
	return label
end

-- Section header: gold accent bar, title, a muted subtitle and a thin divider.
local function header(title: string, subtitle: string, order: number, m: Metrics): Frame
	local height = math.ceil(m.title * 1.3) + 14
	local frame = Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = list,
	})
	Create("Frame", {
		Name = "Accent",
		Size = UDim2.new(0, 6, 1, -14),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = Theme.Colors.Gold,
		BorderSizePixel = 0,
		Parent = frame,
	}, { Components.corner(UDim.new(1, 0)) })
	local titleLabel = text({
		Text = title,
		Size = UDim2.new(0.5, 0, 0, math.ceil(m.title * 1.25)),
		Position = UDim2.fromOffset(16, 2),
		TextSize = m.title,
		Color = Theme.Colors.Gold,
		Parent = frame,
	})
	titleLabel.AutomaticSize = Enum.AutomaticSize.X
	titleLabel.Size = UDim2.fromOffset(0, math.ceil(m.title * 1.25))
	text({
		Text = subtitle,
		Size = UDim2.new(0.5, -16, 0, math.ceil(m.small * 1.3)),
		Position = UDim2.new(1, 0, 0, 2 + math.ceil((m.title - m.small) * 0.6)),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = m.small,
		Color = Theme.Colors.Muted,
		XAlign = Enum.TextXAlignment.Right,
		Parent = frame,
	})
	Create("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, -16, 0, 2),
		Position = UDim2.new(0, 16, 1, -4),
		BackgroundColor3 = Theme.Colors.GoldDark,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = frame,
	})
	return frame
end

-- A centred grid: an incomplete last row (e.g. 2 of 3 cards) sits in the middle instead of
-- leaving a hole on the right.
local function grid(name: string, order: number, cellW: number, cellH: number): Frame
	return Create("Frame", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = list,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellW, cellH),
			CellPadding = UDim2.fromOffset(GRID_GAP, GRID_GAP),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function art(parent: Instance, key: string?, size: UDim2, position: UDim2, anchor: Vector2?): ImageLabel?
	local image = CardArt.image(key)
	if not image then
		return nil
	end
	return Create("ImageLabel", {
		Name = "Art",
		Size = size,
		Position = position,
		AnchorPoint = anchor or Vector2.zero,
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,
		Parent = parent,
	})
end

local function wrapped(props: Components.LabelProps): TextLabel
	local label = Components.label(props)
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	return label
end

local function buyButton(parent: Instance, state: ShopView.CardState, size: UDim2, position: UDim2, onBuy: () -> ())
	return Components.button({
		Text = state.Button,
		Style = state.Style,
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = parent,
		OnClick = function()
			if state.CanBuy then
				onBuy()
			end
		end,
	})
end

-- 1. Featured pack ------------------------------------------------------------------

local function featured(data: Types.PlayerData, order: number)
	local pack = ShopView.premiumPack()
	if not pack then
		return
	end
	local limited = ShopView.activeLimited(now())
	local panel = Components.panel({
		Name = "Featured",
		Size = UDim2.new(1, 0, 0, FEATURED_H),
		LayoutOrder = order,
		Color = Theme.Colors.PanelDeep,
		Trim = Theme.Colors.Gold,
		Parent = list,
	})
	-- Themed backdrop in the pack's colour.
	Create("Frame", {
		Name = "Theme",
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundColor3 = pack.Color,
		BackgroundTransparency = 0.55,
		Active = false,
		Parent = panel,
	}, {
		Components.corner(UDim.new(0, 12)),
		Create("UIGradient", {
			Rotation = 0,
			Transparency = NumberSequence.new(0.2, 0.85),
		}),
	})
	Components.label({
		Text = `FEATURED: {string.upper(pack.DisplayName)}`,
		Size = UDim2.new(0.6, 0, 0, 34),
		Position = UDim2.fromOffset(16, 10),
		Color = Theme.Colors.Gold,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		Parent = panel,
	})
	if #limited > 0 then
		local badge = Components.chip("LIMITED TIME", LIMITED_COLOR, UDim2.fromOffset(170, 30), panel)
		badge.Position = UDim2.new(1, -16, 0, 12)
		badge.AnchorPoint = Vector2.new(1, 0)
	end

	-- Left: the pack wrapper.
	local packArt = art(panel, pack.Artwork, UDim2.fromOffset(130, 196), UDim2.fromOffset(16, 56))
	if not packArt then
		local badge = Components.badge(string.sub(pack.DisplayName, 1, 1), pack.Color, UDim2.fromOffset(130, 196))
		badge.Position = UDim2.fromOffset(16, 56)
		badge.Parent = panel
	end
	wrapped({
		Text = `{pack.CardsPerOpen} cards per pack`,
		Size = UDim2.fromOffset(130, 40),
		Position = UDim2.fromOffset(16, 258),
		Color = Theme.Colors.Muted,
		StrokeThickness = 1.5,
		Parent = panel,
	})

	-- Right: purchase options (the same Developer Products as the Robux packs section).
	local buyW = 230
	local buyColumn = Create("Frame", {
		Name = "Buy",
		Size = UDim2.new(0, buyW, 1, -60),
		Position = UDim2.new(1, -16, 0, 52),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
	})
	local packProducts = Products.list("Packs")
	for i, product in packProducts do
		local state = ShopView.productState(product, restricted(), info(product.Key), now())
		local count = ShopView.packCount(product)
		local label = `{count} PACK{if count == 1 then "" else "S"}  ·  {state.Button}`
		Components.button({
			Text = if state.CanBuy then label else `{count}x  ·  {state.Button}`,
			Style = state.Style,
			Size = UDim2.new(1, 0, 0, 52),
			LayoutOrder = i,
			Parent = buyColumn,
			OnClick = function()
				if state.CanBuy then
					Request(Remotes.Functions.PromptProduct, product.Key)
				end
			end,
		})
	end
	if packProducts[1] then
		wrapped({
			Text = `Odds: {Products.oddsText(data, packProducts[1])}`,
			Size = UDim2.new(1, 0, 0, 58),
			Color = Theme.Colors.Muted,
			StrokeThickness = 1.5,
			LayoutOrder = 10,
			Parent = buyColumn,
		})
	end

	-- Middle: the card row (scrolls sideways) and the chase card on its right.
	local cards, chase, oneIn = ShopView.preview(pack)
	local chaseW = 140
	local left = 16 + 130 + 16
	local rowW = INNER_W - left - 16 - buyW - 16 - chaseW - 12
	local row = Create("ScrollingFrame", {
		Name = "Preview",
		Size = UDim2.fromOffset(rowW, PREVIEW_H + 46),
		Position = UDim2.fromOffset(left, 62),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Gold,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		Parent = panel,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	for i, def in cards do
		local tile = CardTile.new(def, {})
		tile.Size = UDim2.fromOffset(PREVIEW_W, PREVIEW_H)
		tile.LayoutOrder = i
		tile.Parent = row
	end
	if chase then
		local chaseFrame = Create("Frame", {
			Name = "Chase",
			Size = UDim2.fromOffset(chaseW, 250),
			Position = UDim2.fromOffset(left + rowW + 12, 52),
			BackgroundColor3 = Theme.Colors.Gold,
			BackgroundTransparency = 0.65,
			Parent = panel,
		}, { Components.corner(UDim.new(0, 12)), Components.stroke(Theme.Colors.GoldLight, 2.5) })
		Components.label({
			Text = "CHASE CARD",
			Size = UDim2.new(1, -8, 0, 22),
			Position = UDim2.fromOffset(4, 4),
			Color = Theme.Colors.GoldLight,
			StrokeThickness = 2,
			Parent = chaseFrame,
		})
		local tile = CardTile.new(chase, {})
		tile.Size = UDim2.fromOffset(chaseW - 16, (chaseW - 16) * 1.5)
		tile.Position = UDim2.fromOffset(8, 28)
		tile.Parent = chaseFrame
		Components.label({
			Text = if oneIn then `1 IN {Format.commas(oneIn)} CARDS` else "",
			Size = UDim2.new(1, -8, 0, 20),
			Position = UDim2.new(0, 4, 1, -24),
			Color = Theme.Colors.Text,
			StrokeThickness = 1.5,
			Parent = chaseFrame,
		})
	end
end

-- 2. Passes -------------------------------------------------------------------------

-- Compact pill, e.g. the green OWNED badge.
local function pill(parent: Instance, label: string, color: Color3, size: UDim2, position: UDim2, textSize: number)
	local chip = Create("Frame", {
		Name = "Badge",
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = color,
		Parent = parent,
	}, { Components.corner(UDim.new(1, 0)), Components.stroke(color:Lerp(Color3.new(0, 0, 0), 0.5), 2) })
	text({
		Text = label,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		TextSize = textSize,
		XAlign = Enum.TextXAlignment.Center,
		Parent = chip,
	}).TextYAlignment =
		Enum.TextYAlignment.Center
	return chip
end

local function passCard(parent: Instance, data: Types.PlayerData, pass: Entitlements.Product, order: number, m: Metrics)
	local state = ShopView.passState(data, pass, passCheck(), info)
	local owned = state.Kind == "owned"
	local card = Components.panel({
		Name = pass.Key,
		LayoutOrder = order,
		Color = Theme.Colors.PanelInset,
		Trim = if owned then Theme.Colors.Leaf else Theme.Colors.GoldDark,
		Parent = parent,
	})
	local p = m.pad
	-- Icon area: a fixed square well, the art fitted inside it (same size for every pass).
	local well = Create("Frame", {
		Name = "IconWell",
		Size = UDim2.fromOffset(m.icon, m.icon),
		Position = UDim2.fromOffset(p, p),
		BackgroundColor3 = Theme.Colors.PanelDeep,
		Parent = card,
	}, { Components.corner(UDim.new(0, 12)), Components.stroke(Theme.Colors.GoldDark, 1.5) })
	if not art(well, pass.Icon, UDim2.new(1, -8, 1, -8), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)) then
		local badge = Components.badge(string.sub(pass.DisplayName, 1, 2), Theme.Colors.Leaf, UDim2.new(1, -12, 1, -12))
		badge.Position = UDim2.fromScale(0.5, 0.5)
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Parent = well
	end

	local textX = p + m.icon + 12
	local textW = m.cardW - textX - p
	local y = p
	local titleH = math.ceil(m.title * 1.25)
	text({
		Text = string.upper(pass.DisplayName),
		Size = UDim2.fromOffset(textW, titleH),
		Position = UDim2.fromOffset(textX, y),
		TextSize = m.title,
		Color = Theme.Colors.Gold,
		Parent = card,
	})
	y += titleH + 4
	local descH = math.ceil(m.body * 1.3) * 2
	text({
		Text = pass.Description or "",
		Size = UDim2.fromOffset(textW, descH),
		Position = UDim2.fromOffset(textX, y),
		TextSize = m.body,
		Color = Theme.Colors.Text,
		Wrap = true,
		Parent = card,
	})
	y += descH + 4
	text({
		Text = state.Status,
		Size = UDim2.fromOffset(textW, math.ceil(m.small * 1.4)),
		Position = UDim2.fromOffset(textX, y),
		TextSize = m.small,
		Color = if owned then Theme.Colors.Cash else Theme.Colors.Muted,
		Parent = card,
	})

	-- Compact action area along the bottom edge.
	local bottom = UDim2.new(1, -p, 1, -p)
	if owned then
		pill(
			card,
			"✓ OWNED",
			Theme.Buttons.Green[2],
			UDim2.fromOffset(math.floor(m.body * 7), m.action - 6),
			bottom,
			m.body
		)
	elseif state.Kind == "checking" then
		text({
			Text = "Checking ownership...",
			Size = UDim2.fromOffset(m.cardW - 2 * p, m.action),
			Position = UDim2.new(0, p, 1, -p - m.action + math.floor((m.action - m.body) / 2)),
			TextSize = m.body,
			Color = Theme.Colors.Muted,
			XAlign = Enum.TextXAlignment.Right,
			Parent = card,
		})
	elseif state.Kind == "unavailable" then
		pill(
			card,
			state.Button,
			Theme.Buttons.Gray[2],
			UDim2.fromOffset(math.floor(m.body * 8.5), m.action - 6),
			bottom,
			m.small
		)
	else
		-- buy: price button; unlock: wide button for the prerequisite; retry: re-check.
		local wide = state.Kind == "unlock"
		local width = if wide then m.cardW - 2 * p else math.max(math.floor(m.cardW * 0.46), math.floor(m.body * 7))
		local button = Components.button({
			Text = state.Button,
			Style = state.Style,
			Size = UDim2.fromOffset(width, m.action),
			Position = bottom,
			AnchorPoint = Vector2.new(1, 1),
			Parent = card,
			OnClick = function()
				if state.Kind == "retry" then
					Request(Remotes.Functions.RefreshGamePasses)
				elseif state.Target then
					-- The server re-checks prerequisites and ownership before prompting.
					Request(Remotes.Functions.PromptGamePass, state.Target)
				end
			end,
		})
		button.Name = "Action"
	end
end

-- 3. Limited-time offers ------------------------------------------------------------

local function limitedSection(data: Types.PlayerData, order: number, m: Metrics)
	local offers = ShopView.activeLimited(now())
	local head = header("LIMITED-TIME OFFERS", if #offers > 0 then "Robux only" else "", order, m)
	if #offers > 0 then
		-- Only while an offer is actually on sale.
		local badge = Components.chip("LIMITED TIME", LIMITED_COLOR, UDim2.fromOffset(150, 26), head)
		badge.Position = UDim2.new(0.5, 0, 0, 2)
	end
	if #offers == 0 then
		-- Calm, compact empty state in the shop's own colours.
		local height = math.max(72, math.ceil(m.body * 1.3) + math.ceil(m.small * 1.4) + 36)
		local panel = Components.panel({
			Name = "LimitedEmpty",
			Size = UDim2.new(1, 0, 0, height),
			LayoutOrder = order + 1,
			Color = Theme.Colors.PanelInset,
			Trim = Theme.Colors.GoldDark,
			Parent = list,
		})
		local iconSize = height - 24
		if
			not art(
				panel,
				"ui.icon.shop",
				UDim2.fromOffset(iconSize, iconSize),
				UDim2.new(0, 14, 0.5, 0),
				Vector2.new(0, 0.5)
			)
		then
			local badge = Components.badge("!", Theme.Colors.GoldDark, UDim2.fromOffset(iconSize, iconSize))
			badge.Position = UDim2.new(0, 14, 0.5, 0)
			badge.AnchorPoint = Vector2.new(0, 0.5)
			badge.Parent = panel
		end
		local x = 14 + iconSize + 14
		text({
			Text = "No limited offers right now",
			Size = UDim2.new(1, -x - 14, 0, math.ceil(m.body * 1.3)),
			Position = UDim2.new(0, x, 0.5, -math.ceil(m.body * 1.3) - 1),
			TextSize = m.body + 2,
			Color = Theme.Colors.Text,
			Parent = panel,
		})
		text({
			Text = "Check back during special events",
			Size = UDim2.new(1, -x - 14, 0, math.ceil(m.small * 1.4)),
			Position = UDim2.new(0, x, 0.5, 3),
			TextSize = m.small,
			Color = Theme.Colors.Muted,
			Parent = panel,
		})
		return
	end
	local offerH = 300
	local offerGrid = grid("LimitedOffers", order + 1, m.cardW, offerH)
	for i, product in offers do
		local state = ShopView.productState(product, restricted(), info(product.Key), now())
		local card = Components.panel({
			Name = product.Key,
			LayoutOrder = i,
			Color = Theme.Colors.PanelInset,
			Trim = Theme.Colors.Gold,
			Parent = offerGrid,
		})
		art(card, product.Icon, UDim2.fromOffset(110, 110), UDim2.new(0.5, 0, 0, 14), Vector2.new(0.5, 0))
		local tag = Components.chip("LIMITED TIME", LIMITED_COLOR, UDim2.fromOffset(130, 24), card)
		tag.Position = UDim2.fromOffset(10, 10)
		local y = 132
		text({
			Text = string.upper(product.DisplayName),
			Size = UDim2.new(1, -28, 0, math.ceil(m.title * 1.25)),
			Position = UDim2.fromOffset(14, y),
			TextSize = m.title,
			Color = Theme.Colors.Gold,
			XAlign = Enum.TextXAlignment.Center,
			Parent = card,
		})
		y += math.ceil(m.title * 1.25) + 4
		-- Reward summary from the configured grants; time left only with a real end time.
		local lines = { Products.describe(product) }
		if product.EndsAt then
			table.insert(lines, `Ends in {Format.duration(math.max(0, product.EndsAt - now()))}`)
		end
		if Products.isPaidRandom(product) then
			table.insert(lines, `Odds: {Products.oddsText(data, product)}`)
		end
		text({
			Text = table.concat(lines, "\n"),
			Size = UDim2.new(1, -28, 1, -y - m.action - 24),
			Position = UDim2.fromOffset(14, y),
			TextSize = m.small,
			Color = Theme.Colors.Text,
			XAlign = Enum.TextXAlignment.Center,
			Wrap = true,
			Parent = card,
		})
		buyButton(card, state, UDim2.new(1, -28, 0, m.action), UDim2.new(0.5, 0, 1, -14), function()
			Request(Remotes.Functions.PromptProduct, product.Key)
		end)
	end
end

-- 4. Robux packs --------------------------------------------------------------------

local function packCard(parent: Instance, product: Products.Product, order: number)
	local pack = ShopView.premiumPack()
	local state = ShopView.productState(product, restricted(), info(product.Key), now())
	local count = ShopView.packCount(product)
	local card = Components.panel({ Name = product.Key, LayoutOrder = order, Parent = parent })
	local packArtKey = if pack then pack.Artwork else nil
	if not art(card, packArtKey, UDim2.fromOffset(96, 144), UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0)) then
		local badge = Components.badge(tostring(count), Theme.Colors.Leaf, UDim2.fromOffset(96, 96))
		badge.Position = UDim2.new(0.5, 0, 0, 24)
		badge.AnchorPoint = Vector2.new(0.5, 0)
		badge.Parent = card
	end
	if count > 1 then
		local chip = Components.chip(`x{count}`, Theme.Colors.BrownDark, UDim2.fromOffset(64, 30), card)
		chip.Position = UDim2.new(0.5, 52, 0, 20)
	end
	Components.label({
		Text = `{count} PACK{if count == 1 then "" else "S"}`,
		Size = UDim2.new(1, -24, 0, 32),
		Position = UDim2.fromOffset(12, 160),
		Color = Theme.Colors.Gold,
		StrokeThickness = 3,
		Parent = card,
	})
	wrapped({
		Text = if pack
			then `{count}x {pack.DisplayName} ({pack.CardsPerOpen} cards each), straight to your bag`
			else (product.Description or ""),
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(12, 194),
		Color = Theme.Colors.Text,
		StrokeThickness = 1.5,
		Parent = card,
	})
	buyButton(card, state, UDim2.new(1, -24, 0, 54), UDim2.new(0.5, 0, 1, -12), function()
		Request(Remotes.Functions.PromptProduct, product.Key)
	end)
end

-- 5. Promo Ferrets teaser -----------------------------------------------------------

local function promoTeaser(order: number)
	local promo = Config.Packs.ById.promo_ferrets
	if not promo or Config.Monetization.PremiumPackId == promo.Id then
		return
	end
	local panel = Components.panel({
		Name = "PromoTeaser",
		Size = UDim2.new(1, 0, 0, 236),
		LayoutOrder = order,
		Color = Theme.Colors.PanelDeep,
		Trim = promo.Color,
		Parent = list,
	})
	art(panel, promo.Artwork, UDim2.fromOffset(120, 180), UDim2.fromOffset(16, 40))
	Components.label({
		Text = "COMING SOON: PROMO FERRETS #100-#110",
		Size = UDim2.new(1, -32, 0, 28),
		Position = UDim2.fromOffset(16, 8),
		Color = Theme.Colors.Gold,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		Parent = panel,
	})
	local row = Create("ScrollingFrame", {
		Name = "Cards",
		Size = UDim2.new(1, -168, 0, 186),
		Position = UDim2.fromOffset(152, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Gold,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		Parent = panel,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	-- Art and number only: names, rarities and incomes are placeholders until confirmed.
	for _, def in CardRegistry.inCollection("Promo") do
		local holder = Create("Frame", {
			Name = def.Id,
			Size = UDim2.fromOffset(110, 180),
			BackgroundTransparency = 1,
			LayoutOrder = def.CollectionNumber,
			Parent = row,
		})
		art(holder, def.Artwork, UDim2.fromOffset(110, 160), UDim2.fromOffset(0, 0))
		Components.label({
			Text = `#{def.CollectionNumber}`,
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 162),
			Color = Theme.Colors.Muted,
			StrokeThickness = 1.5,
			Parent = holder,
		})
	end
end

local function render()
	if not Windows.isOpen("Shop") then
		return
	end
	clear(list)
	local data = DataController:Get()
	if not data then
		Components.emptyState(list, "LOADING THE SHOP...", "One moment")
		return
	end
	local limited = ShopView.activeLimited(now())
	limitedChip.Visible = #limited > 0
	if #limited > 0 and limited[1].EndsAt then
		Components.setChipText(
			limitedChip,
			`LIMITED OFFER - ENDS IN {Format.duration(math.max(0, (limited[1].EndsAt :: number) - now()))}`
		)
	end

	local m = metrics()
	renderedBody = m.body
	lastColumns = m.columns
	featured(data, 1)
	header("PASSES & UPGRADES", "Permanent - bought once, yours forever", 10, m)
	local passes = grid("Passes", 11, m.cardW, m.passH)
	for i, pass in Entitlements.passes() do
		passCard(passes, data, pass, i, m)
	end
	limitedSection(data, 20, m)
	header("ROBUX PACKS", "Straight to your bag", 30, m)
	local packs = grid("RobuxPacks", 31, COLUMN_W, PACK_CARD_H)
	for i, product in Products.list("Packs") do
		packCard(packs, product, i)
	end
	promoTeaser(40)
end

function PremiumShopController:Start()
	Windows.register("Shop", {
		Title = "Exclusive Shop",
		Icon = "ui.icon.shop",
		Size = WINDOW,
		Build = function(content: Frame)
			-- Limited-time indicator next to the ribbon (only while an offer is live).
			limitedChip = Components.chip("", LIMITED_COLOR, UDim2.fromOffset(330, 30), content)
			limitedChip.Position = UDim2.fromScale(1, 0)
			limitedChip.AnchorPoint = Vector2.new(1, 0)
			limitedChip.Visible = false
			list = Create("ScrollingFrame", {
				Name = "List",
				Size = UDim2.new(1, 0, 1, -38),
				Position = UDim2.fromOffset(0, 38),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = SCROLL_BAR,
				ScrollBarImageColor3 = Theme.Colors.Gold,
				-- The bar gets its own column, so it never overlaps card borders or text.
				VerticalScrollBarInset = Enum.ScrollBarInset.Always,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = content,
			}, {
				Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
				Create("UIPadding", {
					PaddingLeft = UDim.new(0, LIST_PAD),
					PaddingRight = UDim.new(0, LIST_PAD),
					PaddingTop = UDim.new(0, 4),
					PaddingBottom = UDim.new(0, 14),
				}),
			})
			-- Window scale changes (resize, rotate) change text sizes and the column count.
			list:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				local m = metrics()
				if m.body ~= renderedBody or m.columns ~= lastColumns then
					requestRender()
				end
			end)
			Components.label({
				Text = "Robux purchases are confirmed by Roblox before anything is unlocked.",
				Size = UDim2.new(1, -350, 0, 24),
				Position = UDim2.fromOffset(4, 4),
				Color = Theme.Colors.Muted,
				XAlign = Enum.TextXAlignment.Left,
				StrokeThickness = 1.5,
				Parent = content,
			})
			return render
		end,
	})
	local scheduleRender = Coalesce(render)

	DataController.Changed:Connect(function(changed)
		if changed == "Purchases" or changed == "Upgrades" or changed == "Progression" or changed == "*" then
			scheduleRender()
		end
	end)
	for _, attribute in { "GamePassesChecked", "GamePassesVerified", "PaidRandomItemsRestricted" } do
		localPlayer():GetAttributeChangedSignal(attribute):Connect(scheduleRender)
	end
	PackOpening.onProductInfo(scheduleRender)
	requestRender = scheduleRender
end

return PremiumShopController
