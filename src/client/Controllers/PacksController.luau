--!strict
-- Pack shop window. OPEN opens one pack and plays the A7 opening sequence (UI/PackReveal).

local HttpService = game:GetService("HttpService")
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

-- Opens ONE owned pack. The server consumes it and grants the cards before replying; the
-- request id makes a repeated request (double click, retry) return the same result
-- instead of opening another pack. The reveal is purely visual.
local function openPack(pack: Types.PackDef)
	if opening or PackReveal.isOpen() then
		return
	end
	local data = DataController:Get()
	if not data or (data.Packs[pack.Id] or 0) < 1 then
		return
	end
	opening = true
	local requestId = HttpService:GenerateGUID(false)
	local result = Request(Remotes.Functions.OpenPack, pack.Id, requestId)
	if not result.ok or type(result.cards) ~= "table" then
		opening = false
		return
	end
	PackReveal.play(pack, result.cards, function()
		opening = false
	end)
end

-- One shop row per pack.
local function buildRow(list: ScrollingFrame, pack: Types.PackDef)
	local amount = 1
	local row = Create("Frame", {
		Name = pack.Id,
		Size = UDim2.new(1, -12, 0, 124),
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
			openPack(pack)
		end,
	})
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
		Components.setButtonText(open, if owned > 0 then `OPEN ({owned})` else "NO PACKS")
		Components.setButtonStyle(open, if owned > 0 then "Orange" else "Gray")
		local affordable = (data.Currency[pack.Currency] or 0) >= pack.Price * amount
		Components.setButtonStyle(buy, if affordable and missing == nil then "Green" else "Gray")
		lockText.Text = if missing then string.upper(missing) else ""
	end
	DataController:Observe("Progression", refresh)
	DataController:Observe("Packs", refresh)
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
