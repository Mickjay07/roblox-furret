--!strict
-- Upgrades window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Economy = require(Shared.Logic.Economy)
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
	local row = Create("Frame", {
		Name = def.Id,
		Size = UDim2.new(1, -12, 0, 86),
		BackgroundColor3 = Theme.Colors.PanelInset,
		LayoutOrder = def.Order,
		Parent = list,
	}, { Components.corner(UDim.new(0, 12)), Components.stroke(Theme.Colors.Border, 2) })
	Components.label({
		Text = string.upper(def.DisplayName),
		Size = UDim2.new(0, 360, 0, 32),
		Position = UDim2.fromOffset(16, 10),
		XAlign = Enum.TextXAlignment.Left,
		Parent = row,
	})
	Components.label({
		Text = def.Description,
		Size = UDim2.new(0, 360, 0, 22),
		Position = UDim2.fromOffset(16, 50),
		XAlign = Enum.TextXAlignment.Left,
		Color = Theme.Colors.Muted,
		StrokeThickness = 1.5,
		Parent = row,
	})
	local level = Components.label({
		Text = "",
		Size = UDim2.fromOffset(120, 30),
		Position = UDim2.new(1, -230, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = row,
	})
	local buy = Components.button({
		Text = "",
		Style = "Green",
		Size = UDim2.fromOffset(200, 54),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = row,
		OnClick = function()
			Request(Remotes.Functions.BuyUpgrade, def.Id)
		end,
	})
	local function refresh(data: Types.PlayerData)
		local current = Economy.upgradeLevel(data, def.Id)
		level.Text = `LV {current}/{def.MaxLevel}`
		local cost = Economy.upgradeCost(def, current)
		if cost then
			Components.setButtonText(buy, "$" .. Format.short(cost, 1e6))
			Components.setButtonStyle(buy, if (data.Currency[def.Currency] or 0) >= cost then "Green" else "Gray")
		else
			Components.setButtonText(buy, "MAXED")
			Components.setButtonStyle(buy, "Purple")
		end
	end
	DataController:Observe("Upgrades", refresh)
	DataController:Observe("Currency", refresh)
end

function UpgradesController:Start()
	Windows.register("Upgrades", {
		Title = "Upgrades",
		Accent = "Green",
		Size = Vector2.new(820, 540),
		Build = function(content: Frame)
			local list = Create("ScrollingFrame", {
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
			for _, def in Config.Upgrades.List do
				buildRow(list, def)
			end
			return nil
		end,
	})
end

return UpgradesController
