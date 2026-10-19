--!strict
-- Backpack window: every owned card, sortable, with actions for the selected card.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local CardRegistry = require(Shared.Logic.CardRegistry)
local Economy = require(Shared.Logic.Economy)
local Inventory = require(Shared.Logic.Inventory)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent.UI
local CardTile = require(UI.CardTile)
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Windows = require(UI.Windows)
local Coalesce = require(script.Parent.Parent.Lib.Coalesce)
local Request = require(script.Parent.Parent.Lib.Request)
local DataController = require(script.Parent.DataController)

local BackpackController = {}

type Entry = { id: string, instance: Types.CardInstance, def: Types.CardDef, income: number }

local SORTS: { { key: string, label: string } } = {
	{ key = "Recent", label = "RECENT" },
	{ key = "Rarity", label = "RARITY" },
	{ key = "Income", label = "BEST" },
}

local sortKey = "Recent"
local selectedId: string? = nil
-- Set when the backpack was opened from a physical stand: the main action places the selected
-- card on that stand (through the validated PlaceCard remote).
local targetSlot: number? = nil

local function rarityOrder(def: Types.CardDef): number
	local rarity = Config.Rarities.ById[def.Rarity]
	return if rarity then rarity.Order else 0
end

local function sortedEntries(data: Types.PlayerData): { Entry }
	local entries: { Entry } = {}
	for id, instance in data.Cards do
		local def = CardRegistry.get(instance.CardId)
		if def then
			table.insert(entries, { id = id, instance = instance, def = def, income = Economy.cardIncome(instance) })
		end
	end
	table.sort(entries, function(a, b)
		if sortKey == "Rarity" then
			local ra, rb = rarityOrder(a.def), rarityOrder(b.def)
			if ra ~= rb then
				return ra > rb
			end
		elseif sortKey == "Income" then
			if a.income ~= b.income then
				return a.income > b.income
			end
		end
		if a.instance.Obtained ~= b.instance.Obtained then
			return a.instance.Obtained > b.instance.Obtained
		end
		return a.id > b.id
	end)
	return entries
end

