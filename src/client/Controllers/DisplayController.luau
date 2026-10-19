--!strict
-- "My Stands" window: display stands that earn income, plus Place Best.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local CardRegistry = require(Shared.Logic.CardRegistry)
local Economy = require(Shared.Logic.Economy)
local IncomeLedger = require(Shared.Logic.IncomeLedger)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent.UI
local CardTile = require(UI.CardTile)
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Windows = require(UI.Windows)
local Request = require(script.Parent.Parent.Lib.Request)
local DataController = require(script.Parent.DataController)
local BackpackController = require(script.Parent.BackpackController)

local DisplayController = {}

local grid: ScrollingFrame
local summary: TextLabel
-- Per-stand collect buttons, updated in place as earnings accrue (no grid rebuild).
local collectButtons: { [string]: TextButton } = {}

local function updatePending()
	local data = DataController:Get()
	if not data then
		return
	end
	for slotKey, button in collectButtons do
		local amount = math.floor(IncomeLedger.pending(data, slotKey))
		button.Visible = amount > 0
		Components.setButtonText(button, `COLLECT ${Format.short(amount)}`)
	end
end

local function addCollectButton(cell: GuiObject, slot: number)
	local slotKey = tostring(slot)
	collectButtons[slotKey] = Components.button({
		Name = "Collect",
		Text = "",
		Style = "Green",
		Size = UDim2.new(0.92, 0, 0.17, 0),
		Position = UDim2.new(0.5, 0, 1, -6),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = cell,
		OnClick = function()
			Request(Remotes.Functions.CollectEarnings, slot)
		end,
	})
end

local function emptySlot(order: number, text: string, locked: boolean): TextButton
	local slot: TextButton = Create("TextButton", {
		Name = "Slot" .. order,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if locked then Theme.Colors.Border else Theme.Colors.PanelHeader,
		LayoutOrder = order,
	}, {
		Components.corner(UDim.new(0, 12)),
		Components.stroke(Theme.Colors.Border, 3),
	})
	Components.label({
		Text = text,
		Size = UDim2.fromScale(0.8, 0.2),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Colors.Muted,
		Parent = slot,
	})
	return slot
end

local function render()
	local data = DataController:Get()
	if not data or not Windows.isOpen("Display") then
		return
	end
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(collectButtons)
	local slots = Economy.displaySlotCount(data)
	for slot = 1, slots do
		local id = data.Display[tostring(slot)]
		local instance = if id then data.Cards[id] else nil
		local def = if instance then CardRegistry.get(instance.CardId) else nil
		if id and instance and def then
			local tile = CardTile.new(def, {
				Variant = instance.Variant,
				Income = Economy.cardIncome(instance),
				LayoutOrder = slot,
				OnClick = function()
					BackpackController:OpenWith(id)
				end,
			})
			tile.Parent = grid
			addCollectButton(tile, slot)
		else
			local empty = emptySlot(slot, "EMPTY", false)
			empty.Activated:Connect(function()
				BackpackController:OpenWith(nil)
			end)
			empty.Parent = grid
			addCollectButton(empty, slot)
		end
	end
	local locked = emptySlot(slots + 1, "BUY MORE IN UPGRADES", true)
	locked.Activated:Connect(function()
		Windows.open("Upgrades")
	end)
	locked.Parent = grid
	summary.Text = `{slots} STANDS  |  +{Format.short(Economy.totalIncome(data), 1e6)} CASH/S`
	updatePending()
end

function DisplayController:Start()
	Windows.register("Display", {
		Title = "My Stands",
		Accent = "Blue",
		Size = Vector2.new(900, 560),
		Build = function(content: Frame)
			summary = Components.label({
				Text = "",
				Size = UDim2.new(1, -460, 0, 40),
				XAlign = Enum.TextXAlignment.Left,
				Color = Theme.Colors.Cash,
				Parent = content,
			})
			Components.button({
				Text = "COLLECT ALL",
				Style = "Green",
				Size = UDim2.fromOffset(200, 48),
				Position = UDim2.new(1, -232, 0, -4),
				AnchorPoint = Vector2.new(1, 0),
				Parent = content,
				OnClick = function()
					Request(Remotes.Functions.CollectEarnings, 0)
				end,
			})
			Components.button({
				Text = "PLACE BEST",
				Style = "Orange",
				Size = UDim2.fromOffset(220, 48),
				Position = UDim2.new(1, 0, 0, -4),
				AnchorPoint = Vector2.new(1, 0),
				Parent = content,
				OnClick = function()
					Request(Remotes.Functions.PlaceBest)
				end,
			})
			grid = Create("ScrollingFrame", {
				Name = "Grid",
				Size = UDim2.new(1, 0, 1, -56),
				Position = UDim2.fromOffset(0, 56),
				BackgroundColor3 = Theme.Colors.PanelInset,
				BorderSizePixel = 0,
				ScrollBarThickness = 8,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = content,
			}, {
				Components.corner(UDim.new(0, 12)),
				Create("UIGridLayout", {
					CellSize = UDim2.fromOffset(150, 210),
					CellPadding = UDim2.fromOffset(14, 14),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }),
			})
			return render
		end,
	})
	DataController.Changed:Connect(function(changed)
		if changed == "Income" and Windows.isOpen("Display") then
			updatePending()
		end
	end)
	for _, key in { "Display", "Cards", "Upgrades", "Discovered" } do
		DataController.Changed:Connect(function(changed)
			if changed == key or changed == "*" then
				render()
			end
		end)
	end
end

return DisplayController
