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
-- Content is WINDOW.X - 32 wide; the list keeps 20 px for padding and the scroll bar.
local INNER_W = WINDOW.X - 32 - 20
local GRID_GAP = 12
local COLUMN_W = math.floor((INNER_W - 2 * GRID_GAP) / 3)
local PASS_H = 176
local PACK_CARD_H = 300
local FEATURED_H = 318
local PREVIEW_W, PREVIEW_H = 112, 168
local LIMITED_COLOR = Color3.fromRGB(214, 64, 84)

local list: ScrollingFrame
local limitedChip: Frame

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

local function sectionTitle(text: string, order: number)
	Components.sectionTitle(text, UDim2.new(1, -8, 0, 32), list, order)
end

local function grid(name: string, order: number, cellHeight: number): Frame
	return Create("Frame", {
		Name = name,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = list,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(COLUMN_W, cellHeight),
			CellPadding = UDim2.fromOffset(GRID_GAP, GRID_GAP),
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
		Size = UDim2.new(1, -8, 0, FEATURED_H),
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
	local rowW = INNER_W - 8 - left - 16 - buyW - 16 - chaseW - 12
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

local function passCard(parent: Instance, data: Types.PlayerData, pass: Entitlements.Product, order: number)
	local state = ShopView.passState(data, pass, passCheck(), info(pass.Key))
	local card = Components.panel({
		Name = pass.Key,
		LayoutOrder = order,
		Trim = if state.Button == "OWNED" then Theme.Colors.Leaf else nil,
		Parent = parent,
	})
	if not art(card, pass.Icon, UDim2.fromOffset(84, 84), UDim2.fromOffset(12, 12)) then
		local badge = Components.badge(string.sub(pass.DisplayName, 1, 2), Theme.Colors.Leaf, UDim2.fromOffset(84, 84))
		badge.Position = UDim2.fromOffset(12, 12)
		badge.Parent = card
	end
	Components.label({
		Text = string.upper(pass.DisplayName),
		Size = UDim2.new(1, -120, 0, 28),
		Position = UDim2.fromOffset(106, 10),
		Color = Theme.Colors.Gold,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		Parent = card,
	})
	wrapped({
		Text = pass.Description or "",
		Size = UDim2.new(1, -120, 0, 40),
		Position = UDim2.fromOffset(106, 40),
		Color = Theme.Colors.Text,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		Parent = card,
	})
	Components.label({
		Text = state.Status,
		Size = UDim2.new(1, -120, 0, 18),
		Position = UDim2.fromOffset(106, 82),
		Color = if state.Button == "OWNED" then Theme.Colors.Cash else Theme.Colors.Muted,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		Parent = card,
	})
	buyButton(card, state, UDim2.new(1, -24, 0, 50), UDim2.new(0.5, 0, 1, -12), function()
		Request(Remotes.Functions.PromptGamePass, pass.Key)
	end)
end

-- 3. Limited-time offers ------------------------------------------------------------

local function limitedSection(data: Types.PlayerData, order: number)
	local offers = ShopView.activeLimited(now())
	local panel = Components.panel({
		Name = "Limited",
		Size = UDim2.new(1, -8, 0, if #offers == 0 then 96 else PACK_CARD_H + 60),
		LayoutOrder = order,
		Color = Color3.fromRGB(70, 18, 30),
		Trim = LIMITED_COLOR,
		Parent = list,
	})
	Components.label({
		Text = "LIMITED-TIME OFFERS",
		Size = UDim2.new(0.6, 0, 0, 30),
		Position = UDim2.fromOffset(16, 10),
		Color = Theme.Colors.GoldLight,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		Parent = panel,
	})
	if #offers == 0 then
		Components.label({
			Text = "No limited offers right now - check back during events!",
			Size = UDim2.new(1, -32, 0, 24),
			Position = UDim2.fromOffset(16, 52),
			Color = Theme.Colors.Muted,
			XAlign = Enum.TextXAlignment.Left,
			StrokeThickness = 1.5,
			Parent = panel,
		})
		return
	end
	local row = Create("Frame", {
		Name = "Offers",
		Size = UDim2.new(1, -24, 0, PACK_CARD_H),
		Position = UDim2.fromOffset(12, 50),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GRID_GAP),
		}),
	})
	for i, product in offers do
		local state = ShopView.productState(product, restricted(), info(product.Key), now())
		local card = Components.panel({
			Name = product.Key,
			Size = UDim2.fromOffset(COLUMN_W - 8, PACK_CARD_H),
			LayoutOrder = i,
			Color = Theme.Colors.PanelDeep,
			Trim = LIMITED_COLOR,
			Parent = row,
		})
		art(card, product.Icon, UDim2.fromOffset(110, 110), UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0))
		Components.label({
			Text = string.upper(product.DisplayName),
			Size = UDim2.new(1, -24, 0, 28),
			Position = UDim2.fromOffset(12, 128),
			Color = Theme.Colors.Gold,
			StrokeThickness = 2.5,
			Parent = card,
		})
		local ends = if product.EndsAt then `Ends in {Format.duration(math.max(0, product.EndsAt - now()))}` else ""
		local odds = if Products.isPaidRandom(product) then `\nOdds: {Products.oddsText(data, product)}` else ""
		wrapped({
			Text = `{product.Description or ""}\n{ends}{odds}`,
			Size = UDim2.new(1, -24, 0, 70),
			Position = UDim2.fromOffset(12, 160),
			Color = Theme.Colors.Text,
			StrokeThickness = 1.5,
			Parent = card,
		})
		buyButton(card, state, UDim2.new(1, -24, 0, 52), UDim2.new(0.5, 0, 1, -12), function()
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
		Size = UDim2.new(1, -8, 0, 236),
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

	featured(data, 1)
	sectionTitle("PASSES & UPGRADES", 10)
	local passes = grid("Passes", 11, PASS_H)
	for i, pass in Entitlements.passes() do
		passCard(passes, data, pass, i)
	end
	limitedSection(data, 20)
	sectionTitle("ROBUX PACKS  -  STRAIGHT TO YOUR BAG", 30)
	local packs = grid("RobuxPacks", 31, PACK_CARD_H)
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
				ScrollBarThickness = 8,
				ScrollBarImageColor3 = Theme.Colors.Gold,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = content,
			}, {
				Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }),
				Create("UIPadding", {
					PaddingLeft = UDim.new(0, 6),
					PaddingTop = UDim.new(0, 4),
					PaddingBottom = UDim.new(0, 16),
				}),
			})
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
end

return PremiumShopController
