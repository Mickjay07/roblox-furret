--!strict
-- Backpack window: every owned card (server data), searchable and sortable, with a details
-- panel and the actions the server supports for the selected card (place / remove, favourite,
-- sell). Opened from the HUD, from My Stands, or from a physical stand to pick its card.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local CardArt = require(Shared.Logic.CardArt)
local CardRegistry = require(Shared.Logic.CardRegistry)
local Economy = require(Shared.Logic.Economy)
local Entitlements = require(Shared.Logic.Entitlements)
local Inventory = require(Shared.Logic.Inventory)
local RevealStyle = require(Shared.Logic.RevealStyle)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent.UI
local CardTile = require(UI.CardTile)
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Windows = require(UI.Windows)
local Coalesce = require(script.Parent.Parent.Lib.Coalesce)
local PackOpening = require(script.Parent.Parent.Lib.PackOpening)
local Request = require(script.Parent.Parent.Lib.Request)
local DataController = require(script.Parent.DataController)

local BackpackController = {}

type Entry = { id: string, instance: Types.CardInstance, def: Types.CardDef, income: number }

local SORTS: { { key: string, label: string } } = {
	{ key = "Recent", label = "RECENT" },
	{ key = "Rarity", label = "RARITY" },
	{ key = "Income", label = "BEST" },
}

local DETAIL_WIDTH = 304
local TAB_W = 104
local TOOLBAR_SEARCH_W = 200
local SORT_W = 100
local CAPACITY_W = 196

local sortKey = "Recent"
local query = ""
local selectedId: string? = nil
-- Set when the backpack was opened from a physical stand: the main action places the selected
-- card on that stand (through the validated PlaceCard remote).
local targetSlot: number? = nil

local grid: ScrollingFrame
local detail: Frame
local capacityChip: Frame
local sortButtons: { [string]: TextButton } = {}
-- "Cards" or "Packs" (the pack inventory: every bought or granted pack waits here).
local tab = "Cards"
local tabButtons: { [string]: TextButton } = {}
local cardsView: { GuiObject } = {}
local packsPanel: Frame
local packsList: ScrollingFrame
-- Opening size chosen per pack (1, 3 or 6).
local packModes: { [string]: number } = {}

local function rarityOrder(def: Types.CardDef): number
	local rarity = Config.Rarities.ById[def.Rarity]
	return if rarity then rarity.Order else 0
end

local function matches(entry: Entry): boolean
	if query == "" then
		return true
	end
	local needle = string.lower(query)
	local haystack =
		string.lower(`{entry.def.Name} {entry.def.Description} {entry.def.Rarity} {entry.instance.Variant}`)
	return string.find(haystack, needle, 1, true) ~= nil
end

local function sortedEntries(data: Types.PlayerData): ({ Entry }, number)
	local entries: { Entry } = {}
	local total = 0
	for id, instance in data.Cards do
		local def = CardRegistry.get(instance.CardId)
		if def then
			total += 1
			local entry = { id = id, instance = instance, def = def, income = Economy.cardIncome(instance) }
			if matches(entry) then
				table.insert(entries, entry)
			end
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
	return entries, total
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function copiesOf(data: Types.PlayerData, cardId: string): number
	local count = 0
	for _, instance in data.Cards do
		if instance.CardId == cardId then
			count += 1
		end
	end
	return count
end

