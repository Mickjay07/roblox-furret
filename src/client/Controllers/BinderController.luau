--!strict
-- Binder window: collection progress and discovered cards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local CardRegistry = require(Shared.Logic.CardRegistry)
local Collections = require(Shared.Logic.Collections)

local UI = script.Parent.Parent.UI
local CardTile = require(UI.CardTile)
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Windows = require(UI.Windows)
local DataController = require(script.Parent.DataController)

local BinderController = {}

local selected = Config.Collections.List[1].Id
local tabs: Frame
local header: TextLabel
local bonus: TextLabel
local total: TextLabel
local grid: ScrollingFrame

local function render()
	local data = DataController:Get()
	if not data or not Windows.isOpen("Binder") then
		return
	end
	for _, child in tabs:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for _, collection in Config.Collections.List do
		local progress = Collections.progress(data, collection.Id)
		local button = Components.button({
			Text = `{string.upper(collection.DisplayName)}  {progress.Discovered}/{progress.Total}`,
			Style = if collection.Id == selected then "Purple" else "Gray",
			Size = UDim2.new(1, -8, 0, 48),
			LayoutOrder = collection.Order,
			Parent = tabs,
			OnClick = function()
				selected = collection.Id
				render()
			end,
		})
		button.BackgroundColor3 = if collection.Id == selected then collection.Color else button.BackgroundColor3
	end

	local def = Config.Collections.ById[selected]
	local progress = Collections.progress(data, selected)
	header.Text = `{string.upper(def.DisplayName)}  {progress.Discovered}/{progress.Total}`
	local percent = math.floor(def.CompletionIncomeBonus * 100 + 0.5)
	bonus.Text = if progress.Complete then `COMPLETE! +{percent}% INCOME` else `COMPLETE FOR +{percent}% INCOME`
	bonus.TextColor3 = if progress.Complete then Theme.Colors.Cash else Theme.Colors.Treats
	local found, all = Collections.overall(data)
	total.Text = `TOTAL {found}/{all} CARDS`

	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for _, card: Types.CardDef in CardRegistry.inCollection(selected) do
		local entry = data.Discovered[card.Id]
		if entry then
			CardTile.new(card, { LayoutOrder = card.CollectionNumber, Count = entry.Count }).Parent = grid
		else
			CardTile.unknown(card.CollectionNumber).Parent = grid
		end
	end
end

function BinderController:Start()
	Windows.register("Binder", {
		Title = "Binder",
		Accent = "Purple",
		Size = Vector2.new(940, 560),
		Build = function(content: Frame)
			tabs = Create("Frame", {
				Name = "Tabs",
				Size = UDim2.new(0, 300, 1, 0),
				BackgroundTransparency = 1,
			}, {
				Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
			})
			tabs.Parent = content
			header = Components.label({
				Text = "",
				Size = UDim2.new(1, -320, 0, 34),
				Position = UDim2.fromOffset(316, 0),
				XAlign = Enum.TextXAlignment.Left,
				Parent = content,
			})
			bonus = Components.label({
				Text = "",
				Size = UDim2.new(0.5, -170, 0, 24),
				Position = UDim2.fromOffset(316, 40),
				XAlign = Enum.TextXAlignment.Left,
				StrokeThickness = 2,
				Parent = content,
			})
			total = Components.label({
				Text = "",
				Size = UDim2.new(0.5, -170, 0, 24),
				Position = UDim2.new(1, 0, 0, 40),
				AnchorPoint = Vector2.new(1, 0),
				XAlign = Enum.TextXAlignment.Right,
				Color = Theme.Colors.Muted,
				StrokeThickness = 2,
				Parent = content,
			})
			grid = Create("ScrollingFrame", {
				Name = "Grid",
				Size = UDim2.new(1, -316, 1, -76),
				Position = UDim2.fromOffset(316, 76),
				BackgroundColor3 = Theme.Colors.PanelInset,
				BorderSizePixel = 0,
				ScrollBarThickness = 8,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = content,
			}, {
				Components.corner(UDim.new(0, 12)),
				Create("UIGridLayout", {
					CellSize = UDim2.fromOffset(130, 182),
					CellPadding = UDim2.fromOffset(12, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Create("UIPadding", {
					PaddingTop = UDim.new(0, 12),
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}),
			})
			return render
		end,
	})
	DataController.Changed:Connect(function(changed)
		if changed == "Discovered" or changed == "*" then
			render()
		end
	end)
end

return BinderController
