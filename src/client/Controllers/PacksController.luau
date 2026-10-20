--!strict
-- Pack shop window: buy packs with Cash. Bought packs go straight into the pack inventory
-- (Backpack > PACKS), where they are opened (Lib/PackOpening plays the A7 reveal). The BUY
-- button always shows the full price; the server validates the price and balance and
-- deducts once (BuyPack -> PackShop.buy). Robux packs are sold in the Premium Shop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local CardArt = require(Shared.Logic.CardArt)
local CardRegistry = require(Shared.Logic.CardRegistry)
local Economy = require(Shared.Logic.Economy)
local PackRoller = require(Shared.Logic.PackRoller)
local Progression = require(Shared.Logic.Progression)
local UiLayout = require(Shared.Logic.UiLayout)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent.UI
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Windows = require(UI.Windows)
local ArtDiagnostics = require(script.Parent.Parent.Lib.ArtDiagnostics)
local Request = require(script.Parent.Parent.Lib.Request)
local BackpackController = require(script.Parent.BackpackController)
local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local PacksController = {}

-- One shop row per pack.
local function buildRow(list: ScrollingFrame, pack: Types.PackDef)
	local amount = 1
	local row = Components.panel({
		Name = pack.Id,
		Size = UDim2.new(1, -12, 0, 176),
		LayoutOrder = pack.Order,
		Parent = list,
	})

	-- Soft gold glow behind the pack art.
	Create("Frame", {
		Name = "Glow",
		Size = UDim2.fromOffset(112, 160),
		Position = UDim2.fromOffset(12, 8),
		BackgroundColor3 = Theme.Colors.Gold,
		BackgroundTransparency = 0.82,
		Active = false,
		Parent = row,
	}, { Components.corner(UDim.new(0, 18)) })
	local packArt = CardArt.forPack(pack)
	if packArt then
		Create("ImageLabel", {
			Name = "PackArt",
			Size = UDim2.fromOffset(100, 150),
			Position = UDim2.fromOffset(18, 13),
			BackgroundTransparency = 1,
			Image = packArt,
			ScaleType = Enum.ScaleType.Fit,
			Parent = row,
		})
		ArtDiagnostics.watch("Pack Shop", pack.Artwork, packArt)
	else
		ArtDiagnostics.fallback("Pack Shop", pack.Artwork)
		local icon = Components.badge(string.sub(pack.DisplayName, 1, 1), pack.Color, UDim2.fromOffset(100, 150))
		icon.Position = UDim2.fromOffset(18, 13)
		icon.Parent = row
	end

	Components.label({
		Text = string.upper(pack.DisplayName),
		Size = UDim2.new(0, 330, 0, 34),
		Position = UDim2.fromOffset(136, 12),
		Color = Theme.Colors.Gold,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		Parent = row,
	})
	local info = Components.label({
		Text = "",
		Size = UDim2.new(0, 330, 0, 22),
		Position = UDim2.fromOffset(136, 52),
		XAlign = Enum.TextXAlignment.Left,
		Color = Theme.Colors.Muted,
		StrokeThickness = 1.5,
		Parent = row,
	})
	local chase = Components.label({
		Text = "",
		Size = UDim2.new(0, 330, 0, 22),
		Position = UDim2.fromOffset(136, 82),
		XAlign = Enum.TextXAlignment.Left,
		Color = Theme.Colors.Treats,
		StrokeThickness = 1.5,
		Parent = row,
	})

	local amountLabel = Components.label({
		Text = "x1",
		Size = UDim2.fromOffset(60, 34),
		Position = UDim2.new(1, -306, 0, 42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = row,
	})
	local refreshRow: () -> () = function() end
	local function price(): number
		return pack.Price * amount
	end
	local buy = Components.button({
		Text = "",
		Style = "Green",
		Size = UDim2.fromOffset(210, 56),
		Position = UDim2.new(1, -14, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		Parent = row,
		OnClick = function()
			local data = DataController:Get()
			if not data then
				return
			end
			local missing = Progression.describeMissing(data, pack.Unlock)
			if missing then
				NotificationController:Push(missing, "error")
				return
			end
			local need = UiLayout.shortfall(data.Currency[pack.Currency] or 0, price())
			if need then
				-- Answered locally (one toast): the server would reject it anyway.
				NotificationController:Push(`Not enough {pack.Currency}. {need}`, "error")
				return
			end
			local bought = amount
			local result = Request(Remotes.Functions.BuyPack, pack.Id, bought)
			if result.ok then
				NotificationController:Push(
					`{bought}x {pack.DisplayName} added to your bag ({result.owned} owned). Open them from Backpack > Packs!`,
					"success"
				)
			end
		end,
	})
	local hint = Components.label({
		Text = "",
		Size = UDim2.fromOffset(210, 20),
		Position = UDim2.new(1, -14, 0, 74),
		AnchorPoint = Vector2.new(1, 0),
		Color = Theme.Colors.Muted,
		StrokeThickness = 1.5,
		Parent = row,
	})
	local bag = Components.button({
		Text = "IN BAG (0)",
		Style = "Brown",
		Size = UDim2.fromOffset(210, 46),
		Position = UDim2.new(1, -14, 0, 104),
		AnchorPoint = Vector2.new(1, 0),
		Parent = row,
		OnClick = function()
			BackpackController:OpenPacks()
		end,
	})
	Components.button({
		Text = "GET PACKS WITH ROBUX",
		Style = "Purple",
		Size = UDim2.fromOffset(270, 38),
		Position = UDim2.fromOffset(136, 118),
		Parent = row,
		OnClick = function()
			Windows.open("Shop")
		end,
	})
	Components.button({
		Text = "-",
		Style = "Brown",
		Size = UDim2.fromOffset(44, 40),
		Position = UDim2.new(1, -350, 0, 42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = row,
		OnClick = function()
			amount = math.max(1, amount - 1)
			refreshRow()
		end,
	})
	Components.button({
		Text = "+",
		Style = "Brown",
		Size = UDim2.fromOffset(44, 40),
		Position = UDim2.new(1, -262, 0, 42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = row,
		OnClick = function()
			amount = math.min(Config.Game.Limits.MaxPacksPerPurchase, amount + 1)
			refreshRow()
		end,
	})

	local lock = Create("Frame", {
		Name = "Lock",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.PanelDeep,
		BackgroundTransparency = 0.18,
		ZIndex = 5,
		Visible = false,
		Active = true, -- a locked pack can't be clicked through
		Parent = row,
	}, { Components.corner(UDim.new(0, 14)) })
	local lockTitle = Components.label({
		Text = "LOCKED",
		Size = UDim2.new(0.6, 0, 0, 36),
		Position = UDim2.fromScale(0.5, 0.36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Colors.Gold,
		StrokeThickness = 3,
		Parent = lock,
	})
	lockTitle.ZIndex = 6
	local lockText = Components.label({
		Text = "",
		Size = UDim2.new(0.8, 0, 0, 26),
		Position = UDim2.fromScale(0.5, 0.6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = lock,
	})
	lockText.ZIndex = 6

	local function refresh(data: Types.PlayerData)
		local cards = {}
		for _, collectionId in pack.Collections do
			for _, def in CardRegistry.inCollection(collectionId) do
				table.insert(cards, def)
			end
		end
		local found = 0
		for _, def in cards do
			if data.Discovered[def.Id] then
				found += 1
			end
		end
		info.Text = `{pack.CardsPerOpen} CARDS PER PACK  |  {found}/{#cards} FOUND`

		local odds = PackRoller.odds(pack, {
			luck = Economy.luck(data),
			isUnlocked = function(def: Types.CardDef)
				return Progression.meets(data, def.Unlock)
			end,
		})
		local rarest, rarestP = nil :: Types.CardDef?, math.huge
		for cardId, probability in odds do
			if probability < rarestP then
				rarest, rarestP = CardRegistry.get(cardId), probability
			end
		end
		chase.Text = if rarest
			then `CHASE: {string.upper(rarest.Name)}  1 IN {Format.commas(PackRoller.oneIn(rarestP))}`
			else ""

		local missing = Progression.describeMissing(data, pack.Unlock)
		local owned = data.Packs[pack.Id] or 0
		-- Owned packs stay openable (from the bag) even if the pack can no longer be bought.
		lock.Visible = missing ~= nil and owned == 0
		Components.setButtonText(bag, `IN BAG ({owned})`)
		Components.setButtonStyle(bag, if owned > 0 then "Gold" else "Brown")
		-- The button always shows the full price; what is missing is a separate hint.
		amountLabel.Text = `x{amount}`
		local need = UiLayout.shortfall(data.Currency[pack.Currency] or 0, price())
		Components.setButtonText(buy, "BUY " .. UiLayout.priceText(price()))
		Components.setButtonStyle(buy, if need == nil and missing == nil then "Green" else "Gray")
		hint.Text = need or ""
		lockText.Text = if missing then string.upper(missing) else ""
	end
	refreshRow = function()
		local data = DataController:Get()
		if data then
			refresh(data)
		end
	end
	for _, key in { "Progression", "Packs", "Currency", "Discovered", "Upgrades" } do
		DataController:Observe(key, refresh)
	end
end

function PacksController:Start()
	Windows.register("Packs", {
		Title = "Pack Shop",
		Icon = "pack.pack1.front",
		Size = Vector2.new(920, 640),
		Build = function(content: Frame)
			Components.sectionTitle("CHOOSE A PACK", UDim2.new(1, -470, 0, 30), content)
			local balance = Components.chip("$0", Theme.Colors.BrownDark, UDim2.fromOffset(250, 34), content)
			balance.Position = UDim2.fromScale(1, 0)
			balance.AnchorPoint = Vector2.new(1, 0)
			local packsChip = Components.chip("", Theme.Colors.Brown, UDim2.fromOffset(200, 34), content)
			packsChip.Position = UDim2.new(1, -262, 0, 0)
			packsChip.AnchorPoint = Vector2.new(1, 0)
			DataController:Observe("Currency", function(data: Types.PlayerData)
				Components.setChipText(balance, `BALANCE ${Format.short(data.Currency.Cash or 0, 1e9)}`)
			end)
			DataController:Observe("Packs", function(data: Types.PlayerData)
				local total = 0
				for _, count in data.Packs do
					total += count
				end
				Components.setChipText(packsChip, `MY PACKS: {total}`)
			end)
			local list = Create("ScrollingFrame", {
				Name = "List",
				Size = UDim2.new(1, 0, 1, -46),
				Position = UDim2.fromOffset(0, 46),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 8,
				ScrollBarImageColor3 = Theme.Colors.Gold,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = content,
			}, {
				Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }),
				Create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) }),
			})
			for _, pack in Config.Packs.List do
				buildRow(list, pack)
			end
			return nil
		end,
	})
end

return PacksController