local grid: ScrollingFrame
local detail: Frame
local capacityLabel: TextLabel

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function renderDetail(data: Types.PlayerData)
	clear(detail)
	local instance = if selectedId then data.Cards[selectedId] else nil
	local def = if instance then CardRegistry.get(instance.CardId) else nil
	if not selectedId or not instance or not def then
		selectedId = nil
		Components.label({
			Text = "TAP A CARD",
			Size = UDim2.new(1, -20, 0, 36),
			Position = UDim2.fromScale(0.5, 0.4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = Theme.Colors.Muted,
			Parent = detail,
		})
		return
	end
	local id = selectedId :: string
	local onStand = Inventory.displaySlotOf(data, id) ~= nil
	local tile = CardTile.new(def, {
		Variant = instance.Variant,
		Income = Economy.cardIncome(instance),
		Favorite = instance.Favorite,
		OnStand = onStand,
	})
	tile.Size = UDim2.fromOffset(130, 182)
	tile.Position = UDim2.new(0.5, 0, 0, 8)
	tile.AnchorPoint = Vector2.new(0.5, 0)
	tile.Parent = detail

	local description = Components.label({
		Text = def.Description,
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.new(0.5, 0, 0, 196),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Theme.Colors.Muted,
		StrokeThickness = 1.5,
		Parent = detail,
	})
	description.TextWrapped = true

	local saleValue = Economy.cardSaleValue(data, instance)
	local actions = Create("Frame", {
		Name = "Actions",
		Size = UDim2.new(1, -20, 0, 160),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = detail,
	}, {
		Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
	})
	local size = UDim2.new(1, 0, 0, 46)
	local slot = targetSlot
	Components.button({
		Text = if slot then `PLACE ON STAND #{slot}` elseif onStand then "REMOVE FROM STAND" else "PLACE ON STAND",
		Style = if slot then "Green" else "Blue",
		Size = size,
		LayoutOrder = 1,
		Parent = actions,
		OnClick = function()
			if slot then
				local result = Request(Remotes.Functions.PlaceCard, id, slot)
				if result.ok then
					targetSlot = nil
					Windows.close()
				end
			elseif onStand then
				Request(Remotes.Functions.RemoveCard, id)
			else
				Request(Remotes.Functions.PlaceCard, id, 0)
			end
		end,
	})
	Components.button({
		Text = if instance.Favorite then "UNFAVOURITE" else "FAVOURITE",
		Style = "Orange",
		Size = size,
		LayoutOrder = 2,
		Parent = actions,
		OnClick = function()
			Request(Remotes.Functions.SetFavorite, id, not instance.Favorite)
		end,
	})
	local canSell = not onStand and not instance.Favorite
	local sell = Components.button({
		Text = `SELL ${Format.short(saleValue, 1e6)}`,
		Style = if canSell then "Green" else "Gray",
		Size = size,
		LayoutOrder = 3,
		Parent = actions,
		OnClick = function()
			if canSell then
				local result = Request(Remotes.Functions.SellCards, { id })
				if result.ok then
					selectedId = nil
				end
			end
		end,
	})
	sell.AutoButtonColor = false
end

local function render()
	local data = DataController:Get()
	if not data or not Windows.isOpen("Backpack") then
		return
	end
	clear(grid)
	local entries = sortedEntries(data)
	capacityLabel.Text = if targetSlot
		then `PICK FOR STAND #{targetSlot}`
		else `{#entries}/{Economy.backpackCapacity(data)}`
	if #entries == 0 then
		Components.label({
			Text = "NO CARDS YET - BUY A PACK!",
			Size = UDim2.new(1, 0, 0, 40),
			Parent = grid,
		})
	end
	for i, entry in entries do
		local tile = CardTile.new(entry.def, {
			Variant = entry.instance.Variant,
			Income = entry.income,
			Favorite = entry.instance.Favorite,
			OnStand = Inventory.displaySlotOf(data, entry.id) ~= nil,
			Selected = entry.id == selectedId,
			LayoutOrder = i,
			OnClick = function()
				selectedId = entry.id
				render()
			end,
		})
		tile.Parent = grid
	end
	renderDetail(data)
end

function BackpackController:Start()
	Windows.register("Backpack", {
		Title = "Backpack",
		Accent = "Orange",
		Size = Vector2.new(940, 560),
		Build = function(content: Frame)
			local sortBar = Create("Frame", {
				Name = "Sort",
				Size = UDim2.new(1, -300, 0, 44),
				BackgroundTransparency = 1,
				Parent = content,
			}, {
				Create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
			})
			for i, sort in SORTS do
				Components.button({
					Text = sort.label,
					Style = "Purple",
					Size = UDim2.fromOffset(120, 40),
					LayoutOrder = i,
					Parent = sortBar,
					OnClick = function()
						sortKey = sort.key
						render()
					end,
				})
			end
			capacityLabel = Components.label({
				Text = "0/0",
				Size = UDim2.fromOffset(140, 36),
				Position = UDim2.new(1, -300, 0, 4),
				AnchorPoint = Vector2.new(1, 0),
				Parent = content,
			})
			grid = Create("ScrollingFrame", {
				Name = "Grid",
				Size = UDim2.new(1, -300, 1, -54),
				Position = UDim2.fromOffset(0, 54),
				BackgroundColor3 = Theme.Colors.PanelInset,
				BorderSizePixel = 0,
				ScrollBarThickness = 8,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = content,
			}, {
				Components.corner(UDim.new(0, 12)),
				Create("UIGridLayout", {
					CellSize = UDim2.fromOffset(110, 154),
					CellPadding = UDim2.fromOffset(10, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Create("UIPadding", {
					PaddingTop = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
				}),
			})
			detail = Create("Frame", {
				Name = "Detail",
				Size = UDim2.new(0, 284, 1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Theme.Colors.PanelInset,
				Parent = content,
			}, { Components.corner(UDim.new(0, 12)) })
			return render
		end,
		OnClose = function()
			targetSlot = nil
		end,
	})

	-- Re-render while open when cards or stands change: once per frame, however many of
	-- these keys arrive together (a pack opening sends several).
	local scheduleRender = Coalesce(render)
	for _, key in { "Cards", "Display", "Upgrades" } do
		DataController.Changed:Connect(function(changed)
			if changed == key or changed == "*" then
				scheduleRender()
			end
		end)
	end
end

-- Opens the backpack with a card pre-selected (used by the stands window).
function BackpackController:OpenWith(instanceId: string?)
	selectedId = instanceId
	targetSlot = nil
	Windows.open("Backpack")
end

-- Opens the backpack to choose a card for a physical stand (used by stand prompts).
function BackpackController:OpenForStand(slot: number)
	local data = DataController:Get()
	selectedId = if data then data.Display[tostring(slot)] else nil
	targetSlot = slot
	Windows.open("Backpack")
end

function BackpackController:TargetSlot(): number?
	return targetSlot
end

return BackpackController
