--!strict
-- Binder window: the player's card collection as an album. Bookmarks on the left (one per
-- collection, with progress), the selected collection's page on the right: discovered cards
-- show their art and copy count, undiscovered ones show the card back and their number.
-- Everything comes from replicated data (Discovered) and Config; nothing is invented.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local CardRegistry = require(Shared.Logic.CardRegistry)
local Collections = require(Shared.Logic.Collections)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent.UI
local CardTile = require(UI.CardTile)
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Windows = require(UI.Windows)
local Coalesce = require(script.Parent.Parent.Lib.Coalesce)
local DataController = require(script.Parent.DataController)

local BinderController = {}

local TAB_WIDTH = 270
-- Grid cell: the card (2:3) plus a reserved strip underneath for the copy count, so the
-- count never covers the card's art, name, rarity or income.
local CARD_W, CARD_H = 120, 180
local STRIP_H = 26

local selected = Config.Collections.List[1].Id
local tabs: ScrollingFrame
local title: TextLabel
local countLabel: TextLabel
local setProgress: (number) -> ()
local bonusChip: Frame
local totalLabel: TextLabel
local grid: ScrollingFrame

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function bookmark(collection: Types.CollectionDef, progress: any, isSelected: boolean)
	local button: TextButton = Create("TextButton", {
		Name = collection.Id,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, -10, 0, 62),
		BackgroundColor3 = if isSelected then Theme.Colors.PanelHeader else Theme.Colors.PanelInset,
		LayoutOrder = collection.Order,
		Parent = tabs,
	}, {
		Components.corner(UDim.new(0, 12)),
		Create("UIStroke", {
			Color = if isSelected then Theme.Colors.Gold else Theme.Colors.Border,
			Thickness = if isSelected then 3 else 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
	-- Coloured spine of the bookmark.
	Create("Frame", {
		Name = "Spine",
		Size = UDim2.new(0, 10, 1, -14),
		Position = UDim2.fromOffset(8, 7),
		BackgroundColor3 = collection.Color,
		Active = false,
		Parent = button,
	}, { Components.corner(UDim.new(1, 0)) })
	Components.label({
		Text = string.upper(collection.DisplayName),
		Size = UDim2.new(1, -96, 0, 26),
		Position = UDim2.fromOffset(28, 8),
		Color = if isSelected then Theme.Colors.Gold else Theme.Colors.Text,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 2,
		Parent = button,
	})
	Components.label({
		Text = `{progress.Discovered}/{progress.Total}`,
		Size = UDim2.fromOffset(62, 24),
		Position = UDim2.new(1, -10, 0, 9),
		AnchorPoint = Vector2.new(1, 0),
		Color = if progress.Complete then Theme.Colors.Cash else Theme.Colors.Muted,
		XAlign = Enum.TextXAlignment.Right,
		StrokeThickness = 2,
		Parent = button,
	})
	local bar, set = Components.progressBar(collection.Color, UDim2.new(1, -40, 0, 9))
	bar.Position = UDim2.new(0, 28, 1, -18)
	bar.Parent = button
	set(if progress.Total > 0 then progress.Discovered / progress.Total else 0)
	button.Activated:Connect(function()
		selected = collection.Id
		BinderController:Render()
	end)
end

function BinderController:Render()
	if not Windows.isOpen("Binder") then
		return
	end
	clear(tabs)
	clear(grid)
	local data = DataController:Get()
	if not data then
		Components.emptyState(grid, "LOADING YOUR BINDER...", "One moment")
		return
	end
	for _, collection in Config.Collections.List do
		bookmark(collection, Collections.progress(data, collection.Id), collection.Id == selected)
	end

	local def = Config.Collections.ById[selected]
	local progress = Collections.progress(data, selected)
	title.Text = string.upper(def.DisplayName)
	local percent = if progress.Total > 0 then math.floor(progress.Discovered / progress.Total * 100) else 0
	countLabel.Text = `{progress.Discovered}/{progress.Total} FOUND  ·  {percent}%`
	setProgress(if progress.Total > 0 then progress.Discovered / progress.Total else 0)
	local bonus = math.floor(def.CompletionIncomeBonus * 100 + 0.5)
	if progress.Complete then
		Components.setChipText(bonusChip, `COMPLETE! +{bonus}% INCOME`)
		bonusChip.BackgroundColor3 = Theme.Buttons.Green[1]
	else
		Components.setChipText(bonusChip, `COMPLETE FOR +{bonus}% INCOME`)
		bonusChip.BackgroundColor3 = Theme.Colors.Brown
	end
	local found, all = Collections.overall(data)
	totalLabel.Text = `ALL COLLECTIONS {found}/{all}`

	-- Copies the player owns right now (the backpack is the source of truth; Discovered.Count
	-- counts every copy ever found, including sold ones).
	local owned: { [string]: number } = {}
	for _, instance in data.Cards do
		owned[instance.CardId] = (owned[instance.CardId] or 0) + 1
	end
	for _, card: Types.CardDef in CardRegistry.inCollection(selected) do
		local entry = data.Discovered[card.Id]
		local cell = Create("Frame", {
			Name = card.Id,
			BackgroundTransparency = 1,
			LayoutOrder = card.CollectionNumber,
			Parent = grid,
		})
		local tile: GuiObject = if entry then CardTile.new(card, {}) else CardTile.unknown(nil, card.CollectionNumber)
		tile.Size = UDim2.fromOffset(CARD_W, CARD_H)
		tile.Parent = cell
		-- Copy count in its own strip below the card.
		if entry then
			local count = owned[card.Id] or 0
			local chip = Components.chip(
				`OWNED x{Format.commas(count)}`,
				if count > 0 then Theme.Colors.BrownDark else Theme.Colors.PanelDeep,
				nil,
				cell
			)
			chip.Size = UDim2.fromOffset(CARD_W - 8, STRIP_H - 4)
			chip.Position = UDim2.fromOffset(4, CARD_H + 4)
		else
			Components.label({
				Text = "NOT FOUND",
				Size = UDim2.fromOffset(CARD_W - 16, STRIP_H - 8),
				Position = UDim2.fromOffset(8, CARD_H + 6),
				Color = Theme.Colors.Muted,
				StrokeThickness = 1.5,
				Parent = cell,
			})
		end
	end
end

function BinderController:Start()
	Windows.register("Binder", {
		Title = "Binder",
		Icon = "ui.icon.binder",
		Size = Vector2.new(1000, 620),
		Build = function(content: Frame)
			local tabPanel = Components.panel({
				Name = "Bookmarks",
				Size = UDim2.new(0, TAB_WIDTH, 1, 0),
				Parent = content,
			})
			tabs = Create("ScrollingFrame", {
				Name = "Tabs",
				Size = UDim2.new(1, -8, 1, -12),
				Position = UDim2.fromOffset(6, 6),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Colors.Gold,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = tabPanel,
			}, {
				Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
				Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
			})

			-- The album page.
			local page = Components.panel({
				Name = "Page",
				Size = UDim2.new(1, -TAB_WIDTH - 12, 1, 0),
				Position = UDim2.fromScale(1, 0),
				AnchorPoint = Vector2.new(1, 0),
				Color = Theme.Colors.PanelDeep,
				Trim = Theme.Colors.Brown,
				Parent = content,
			})
			title = Components.label({
				Text = "",
				Size = UDim2.new(0.55, 0, 0, 36),
				Position = UDim2.fromOffset(18, 12),
				Color = Theme.Colors.Gold,
				XAlign = Enum.TextXAlignment.Left,
				StrokeThickness = 3,
				Parent = page,
			})
			totalLabel = Components.label({
				Text = "",
				Size = UDim2.new(0.42, 0, 0, 22),
				Position = UDim2.new(1, -18, 0, 18),
				AnchorPoint = Vector2.new(1, 0),
				Color = Theme.Colors.Muted,
				XAlign = Enum.TextXAlignment.Right,
				StrokeThickness = 1.5,
				Parent = page,
			})
			local bar
			bar, setProgress = Components.progressBar(Theme.Colors.Gold, UDim2.new(0.5, -18, 0, 14))
			bar.Position = UDim2.fromOffset(18, 58)
			bar.Parent = page
			countLabel = Components.label({
				Text = "",
				Size = UDim2.new(0.5, -40, 0, 20),
				Position = UDim2.new(0.5, 12, 0, 55),
				Color = Theme.Colors.Text,
				XAlign = Enum.TextXAlignment.Left,
				StrokeThickness = 2,
				Parent = page,
			})
			bonusChip = Components.chip("", Theme.Colors.Brown, UDim2.fromOffset(280, 28), page)
			bonusChip.Position = UDim2.fromOffset(18, 82)
			grid = Create("ScrollingFrame", {
				Name = "Grid",
				Size = UDim2.new(1, -16, 1, -128),
				Position = UDim2.fromOffset(8, 122),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 8,
				ScrollBarImageColor3 = Theme.Colors.Gold,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = page,
			}, {
				Create("UIGridLayout", {
					CellSize = UDim2.fromOffset(CARD_W, CARD_H + STRIP_H + 2),
					CellPadding = UDim2.fromOffset(12, 12),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 12) }),
			})
			return function()
				BinderController:Render()
			end
		end,
	})
	-- Owned counts come from Cards, discoveries from Discovered: one re-render per frame.
	local scheduleRender = Coalesce(function()
		BinderController:Render()
	end)
	DataController.Changed:Connect(function(changed)
		if changed == "Discovered" or changed == "Cards" or changed == "*" then
			scheduleRender()
		end
	end)
end

return BinderController