local function statRow(parent: Instance, order: number, name: string, value: string, color: Color3?)
	local row = Create("Frame", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	Components.label({
		Text = name,
		Size = UDim2.fromScale(0.5, 1),
		Color = Theme.Colors.Muted,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		Parent = row,
	})
	Components.label({
		Text = value,
		Size = UDim2.fromScale(0.5, 1),
		Position = UDim2.fromScale(0.5, 0),
		Color = color or Theme.Colors.Text,
		XAlign = Enum.TextXAlignment.Right,
		StrokeThickness = 2,
		Parent = row,
	})
end

local function renderDetail(data: Types.PlayerData)
	clear(detail)
	local instance = if selectedId then data.Cards[selectedId] else nil
	local def = if instance then CardRegistry.get(instance.CardId) else nil
	if not selectedId or not instance or not def then
		selectedId = nil
		Components.paw(detail, UDim2.fromScale(0.5, 0.36), 70, Theme.Colors.Gold, 0.55, -10)
		Components.label({
			Text = if targetSlot then `PICK A CARD FOR STAND #{targetSlot}` else "TAP A CARD",
			Size = UDim2.new(1, -24, 0, 32),
			Position = UDim2.fromScale(0.5, 0.52),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = Theme.Colors.Gold,
			Parent = detail,
		})
		Components.label({
			Text = "to see its details",
			Size = UDim2.new(1, -24, 0, 20),
			Position = UDim2.fromScale(0.5, 0.6),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = Theme.Colors.Muted,
			StrokeThickness = 1.5,
			Parent = detail,
		})
		return
	end
	local id = selectedId :: string
	local standSlot = Inventory.displaySlotOf(data, id)
	local onStand = standSlot ~= nil
	local income = Economy.cardIncome(instance)
	local rarity = Config.Rarities.ById[def.Rarity]
	local rarityColor = if rarity then rarity.Color else Theme.Colors.Muted

	local stack = Create("Frame", {
		Name = "Stack",
		Size = UDim2.new(1, -24, 1, -16),
		Position = UDim2.fromOffset(12, 10),
		BackgroundTransparency = 1,
		Parent = detail,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})

	-- The card itself (full art when uploaded, with its own tags).
	local tile = CardTile.new(def, {
		Variant = instance.Variant,
		Income = income,
		Favorite = instance.Favorite,
		OnStand = onStand,
	})
	-- 104 x 156: stack total = 156 + 28 + 26 + 94 + 98 + 4 x 6 gaps = 426 px, which fits the
	-- 430 px details column.
	tile.Size = UDim2.fromOffset(104, 156)
	tile.LayoutOrder = 1
	tile.Parent = stack

	Components.label({
		Text = string.upper(def.Name),
		Size = UDim2.new(1, 0, 0, 28),
		Color = Theme.Colors.Gold,
		StrokeThickness = 3,
		LayoutOrder = 2,
		Parent = stack,
	})
	local chips = Create("Frame", {
		Name = "Chips",
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = stack,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})
	Components.chip(if rarity then rarity.DisplayName else def.Rarity, rarityColor, UDim2.fromOffset(118, 26), chips)
	local variantLabel = RevealStyle.variantLabel(instance.Variant, income, def.BaseIncome)
	local variantDef = Config.Variants.ById[instance.Variant]
	if variantLabel and variantDef then
		Components.chip(
			variantLabel,
			variantDef.Color:Lerp(Color3.new(0, 0, 0), 0.25),
			UDim2.fromOffset(130, 26),
			chips
		)
	end

	local stats = Create("Frame", {
		Name = "Stats",
		Size = UDim2.new(1, 0, 0, 4 * 22 + 3 * 2),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = stack,
	}, { Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }) })
	statRow(stats, 1, "INCOME", `+{Format.rate(income)}/S`, Theme.Colors.Cash)
	statRow(stats, 2, "SELL VALUE", `${Format.short(Economy.cardSaleValue(data, instance), 1e6)}`, Theme.Colors.Gold)
	statRow(stats, 3, "COPIES OWNED", `x{copiesOf(data, def.Id)}`)
	statRow(
		stats,
		4,
		"STATUS",
		if standSlot then `ON STAND #{standSlot}` else "IN BACKPACK",
		if onStand then Theme.Colors.Level else Theme.Colors.Text
	)

	local actions = Create("Frame", {
		Name = "Actions",
		Size = UDim2.new(1, 0, 0, 98),
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		Parent = stack,
	})
	local slot = targetSlot
	Components.button({
		Text = if slot then `PLACE ON STAND #{slot}` elseif onStand then "REMOVE FROM STAND" else "PLACE ON STAND",
		Style = if slot then "Gold" elseif onStand then "Blue" else "Green",
		Size = UDim2.new(1, 0, 0, 46),
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
		Text = if instance.Favorite then "UNFAV" else "FAVOURITE",
		Style = "Orange",
		Size = UDim2.new(0.5, -4, 0, 46),
		Position = UDim2.fromOffset(0, 52),
		Parent = actions,
		OnClick = function()
			Request(Remotes.Functions.SetFavorite, id, not instance.Favorite)
		end,
	})
	-- Selling is refused by the server for favourites and displayed cards; say why.
	local canSell = not onStand and not instance.Favorite
	Components.button({
		Text = if canSell then "SELL" elseif onStand then "ON STAND" else "FAVOURITE",
		Style = if canSell then "Gold" else "Gray",
		Size = UDim2.new(0.5, -4, 0, 46),
		Position = UDim2.new(0.5, 4, 0, 52),
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
end

local function refreshSortButtons()
	for key, button in sortButtons do
		Components.setButtonStyle(button, if key == sortKey then "Gold" else "Brown")
	end
end

local render: () -> ()

local function renderPackRow(data: Types.PlayerData, pack: Types.PackDef, owned: number, order: number)
	local row = Components.panel({
		Name = pack.Id,
		Size = UDim2.new(1, -12, 0, 150),
		LayoutOrder = order,
		Parent = packsList,
	})
	local art = CardArt.forPack(pack)
	if art then
		Create("ImageLabel", {
			Name = "PackArt",
			Size = UDim2.fromOffset(84, 126),
			Position = UDim2.fromOffset(16, 12),
			BackgroundTransparency = 1,
			Image = art,
			ScaleType = Enum.ScaleType.Fit,
			Parent = row,
		})
	else
		local badge = Components.badge(string.sub(pack.DisplayName, 1, 1), pack.Color, UDim2.fromOffset(84, 126))
		badge.Position = UDim2.fromOffset(16, 12)
		badge.Parent = row
	end
	Components.label({
		Text = string.upper(pack.DisplayName),
		Size = UDim2.fromOffset(320, 32),
		Position = UDim2.fromOffset(116, 12),
		Color = Theme.Colors.Gold,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		Parent = row,
	})
	Components.label({
		Text = `x{Format.commas(owned)} IN YOUR BAG  |  {pack.CardsPerOpen} CARDS EACH`,
		Size = UDim2.fromOffset(360, 22),
		Position = UDim2.fromOffset(116, 48),
		Color = Theme.Colors.Text,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 2,
		Parent = row,
	})
	-- Opening size: 1 always; 3x / 6x with the Multi Opening passes (locked ones lead to the
	-- Premium Shop, where the server prompts the game pass).
	local mode = packModes[pack.Id] or 1
	if not Entitlements.canUseMode(data, mode) then
		mode = 1
	end
	local options = { 1 }
	for _, product in Entitlements.products() do
		table.insert(options, product.Packs :: number)
	end
	for i, packs in options do
		local usable = Entitlements.canUseMode(data, packs)
		local label = if packs == 1 then "1 PACK" elseif usable then `{packs} PACKS` else `{packs}x LOCKED`
		Components.button({
			Text = label,
			Style = if not usable then "Purple" elseif packs == mode then "Gold" else "Brown",
			Size = UDim2.fromOffset(136, 40),
			Position = UDim2.fromOffset(116 + (i - 1) * 144, 92),
			Parent = row,
			OnClick = function()
				if usable then
					packModes[pack.Id] = packs
					render()
				else
					Windows.open("Shop")
				end
			end,
		})
	end
	local canOpen = owned >= mode
	Components.button({
		Text = if canOpen then (if mode > 1 then `OPEN {mode}x` else "OPEN") else `NEED {mode} PACKS`,
		Style = if canOpen then "Gold" else "Gray",
		Size = UDim2.fromOffset(200, 60),
		Position = UDim2.new(1, -16, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = row,
		OnClick = function()
			if canOpen then
				PackOpening.open(pack, mode)
			end
		end,
	})
end

local function renderPacks(data: Types.PlayerData)
	clear(packsList)
	local total = 0
	local order = 0
	for _, pack in Config.Packs.List do
		local owned = data.Packs[pack.Id] or 0
		if owned > 0 then
			total += owned
			order += 1
			renderPackRow(data, pack, owned, order)
		end
	end
	Components.setChipText(capacityChip, `{Format.commas(total)} PACK{if total == 1 then "" else "S"}`)
	if total > 0 then
		-- Open All (game pass): every pack in the bag with one click; locked -> the Shop.
		local bar = Create("Frame", {
			Name = "OpenAllBar",
			Size = UDim2.new(1, -12, 0, 56),
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Parent = packsList,
		})
		local unlocked = Entitlements.canOpenAll(data)
		local cap = Config.Game.Limits.MaxOpenAll
		Components.button({
			Text = if unlocked then `OPEN ALL ({math.min(total, cap)})` else "OPEN ALL  -  LOCKED",
			Style = if unlocked then "Gold" else "Purple",
			Size = UDim2.fromOffset(300, 52),
			Position = UDim2.fromScale(1, 0),
			AnchorPoint = Vector2.new(1, 0),
			Parent = bar,
			OnClick = function()
				if unlocked then
					PackOpening.openAll()
				else
					Windows.open("Shop")
				end
			end,
		})
		Components.label({
			Text = if unlocked
				then `Opens up to {cap} packs at once, as many as your backpack has room for.`
				else "Get the Open All pass in the Shop to open every pack with one click.",
			Size = UDim2.new(1, -320, 0, 24),
			Position = UDim2.new(0, 4, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Color = Theme.Colors.Muted,
			XAlign = Enum.TextXAlignment.Left,
			StrokeThickness = 1.5,
			Parent = bar,
		})
	end
	if total == 0 then
		Components.emptyState(
			packsList,
			"NO PACKS IN YOUR BAG",
			"Packs you buy wait here until you open them.",
			"BUY PACKS",
			function()
				Windows.open("Packs")
			end
		)
	end
end

render = function()
	if not Windows.isOpen("Backpack") then
		return
	end
	for name, button in tabButtons do
		Components.setButtonStyle(button, if name == tab then "Gold" else "Brown")
	end
	for _, object in cardsView do
		object.Visible = tab == "Cards"
	end
	packsPanel.Visible = tab == "Packs"
	if tab == "Packs" then
		local data = DataController:Get()
		if data then
			renderPacks(data)
		end
		return
	end
	clear(grid)
	local data = DataController:Get()
	if not data then
		Components.emptyState(grid, "LOADING YOUR CARDS...", "One moment")
		clear(detail)
		return
	end
	local entries, total = sortedEntries(data)
	Components.setChipText(
		capacityChip,
		if targetSlot then `STAND #{targetSlot}` else `{total}/{Economy.backpackCapacity(data)}`
	)
	if total == 0 then
		Components.emptyState(grid, "NO CARDS YET", "Open packs to collect ferrets.", "OPEN SHOP", function()
			Windows.open("Packs")
		end)
	elseif #entries == 0 then
		Components.emptyState(grid, "NO MATCHES", `Nothing matches "{query}".`)
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
		Icon = "ui.icon.backpack",
		Size = Vector2.new(1000, 600),
		Build = function(content: Frame)
			-- Toolbar: CARDS / PACKS tabs, search, sort, capacity.
			for i, name in { "Cards", "Packs" } do
				tabButtons[name] = Components.button({
					Text = string.upper(name),
					Style = "Brown",
					Size = UDim2.fromOffset(TAB_W, 42),
					Position = UDim2.fromOffset((i - 1) * (TAB_W + 6), 0),
					Parent = content,
					OnClick = function()
						tab = name
						render()
					end,
				})
			end
			local toolX = 2 * (TAB_W + 6) + 6
			local search = Components.searchBox(
				"Search cards...",
				UDim2.fromOffset(TOOLBAR_SEARCH_W, 42),
				content,
				function(text)
					query = text
					render()
				end
			)
			search.Position = UDim2.fromOffset(toolX, 0)
			local sortBar = Create("Frame", {
				Name = "Sort",
				Size = UDim2.fromOffset(3 * (SORT_W + 6), 42),
				Position = UDim2.fromOffset(toolX + TOOLBAR_SEARCH_W + 8, 0),
				BackgroundTransparency = 1,
				Parent = content,
			}, {
				Create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
			})
			for i, sort in SORTS do
				sortButtons[sort.key] = Components.button({
					Text = sort.label,
					Style = "Brown",
					Size = UDim2.fromOffset(SORT_W, 42),
					LayoutOrder = i,
					Parent = sortBar,
					OnClick = function()
						sortKey = sort.key
						refreshSortButtons()
						render()
					end,
				})
			end
			refreshSortButtons()
			-- Capacity sits above the details column, clear of the toolbar.
			capacityChip = Components.chip("0/0", Theme.Colors.BrownDark, UDim2.fromOffset(CAPACITY_W, 38), content)
			capacityChip.Position = UDim2.fromScale(1, 0)
			capacityChip.AnchorPoint = Vector2.new(1, 0)

			local gridPanel = Components.panel({
				Name = "GridPanel",
				Size = UDim2.new(1, -DETAIL_WIDTH - 12, 1, -54),
				Position = UDim2.fromOffset(0, 54),
				Parent = content,
			})
			grid = Create("ScrollingFrame", {
				Name = "Grid",
				Size = UDim2.new(1, -8, 1, -8),
				Position = UDim2.fromOffset(4, 4),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 8,
				ScrollBarImageColor3 = Theme.Colors.Gold,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = gridPanel,
			}, {
				Create("UIGridLayout", {
					CellSize = UDim2.fromOffset(108, 162),
					CellPadding = UDim2.fromOffset(10, 10),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Create("UIPadding", {
					PaddingTop = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 10),
				}),
			})
			detail = Components.panel({
				Name = "Detail",
				Size = UDim2.new(0, DETAIL_WIDTH, 1, -54),
				Position = UDim2.new(1, 0, 0, 54),
				AnchorPoint = Vector2.new(1, 0),
				Color = Theme.Colors.PanelDeep,
				Trim = Theme.Colors.Gold,
				Parent = content,
			})
			packsPanel = Components.panel({
				Name = "PacksPanel",
				Size = UDim2.new(1, 0, 1, -54),
				Position = UDim2.fromOffset(0, 54),
				Parent = content,
			})
			packsPanel.Visible = false
			packsList = Create("ScrollingFrame", {
				Name = "Packs",
				Size = UDim2.new(1, -8, 1, -8),
				Position = UDim2.fromOffset(4, 4),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 8,
				ScrollBarImageColor3 = Theme.Colors.Gold,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = packsPanel,
			}, {
				Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
				Create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 6) }),
			})
			cardsView = { search, sortBar, gridPanel, detail }
			return render
		end,
		OnClose = function()
			targetSlot = nil
		end,
	})

	-- Re-render while open when cards or stands change: once per frame, however many of
	-- these keys arrive together (a pack opening sends several).
	local scheduleRender = Coalesce(render)
	for _, key in { "Cards", "Display", "Upgrades", "Packs", "Purchases" } do
		DataController.Changed:Connect(function(changed)
			if changed == key or changed == "*" then
				scheduleRender()
			end
		end)
	end
end

-- Opens the backpack on the PACKS tab (owned packs, ready to open).
function BackpackController:OpenPacks()
	tab = "Packs"
	targetSlot = nil
	Windows.open("Backpack")
end

-- Opens the backpack with a card pre-selected (used by the stands window).
function BackpackController:OpenWith(instanceId: string?)
	tab = "Cards"
	selectedId = instanceId
	targetSlot = nil
	Windows.open("Backpack")
end

-- Opens the backpack to choose a card for a physical stand (used by stand prompts).
function BackpackController:OpenForStand(slot: number)
	local data = DataController:Get()
	selectedId = if data then data.Display[tostring(slot)] else nil
	targetSlot = slot
	tab = "Cards"
	Windows.open("Backpack")
end

function BackpackController:TargetSlot(): number?
	return targetSlot
end

return BackpackController
