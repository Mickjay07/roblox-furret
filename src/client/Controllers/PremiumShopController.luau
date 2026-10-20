--!strict
-- Premium Shop (Robux): permanent game passes, Robux pack bundles and limited-time bundles.
--
-- Prices and sale state come only from the server (ReplicatedStorage.ProductInfo, read with
-- GetProductInfo). Buttons ask the server to prompt the purchase (PromptGamePass /
-- PromptProduct); the client never shows success on its own: game pass ownership appears
-- once the server has confirmed it with UserOwnsGamePassAsync, and products are granted -
-- and announced - only after the server processed the receipt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local CardArt = require(Shared.Logic.CardArt)
local Entitlements = require(Shared.Logic.Entitlements)
local Products = require(Shared.Logic.Products)

local UI = script.Parent.Parent.UI
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Windows = require(UI.Windows)
local Coalesce = require(script.Parent.Parent.Lib.Coalesce)
local PackOpening = require(script.Parent.Parent.Lib.PackOpening)
local Request = require(script.Parent.Parent.Lib.Request)
local DataController = require(script.Parent.DataController)

local PremiumShopController = {}

local CARD_W, CARD_H = 300, 200

local list: ScrollingFrame

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function section(title: string, order: number): Frame
	Components.sectionTitle(title, UDim2.new(1, -12, 0, 30), list, order)
	return Create("Frame", {
		Name = title,
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order + 1,
		Parent = list,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CARD_W, CARD_H),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

type CardSpec = {
	Name: string,
	Description: string,
	Icon: string?,
	Order: number,
	Button: string,
	Style: string,
	OnClick: (() -> ())?,
}

local function card(parent: Instance, spec: CardSpec)
	local panel = Components.panel({ Name = spec.Name, LayoutOrder = spec.Order, Parent = parent })
	local image = CardArt.image(spec.Icon)
	if image then
		Create("ImageLabel", {
			Name = "Icon",
			Size = UDim2.fromOffset(84, 84),
			Position = UDim2.fromOffset(12, 12),
			BackgroundTransparency = 1,
			Image = image,
			ScaleType = Enum.ScaleType.Fit,
			Parent = panel,
		})
	else
		local badge = Components.badge(string.sub(spec.Name, 1, 2), Theme.Colors.Leaf, UDim2.fromOffset(84, 84))
		badge.Position = UDim2.fromOffset(12, 12)
		badge.Parent = panel
	end
	Components.label({
		Text = string.upper(spec.Name),
		Size = UDim2.fromOffset(CARD_W - 120, 28),
		Position = UDim2.fromOffset(106, 12),
		Color = Theme.Colors.Gold,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		Parent = panel,
	})
	local description = Components.label({
		Text = spec.Description,
		Size = UDim2.fromOffset(CARD_W - 120, 86),
		Position = UDim2.fromOffset(106, 44),
		Color = Theme.Colors.Text,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		Parent = panel,
	})
	description.TextWrapped = true
	description.TextYAlignment = Enum.TextYAlignment.Top
	Components.button({
		Text = spec.Button,
		Style = spec.Style,
		Size = UDim2.new(1, -24, 0, 50),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = panel,
		OnClick = spec.OnClick,
	})
end

-- Button state for one game pass.
local function passButton(data: Types.PlayerData, pass: Entitlements.Product): (string, string, (() -> ())?)
	if pass.GamePassId <= 0 then
		return "COMING SOON", "Gray", nil
	end
	local required = if pass.Requires then Entitlements.product(pass.Requires) else nil
	if Entitlements.owns(data, pass.Key) then
		if pass.Requires and not Entitlements.owns(data, pass.Requires) then
			return `OWNED - NEEDS {string.upper(if required then required.DisplayName else pass.Requires)}`, "Gray", nil
		end
		return "OWNED", "Gold", nil
	end
	if Players.LocalPlayer:GetAttribute("GamePassesChecked") ~= true then
		-- Ownership not confirmed by Roblox yet: never offer a pass the player may own.
		return "CHECKING...", "Gray", nil
	end
	if pass.Requires and not Entitlements.owns(data, pass.Requires) then
		return `NEEDS {string.upper(if required then required.DisplayName else pass.Requires)}`, "Gray", nil
	end
	local available, price = PackOpening.productState(pass.Key)
	if not available then
		return "UNAVAILABLE", "Gray", nil
	end
	return if price then `BUY  R$ {price}` else "BUY",
		"Purple",
		function()
			Request(Remotes.Functions.PromptGamePass, pass.Key)
		end
end

local function productButton(product: Products.Product): (string, string, (() -> ())?)
	if Products.isPaidRandom(product) and Players.LocalPlayer:GetAttribute("PaidRandomItemsRestricted") ~= false then
		-- Random cards for Robux are not sold where Roblox restricts paid random items.
		return "NOT AVAILABLE HERE", "Gray", nil
	end
	local available, price = PackOpening.productState(product.Key)
	if not available or not Products.isOnSale(product, workspace:GetServerTimeNow()) then
		return "UNAVAILABLE", "Gray", nil
	end
	return if price then `BUY  R$ {price}` else "BUY",
		"Purple",
		function()
			Request(Remotes.Functions.PromptProduct, product.Key)
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
	local passes = section("PERMANENT PASSES", 1)
	for i, pass in Entitlements.passes() do
		local text, style, onClick = passButton(data, pass)
		card(passes, {
			Name = pass.DisplayName,
			Description = pass.Description or "",
			Icon = pass.Icon,
			Order = i,
			Button = text,
			Style = style,
			OnClick = onClick,
		})
	end

	local packs = section("ROBUX PACKS  -  STRAIGHT TO YOUR BAG", 10)
	for i, product in Products.list("Packs") do
		local text, style, onClick = productButton(product)
		card(packs, {
			Name = product.DisplayName,
			-- Paid random items show their odds before purchase.
			Description = `{product.Description or ""}\nOdds: {Products.oddsText(data, product)}`,
			Icon = product.Icon,
			Order = i,
			Button = text,
			Style = style,
			OnClick = onClick,
		})
	end

	local now = workspace:GetServerTimeNow()
	local limited = {}
	for _, product in Products.list("Limited") do
		if Products.isOnSale(product, now) then
			table.insert(limited, product)
		end
	end
	local limitedGrid = section("LIMITED-TIME BUNDLES", 20)
	if #limited == 0 then
		local layout = limitedGrid:FindFirstChildOfClass("UIGridLayout")
		if layout then
			layout:Destroy()
		end
		Components.emptyState(limitedGrid, "NO LIMITED OFFERS RIGHT NOW", "Check back soon!")
	end
	for i, product in limited do
		local text, style, onClick = productButton(product)
		local odds = if Products.isPaidRandom(product) then `\nOdds: {Products.oddsText(data, product)}` else ""
		card(limitedGrid, {
			Name = product.DisplayName,
			Description = (product.Description or "") .. odds,
			Icon = product.Icon,
			Order = i,
			Button = text,
			Style = style,
			OnClick = onClick,
		})
	end
end

function PremiumShopController:Start()
	Windows.register("Shop", {
		Title = "Shop",
		Icon = "ui.icon.shop",
		Size = Vector2.new(1000, 640),
		Build = function(content: Frame)
			list = Create("ScrollingFrame", {
				Name = "List",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 8,
				ScrollBarImageColor3 = Theme.Colors.Gold,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = content,
			}, {
				Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
				Create(
					"UIPadding",
					{ PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 12) }
				),
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
	Players.LocalPlayer:GetAttributeChangedSignal("GamePassesChecked"):Connect(scheduleRender)
	Players.LocalPlayer:GetAttributeChangedSignal("PaidRandomItemsRestricted"):Connect(scheduleRender)
	PackOpening.onProductInfo(scheduleRender)
end

return PremiumShopController
