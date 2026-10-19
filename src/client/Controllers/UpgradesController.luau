--!strict
-- Upgrades window: one card per upgrade in Config.Upgrades (the upgrades the server actually
-- implements), with its level, what it does now and at the next level, and a buy button in
-- one of three states: affordable, unaffordable ("NEED $X") or maxed. Purchases go through
-- the validated BuyUpgrade remote; the UI only updates from replicated data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local CardArt = require(Shared.Logic.CardArt)
local Economy = require(Shared.Logic.Economy)
local UiLayout = require(Shared.Logic.UiLayout)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent.UI
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Windows = require(UI.Windows)
local Request = require(script.Parent.Parent.Lib.Request)
local DataController = require(script.Parent.DataController)

local UpgradesController = {}

local function buildRow(list: Instance, def: Types.UpgradeDef)
	local row = Components.panel({
		Name = def.Id,
		Size = UDim2.new(1, -12, 0, 104),
		LayoutOrder = def.Order,
		Parent = list,
	})
	local icon = CardArt.image("ui.icon.upgrades")
	if icon then
		Create("ImageLabel", {
			Name = "Icon",
			Size = UDim2.fromOffset(76, 76),
			Position = UDim2.new(0, 12, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = icon,
			ScaleType = Enum.ScaleType.Fit,
			Parent = row,
		})
	else
		local badge = Components.badge("+", Theme.Colors.Leaf, UDim2.fromOffset(64, 64))
		badge.Position = UDim2.new(0, 18, 0.5, 0)
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Parent = row
	end
	Components.label({
		Text = string.upper(def.DisplayName),
		Size = UDim2.new(0, 330, 0, 30),
		Position = UDim2.fromOffset(100, 10),
		Color = Theme.Colors.Gold,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		Parent = row,
	})
	Components.label({
		Text = def.Description,
		Size = UDim2.new(0, 330, 0, 20),
		Position = UDim2.fromOffset(100, 42),
		Color = Theme.Colors.Muted,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		Parent = row,
	})
	local effect = Components.label({
		Text = "",
		Size = UDim2.new(0, 330, 0, 20),
		Position = UDim2.fromOffset(100, 70),
		Color = Theme.Colors.Text,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 2,
		Parent = row,
	})
	local levelLabel = Components.label({
		Text = "",
		Size = UDim2.fromOffset(140, 22),
		Position = UDim2.new(1, -230, 0, 22),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Right,
		StrokeThickness = 2,
		Parent = row,
	})
	local bar, setProgress = Components.progressBar(Theme.Colors.Gold, UDim2.fromOffset(140, 12))
	bar.Position = UDim2.new(1, -230, 0, 52)
	bar.AnchorPoint = Vector2.new(1, 0)
	bar.Parent = row
	local buy = Components.button({
		Text = "",
		Style = "Green",
		Size = UDim2.fromOffset(196, 58),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = row,
		OnClick = function()
			Request(Remotes.Functions.BuyUpgrade, def.Id)
		end,
	})
	local function refresh(data: Types.PlayerData)
		local current = Economy.upgradeLevel(data, def.Id)
		levelLabel.Text = `LV {current} / {def.MaxLevel}`
		setProgress(current / def.MaxLevel)
		local cost = Economy.upgradeCost(def, current)
		local now = if current > 0 then UiLayout.upgradeEffect(def.Id, current) else "nothing yet"
		if cost then
			effect.Text = `NOW: {now}  →  NEXT: {UiLayout.upgradeEffect(def.Id, current + 1)}`
			local balance = data.Currency[def.Currency] or 0
			local need = UiLayout.shortfall(balance, cost)
			Components.setButtonText(buy, need or ("$" .. Format.short(cost, 1e6)))
			Components.setButtonStyle(buy, if need then "Gray" else "Green")
		else
			effect.Text = `MAXED: {now}`
			Components.setButtonText(buy, "MAXED")
			Components.setButtonStyle(buy, "Gold")
		end
	end
	DataController:Observe("Upgrades", refresh)
	DataController:Observe("Currency", refresh)
end

function UpgradesController:Start()
	Windows.register("Upgrades", {
		Title = "Upgrades",
		Icon = "ui.icon.upgrades",
		Size = Vector2.new(900, 600),
		Build = function(content: Frame)
			local balance = Components.chip("$0", Theme.Colors.BrownDark, UDim2.fromOffset(240, 34), content)
			balance.Position = UDim2.fromScale(1, 0)
			balance.AnchorPoint = Vector2.new(1, 0)
			Components.sectionTitle("IMPROVE YOUR FERRET FARM", UDim2.new(1, -260, 0, 30), content)
			DataController:Observe("Currency", function(data: Types.PlayerData)
				Components.setChipText(balance, `BALANCE ${Format.short(data.Currency.Cash or 0, 1e9)}`)
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
				Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
				Create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) }),
			})
			for _, def in Config.Upgrades.List do
				buildRow(list, def)
			end
			return nil
		end,
	})
end

return UpgradesController
