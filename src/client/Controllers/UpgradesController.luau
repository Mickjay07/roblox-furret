--!strict
-- Upgrades window: one card per upgrade in Config.Upgrades (the upgrades the server actually
-- implements), with its level, what it does now and at the next level, and a buy button in
-- one of three states: affordable (green), unaffordable (grey) or MAXED. The button always
-- shows the FULL price of the next level; how much is missing is a separate hint below it.
-- Purchases go through the validated BuyUpgrade remote (the server re-checks the price and
-- balance); the UI only updates from replicated data. An unaffordable click is answered
-- locally with one toast instead of a request the server would reject.

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
local NotificationController = require(script.Parent.NotificationController)
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
	local state: UiLayout.UpgradeButton? = nil
	local buy = Components.button({
		Text = "",
		Style = "Green",
		Size = UDim2.fromOffset(196, 52),
		Position = UDim2.new(1, -14, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		Parent = row,
		OnClick = function()
			local current = state
			if not current or current.Maxed then
				return
			end
			if not current.Affordable then
				NotificationController:Push(`Not enough {def.Currency}. {current.Hint or ""}`, "error")
				return
			end
			Request(Remotes.Functions.BuyUpgrade, def.Id)
		end,
	})
	local hint = Components.label({
		Text = "",
		Size = UDim2.fromOffset(196, 20),
		Position = UDim2.new(1, -14, 0, 72),
		AnchorPoint = Vector2.new(1, 0),
		Color = Theme.Colors.Muted,
		StrokeThickness = 1.5,
		Parent = row,
	})
	local function refresh(data: Types.PlayerData)
		local current = Economy.upgradeLevel(data, def.Id)
		levelLabel.Text = `LV {current} / {def.MaxLevel}`
		setProgress(current / def.MaxLevel)
		local balance = data.Currency[def.Currency] or 0
		local button = UiLayout.upgradeButton(def, current, balance)
		state = button
		local now = if current > 0 then UiLayout.upgradeEffect(def.Id, current) else "nothing yet"
		effect.Text = if button.Maxed
			then `MAXED: {now}`
			else `NOW: {now}  →  NEXT: {UiLayout.upgradeEffect(def.Id, current + 1)}`
		Components.setButtonText(buy, button.Text)
		Components.setButtonStyle(buy, button.Style)
		hint.Text = if button.Maxed then "Max level reached" else (button.Hint or "")
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
