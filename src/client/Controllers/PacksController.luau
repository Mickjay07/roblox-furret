--!strict
-- Pack shop window. OPEN opens one pack and plays the A7 opening sequence (UI/PackReveal).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local CardArt = require(Shared.Logic.CardArt)
local CardRegistry = require(Shared.Logic.CardRegistry)
local Economy = require(Shared.Logic.Economy)
local Entitlements = require(Shared.Logic.Entitlements)
local PackRoller = require(Shared.Logic.PackRoller)
local Progression = require(Shared.Logic.Progression)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent.UI
local PackReveal = require(UI.PackReveal)
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Windows = require(UI.Windows)
local ArtDiagnostics = require(script.Parent.Parent.Lib.ArtDiagnostics)
local Request = require(script.Parent.Parent.Lib.Request)
local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local PacksController = {}

-- One pack opening at a time: set from the OPEN click until the reveal is closed.
local opening = false

-- Opens `packs` owned packs together (1, or 3 / 6 with Multi Opening). The server checks the
-- unlock and the pack count, consumes the packs and grants the cards before replying; the
-- request id makes a repeated request (double click, retry) return the same result
-- instead of opening more packs. The reveal is purely visual.
local function openPack(pack: Types.PackDef, packs: number)
	if opening or PackReveal.isOpen() then
		return
	end
	local data = DataController:Get()
	if not data or (data.Packs[pack.Id] or 0) < packs or not Entitlements.canUseMode(data, packs) then
		return
	end
	opening = true
	local requestId = HttpService:GenerateGUID(false)
	local result = Request(Remotes.Functions.OpenPack, pack.Id, requestId, packs)
	if not result.ok or type(result.cards) ~= "table" then
		opening = false
		return
	end
	PackReveal.play(pack, result.cards, result.packs, result.cardsPerPack, function()
		opening = false
	end)
end

-- Robux price published by the server after reading the game pass info (nil until then,
-- or when the pass is not for sale / could not be read).
local function productState(key: string): (boolean, number?)
	local folder = ReplicatedStorage:FindFirstChild("ProductInfo")
	if not folder then
		return false, nil
	end
	local price = folder:GetAttribute(`{key}_Price`)
	return folder:GetAttribute(`{key}_Available`) == true, if type(price) == "number" then price else nil
end

-- One shop row per pack.
local function buildRow(list: ScrollingFrame, pack: Types.PackDef)
	local amount = 1
	-- Opening size for this row: 1, 3 or 6 packs at once.
	local mode = 1
	local row = Create("Frame", {
		Name = pack.Id,
		Size = UDim2.new(1, -12, 0, 172),
		BackgroundColor3 = Theme.Colors.PanelInset,
		LayoutOrder = pack.Order,
		Parent = list,
	}, { Components.corner(UDim.new(0, 14)), Components.stroke(Theme.Colors.Border, 2) })

	local packArt = CardArt.forPack(pack)
	if packArt then
		Create("ImageLabel", {
			Name = "PackArt",
			Size = UDim2.fromOffset(70, 105),
			Position = UDim2.fromOffset(16, 9),
			BackgroundTransparency = 1,
			Image = packArt,
			ScaleType = Enum.ScaleType.Fit,
			Parent = row,
		})
		ArtDiagnostics.watch("Pack Shop", pack.Artwork, packArt)
	else
		ArtDiagnostics.fallback("Pack Shop", pack.Artwork)
		local icon = Components.badge(string.sub(pack.DisplayName, 1, 1), pack.Color, UDim2.fromOffset(84, 104))
		icon.Position = UDim2.fromOffset(10, 10)
		icon.Parent = row
	end

	Components.label({
		Text = string.upper(pack.DisplayName),
		Size = UDim2.new(0, 300, 0, 34),
		Position = UDim2.fromOffset(110, 10),
		XAlign = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local info = Components.label({
		Text = "",
		Size = UDim2.new(0, 300, 0, 22),
		Position = UDim2.fromOffset(110, 48),
		XAlign = Enum.TextXAlignment.Left,
		Color = Theme.Colors.Muted,
		StrokeThickness = 1.5,
		Parent = row,
	})
	local chase = Components.label({
		Text = "",
		Size = UDim2.new(0, 300, 0, 22),
		Position = UDim2.fromOffset(110, 76),
		XAlign = Enum.TextXAlignment.Left,
		Color = Theme.Colors.Treats,
		StrokeThickness = 1.5,
		Parent = row,
	})

	local amountLabel = Components.label({
		Text = "x1",
		Size = UDim2.fromOffset(60, 34),
		Position = UDim2.new(1, -282, 0, 82),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = row,
	})
	local buy: TextButton
	local onAmountChanged: () -> () = function() end
	local function refreshPrice()
		amountLabel.Text = `x{amount}`
		Components.setButtonText(buy, "BUY $" .. Format.short(pack.Price * amount, 1e6))
		onAmountChanged()
	end
	buy = Components.button({
		Text = "",
		Style = "Green",
		Size = UDim2.fromOffset(190, 56),
		Position = UDim2.new(1, -14, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		Parent = row,
		OnClick = function()
			local result = Request(Remotes.Functions.BuyPack, pack.Id, amount)
			if result.ok then
				NotificationController:Push(
					`Bought {amount}x {pack.DisplayName} - you have {result.owned}. Open them any time!`,
					"success"
				)
			end
		end,
	})
	local open = Components.button({
		Text = "NO PACKS",
		Style = "Gray",
		Size = UDim2.fromOffset(190, 40),
		Position = UDim2.new(1, -14, 0, 76),
		AnchorPoint = Vector2.new(1, 0),
		Parent = row,
		OnClick = function()
			openPack(pack, mode)
		end,
	})

	-- Opening mode strip: 1 pack always; 3x / 6x with the Multi Opening game passes.
	Components.label({
		Text = "OPEN:",
		Size = UDim2.fromOffset(70, 30),
		Position = UDim2.fromOffset(16, 130),
		XAlign = Enum.TextXAlignment.Left,
		Color = Theme.Colors.Muted,
		Parent = row,
	})
	local refreshModes: () -> () = function() end
	local modeButtons: { { packs: number, product: Entitlements.Product?, button: TextButton } } = {}
	local modeOptions: { { packs: number, product: Entitlements.Product? } } = { { packs = 1, product = nil } }
	for _, product in Entitlements.products() do
		table.insert(modeOptions, { packs = product.Packs, product = product })
	end
	for i, option in modeOptions do
		local button = Components.button({
			Text = "",
			Style = "Blue",
			Size = UDim2.fromOffset(196, 36),
			Position = UDim2.fromOffset(90 + (i - 1) * 206, 128),
			Parent = row,
			OnClick = function()
				local data = DataController:Get()
				if not data then
					return
				end
				if Entitlements.canUseMode(data, option.packs) then
					mode = option.packs
					refreshModes()
					return
				end
				local product = option.product
				if product and Entitlements.canPurchase(data, product.Key) then
					-- The server re-checks the prerequisite and prompts the game pass. Ownership
					-- is recorded only after the server confirms it with Roblox.
					Request(Remotes.Functions.PromptMultiOpen, product.Key)
				end
			end,
		})
		table.insert(modeButtons, { packs = option.packs, product = option.product, button = button })
	end
	Components.button({
		Text = "-",
		Style = "Blue",
		Size = UDim2.fromOffset(44, 40),
		Position = UDim2.new(1, -326, 0, 82),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = row,
		OnClick = function()
			amount = math.max(1, amount - 1)
			refreshPrice()
		end,
	})
	Components.button({
		Text = "+",
		Style = "Blue",
		Size = UDim2.fromOffset(44, 40),
		Position = UDim2.new(1, -238, 0, 82),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = row,
		OnClick = function()
			amount = math.min(Config.Game.Limits.MaxPacksPerPurchase, amount + 1)
			refreshPrice()
		end,
	})
	refreshPrice()

	local lock = Create("Frame", {
		Name = "Lock",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		ZIndex = 5,
		Visible = false,
		Parent = row,
	}, { Components.corner(UDim.new(0, 14)) })
	local lockText = Components.label({
		Text = "LOCKED",
		Size = UDim2.new(0.8, 0, 0, 36),
		Position = UDim2.fromScale(0.5, 0.5),
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
		-- Owned packs stay openable even if the pack can no longer be bought.
		lock.Visible = missing ~= nil and owned == 0
		if not Entitlements.canUseMode(data, mode) then
			mode = 1
		end
		Components.setButtonText(
			open,
			if owned >= mode
				then (if mode > 1 then `OPEN {mode}x ({owned})` else `OPEN ({owned})`)
				elseif owned > 0 then `NEED {mode} PACKS`
				else "NO PACKS"
		)
		Components.setButtonStyle(open, if owned >= mode then "Orange" else "Gray")
		for _, entry in modeButtons do
			local label, style
			if Entitlements.canUseMode(data, entry.packs) then
				label = if entry.packs == 1 then "1 PACK" else `{entry.packs} PACKS`
				style = if entry.packs == mode then "Orange" else "Blue"
			elseif entry.product then
				local product = entry.product :: Entitlements.Product
				local available, price = productState(product.Key)
				local canBuy, _ = Entitlements.canPurchase(data, product.Key)
				local verified = Players.LocalPlayer:GetAttribute("GamePassesVerified") == true
				if product.Requires and not Entitlements.owns(data, product.Requires) then
					local required = Entitlements.product(product.Requires)
					label, style = `{entry.packs}x - NEEDS {if required then `{required.Packs}x` else "UNLOCK"}`, "Gray"
				elseif Entitlements.owns(data, product.Key) then
					label, style = `{entry.packs}x - LOCKED`, "Gray"
				elseif not verified then
					-- Ownership not confirmed by Roblox yet: never show "unlock" as if not owned.
					label, style = `{entry.packs}x - CHECKING...`, "Gray"
				elseif canBuy and available then
					label, style =
						if price then `UNLOCK {entry.packs}x  R${price}` else `UNLOCK {entry.packs}x`, "Purple"
				else
					label, style = `{entry.packs}x - UNAVAILABLE`, "Gray"
				end
			end
			Components.setButtonText(entry.button, label or "")
			Components.setButtonStyle(entry.button, style or "Gray")
		end
		local affordable = (data.Currency[pack.Currency] or 0) >= pack.Price * amount
		Components.setButtonStyle(buy, if affordable and missing == nil then "Green" else "Gray")
		lockText.Text = if missing then string.upper(missing) else ""
	end
	DataController:Observe("Progression", refresh)
	DataController:Observe("Packs", refresh)
	DataController:Observe("Purchases", refresh)
	refreshModes = function()
		local data = DataController:Get()
		if data then
			refresh(data)
		end
	end
	task.spawn(function()
		-- Prices and availability appear once the server has verified the products.
		Players.LocalPlayer:GetAttributeChangedSignal("GamePassesVerified"):Connect(refreshModes)
		local folder = ReplicatedStorage:WaitForChild("ProductInfo", 30)
		if folder then
			folder.AttributeChanged:Connect(refreshModes)
			refreshModes()
		end
	end)
	onAmountChanged = function()
		local data = DataController:Get()
		if data then
			refresh(data)
		end
	end
	DataController:Observe("Currency", refresh)
	DataController:Observe("Discovered", refresh)
	DataController:Observe("Upgrades", refresh)
end

function PacksController:Start()
	Windows.register("Packs", {
		Title = "Packs",
		Accent = "Green",
		Size = Vector2.new(820, 540),
		Build = function(content: Frame)
			local list = Create("ScrollingFrame", {
				Name = "List",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 8,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = content,
			}, {
				Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
			})
			for _, pack in Config.Packs.List do
				buildRow(list, pack)
			end
			return nil
		end,
	})
end

return PacksController
