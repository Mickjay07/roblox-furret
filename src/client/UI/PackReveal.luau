--!strict
-- Pack opening scene (spec §7.5, roadmap A7). Purely visual: the server has already
-- consumed the packs and added every card before this plays, so closing it, skipping it
-- or disconnecting never loses or duplicates a reward.
--
-- One scene for 1, 3 or 6 packs opened together (Multi Opening), laid out as columns:
--   1. All packs appear side by side over a blurred world, shake together (harder when a
--      rarer card is inside), then burst open; each column shows the shared card back.
--   2. Manual reveal (Logic/RevealPlan, no timers): CLICK TO REVEAL (or click a card)
--      flips card k of EVERY pack at once - 1, 3 or 6 cards - with rarity effects
--      (Logic/RevealStyle) and each card's name, rarity, income and variant bonus.
--      NEXT CARD turns the next round face down. No pack is finished before the others.
--   3. After round 5 (or SKIP TO SUMMARY): every card - 5, 15 or 30 - and CLAIM ALL.
--
-- Image instances are reused: each column keeps one ImageLabel and only its Image switches
-- between the card back and the front. The cards' images are preloaded during step 1.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local CardArt = require(Shared.Logic.CardArt)
local CardRegistry = require(Shared.Logic.CardRegistry)
local RevealPlan = require(Shared.Logic.RevealPlan)
local RevealStyle = require(Shared.Logic.RevealStyle)
local Format = require(Shared.Util.Format)

local ImagePreloader = require(script.Parent.Parent.Lib.ImagePreloader)
local CardTile = require(script.Parent.CardTile)
local Components = require(script.Parent.Components)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

export type RevealCard = {
	InstanceId: string,
	CardId: string,
	Variant: string,
	IsNew: boolean,
	OneIn: number,
	Income: number,
	Pack: number?,
	Slot: number?,
}

type Column = {
	frame: Frame,
	flipper: Frame,
	face: ImageLabel,
	drawnBack: Frame,
	tileHolder: Frame,
	glow: Frame,
	pop: UIScale,
	labels: { TextLabel },
}

type Layout = { cardWidth: number, gap: number, infoHeights: { number }, useThumb: boolean }

local PackReveal = {}

local ROOT_SIZE = Vector2.new(1100, 760)
local MAX_SPARKS = 36

local gui: ScreenGui? = nil
local stage: Frame
local flash: Frame
local skipButton: TextButton
local actionButton: TextButton
local cardCatcher: TextButton
local blur: BlurEffect? = nil
local session = 0
local busy = false
local onClosed: (() -> ())? = nil

-- Current opening.
local plan: RevealPlan.Plan? = nil
local currentCards: { RevealCard } = {}
local currentPack: Types.PackDef? = nil
local columns: { Column } = {}
local layout: Layout
local effects: { Instance } = {}
local roundLabel: TextLabel? = nil

local function layoutFor(packs: number): Layout
	if packs >= 6 then
		return { cardWidth = 158, gap = 12, infoHeights = { 22, 17, 20, 16 }, useThumb = true }
	elseif packs >= 3 then
		return { cardWidth = 226, gap = 18, infoHeights = { 28, 20, 24, 18 }, useThumb = false }
	end
	return { cardWidth = 280, gap = 0, infoHeights = { 36, 26, 30, 22 }, useThumb = false }
end

local function alive(token: number): boolean
	return token == session
end

local function play(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), goal):Play()
end

local function clearEffects()
	for _, effect in effects do
		effect:Destroy()
	end
	table.clear(effects)
end

local function clearStage()
	clearEffects()
	table.clear(columns)
	roundLabel = nil
	for _, child in stage:GetChildren() do
		child:Destroy()
	end
end

local function doFlash(strength: number)
	if Components.reducedMotion then
		return
	end
	flash.BackgroundTransparency = 1 - strength
	play(flash, 0.45, { BackgroundTransparency = 1 })
end

local function shakeStage(token: number, intensity: number, times: number)
	if Components.reducedMotion then
		return
	end
	for i = 1, times do
		if not alive(token) then
			return
		end
		local dx = (if i % 2 == 0 then 1 else -1) * intensity
		stage.Position = UDim2.new(0.5, dx, 0.5, math.random(-intensity, intensity) // 2)
		task.wait(0.035)
	end
	stage.Position = UDim2.fromScale(0.5, 0.5)
end

local function burst(parent: GuiObject, color: Color3, count: number)
	if Components.reducedMotion then
		return
	end
	for _ = 1, count do
		local size = math.random(8, 18)
		local spark = Create("Frame", {
			Name = "Spark",
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromScale(0.5, 0.4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = math.random(0, 90),
			BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), math.random() * 0.5),
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = parent,
		}, { Components.corner(UDim.new(0.25, 0)) })
		local angle = math.random() * math.pi * 2
		local distance = math.random(120, 300)
		play(spark, 0.9, {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.4, math.sin(angle) * distance),
			BackgroundTransparency = 1,
			Rotation = spark.Rotation + math.random(90, 360),
		}, Enum.EasingStyle.Quart)
		task.delay(1, function()
			spark:Destroy()
		end)
	end
end

local function rays(parent: GuiObject, color: Color3, size: number): Frame
	local holder = Create("Frame", {
		Name = "Rays",
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(0.5, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = parent,
	})
	for i = 0, 7 do
		Create("Frame", {
			Size = UDim2.new(0, size * 0.05, 1, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = i * 22.5,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = holder,
		}, {
			Create("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 90,
			}),
		})
	end
	if not Components.reducedMotion then
		-- Endless slow spin; destroying the frame stops the tween.
		TweenService
			:Create(holder, TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
			:Play()
	end
	return holder
end

local function stageLabel(text: string, y: number, height: number, color: Color3?): TextLabel
	local label = Components.label({
		Text = text,
		Size = UDim2.new(0, 700, 0, height),
		Position = UDim2.new(0.5, 0, 0, y),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = color,
		StrokeThickness = 3,
		Parent = stage,
	})
	label.ZIndex = 6
	return label
end

local function frontImage(def: Types.CardDef): string?
	if not Config.Assets.FullCardArt then
		return nil
	end
	return if layout.useThumb then CardArt.thumbnail(def.Artwork) else CardArt.forCard(def)
end

-- Builds one column per pack: card (one reusable ImageLabel), glow and info labels.
local function buildColumns(packs: number)
	local cardHeight = layout.cardWidth * 1.5
	local infoHeight = 0
	for _, height in layout.infoHeights do
		infoHeight += height + 4
	end
	local row = Create("Frame", {
		Name = "Columns",
		Size = UDim2.new(1, 0, 0, cardHeight + infoHeight + 16),
		Position = UDim2.new(0.5, 0, 0, if packs >= 6 then 150 else 110),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = stage,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, layout.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local backImage = CardArt.backFor(currentPack)
	for p = 1, packs do
		local frame = Create("Frame", {
			Name = "Pack" .. p,
			Size = UDim2.fromOffset(layout.cardWidth, cardHeight + infoHeight + 16),
			BackgroundTransparency = 1,
			LayoutOrder = p,
			Parent = row,
		})
		local glow = Create("Frame", {
			Name = "Glow",
			Size = UDim2.fromOffset(layout.cardWidth + 24, cardHeight + 24),
			Position = UDim2.fromOffset(layout.cardWidth / 2, cardHeight / 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = frame,
		}, { Components.corner(UDim.new(0, 22)) })
		local flipper = Create("Frame", {
			Name = "Flipper",
			Size = UDim2.fromOffset(layout.cardWidth, cardHeight),
			Position = UDim2.fromOffset(layout.cardWidth / 2, cardHeight / 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = frame,
		})
		local pop = Create("UIScale", { Scale = 1, Parent = flipper })
		local face = Create("ImageLabel", {
			Name = "Face",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = backImage or "",
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = 4,
			Parent = flipper,
		})
		-- Drawn back, only when the card back image isn't uploaded.
		local drawnBack = Create("Frame", {
			Name = "DrawnBack",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(28, 70, 46),
			Visible = backImage == nil,
			ZIndex = 4,
			Parent = flipper,
		}, { Components.corner(UDim.new(0, 14)), Components.stroke(Color3.fromRGB(214, 180, 110), 4) })
		local mark = Components.label({ Text = "?", Size = UDim2.fromScale(0.5, 0.3), Parent = drawnBack })
		mark.Position = UDim2.fromScale(0.5, 0.5)
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.ZIndex = 5
		-- Holds a placeholder tile for fronts without uploaded art.
		local tileHolder = Create("Frame", {
			Name = "Tile",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = flipper,
		})
		local labels = {}
		local y = cardHeight + 12
		for i, height in layout.infoHeights do
			local label = Components.label({
				Text = "",
				Size = UDim2.new(1, 16, 0, height),
				Position = UDim2.new(0.5, 0, 0, y),
				AnchorPoint = Vector2.new(0.5, 0),
				StrokeThickness = if i == 1 then 2.5 else 2,
				Parent = frame,
			})
			label.ZIndex = 6
			table.insert(labels, label)
			y += height + 4
		end
		table.insert(columns, {
			frame = frame,
			flipper = flipper,
			face = face,
			drawnBack = drawnBack,
			tileHolder = tileHolder,
			glow = glow,
			pop = pop,
			labels = labels,
		})
	end
end

local function showBack(column: Column)
	local backImage = CardArt.backFor(currentPack)
	column.face.Image = backImage or ""
	column.face.Visible = true
	column.drawnBack.Visible = backImage == nil
	column.tileHolder:ClearAllChildren()
	column.glow.BackgroundTransparency = 1
	for _, label in column.labels do
		label.Text = ""
	end
end

local function showFront(column: Column, card: RevealCard, def: Types.CardDef)
	column.drawnBack.Visible = false
	local image = frontImage(def)
	if image then
		column.face.Image = image
		column.face.Visible = true
	else
		column.face.Visible = false
		local tile = CardTile.new(def, { Variant = card.Variant, IsNew = card.IsNew, Income = card.Income })
		tile.Size = UDim2.fromScale(1, 1)
		tile.ZIndex = 4
		tile.Parent = column.tileHolder
	end
end

-- Shiny (and every non-Normal variant): a light sweep across the card and a ribbon with the
-- variant bonus above it ("SHINY +2%"). Both are round effects, cleared on the next round.
local function variantFlourish(column: Column, card: RevealCard, def: Types.CardDef)
	local label = RevealStyle.variantLabel(card.Variant, card.Income, def.BaseIncome)
	local variant = Config.Variants.ById[card.Variant]
	if not label or not variant then
		return
	end
	local sheen = Create("Frame", {
		Name = "Sheen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = variant.Color:Lerp(Color3.new(1, 1, 1), 0.55),
		ZIndex = 5,
		Active = false,
		Parent = column.flipper,
	}, {
		Components.corner(UDim.new(0.06, 0)),
		Create("UIGradient", {
			Rotation = 25,
			Offset = Vector2.new(-1, 0),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.4, 1),
				NumberSequenceKeypoint.new(0.5, 0.3),
				NumberSequenceKeypoint.new(0.6, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	table.insert(effects, sheen)
	local gradient = sheen:FindFirstChildOfClass("UIGradient")
	if gradient and not Components.reducedMotion then
		TweenService:Create(
			gradient,
			TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 2, false, 0.2),
			{ Offset = Vector2.new(1, 0) }
		):Play()
	else
		sheen.Visible = false
	end
	local ribbon = Components.chip(
		label,
		variant.Color:Lerp(Color3.new(0, 0, 0), 0.3),
		UDim2.fromOffset(math.floor(layout.cardWidth * 0.86), 28),
		column.frame
	)
	ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
	ribbon.Position = UDim2.fromOffset(layout.cardWidth / 2, 2)
	ribbon.ZIndex = 8
	for _, child in ribbon:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 9
		end
	end
	table.insert(effects, ribbon)
end

local function fillLabels(column: Column, card: RevealCard, def: Types.CardDef)
	local rarity = Config.Rarities.ById[def.Rarity]
	local variantLabel = RevealStyle.variantLabel(card.Variant, card.Income, def.BaseIncome)
	local variantDef = Config.Variants.ById[card.Variant]
	local extra = variantLabel or (if card.IsNew then "NEW!" else `1 IN {Format.commas(card.OneIn)}`)
	local texts: { { text: string, color: Color3 } } = {
		{ text = string.upper(def.Name), color = Theme.Colors.Text },
		{
			text = if rarity then rarity.DisplayName else def.Rarity,
			color = if rarity then rarity.Color else Theme.Colors.Muted,
		},
		{ text = `+{Format.rate(card.Income)}/S`, color = Theme.Colors.Cash },
		{
			text = extra,
			color = if variantLabel and variantDef then variantDef.Color else Theme.Colors.Muted,
		},
	}
	for i, label in column.labels do
		local entry = texts[i]
		label.Text = if entry then entry.text else ""
		label.TextColor3 = if entry then entry.color else Theme.Colors.Text
		label.TextTransparency = 1
		play(label, 0.25, { TextTransparency = 0 })
	end
end

local function setAction(text: string?, style: string?)
	if text then
		Components.setButtonText(actionButton, text)
		Components.setButtonStyle(actionButton, style or "Orange")
		actionButton.Visible = true
	else
		actionButton.Visible = false
	end
end

local function updateRoundLabel()
	local current = plan
	if roundLabel and current then
		local packs = current.packs
		roundLabel.Text = if packs > 1
			then `CARD {current.round} / {#current.rounds}  ·  {packs} PACKS`
			else `CARD {current.round} / {#current.rounds}`
	end
end

-- Turns the current round face down and waits for CLICK TO REVEAL.
local function presentHidden()
	clearEffects()
	for _, column in columns do
		showBack(column)
		column.pop.Scale = 0.85
		Components.tween(column.pop, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	updateRoundLabel()
	setAction("CLICK TO REVEAL", "Gold")
	cardCatcher.Visible = true
end

local showSummary: () -> ()

-- Flips every column at once and plays the rarity effects of this round.
local function revealRound(token: number)
	local current = plan
	if not current or busy or not RevealPlan.reveal(current) then
		return
	end
	busy = true
	setAction(nil)
	cardCatcher.Visible = false
	local round = RevealPlan.current(current)
	local cardHeight = layout.cardWidth * 1.5

	-- Flip: squash, swap faces, unsquash - all columns together.
	for _, column in columns do
		play(column.flipper, 0.14, { Size = UDim2.fromOffset(0, cardHeight) })
	end
	task.wait(if Components.reducedMotion then 0 else 0.15)
	if not alive(token) then
		return
	end
	local bestTier, bestIndex = 0, 1
	for i, column in columns do
		local card = round[i] :: RevealCard?
		local def = if card then CardRegistry.get(card.CardId) else nil
		if card and def then
			showFront(column, card, def)
			fillLabels(column, card, def)
			variantFlourish(column, card, def)
			local style = RevealStyle.forRarity(def.Rarity)
			local rarity = Config.Rarities.ById[def.Rarity]
			local color = if rarity then rarity.Color else Theme.Colors.Muted
			column.glow.BackgroundColor3 = color
			play(column.glow, 0.3, { BackgroundTransparency = 0.6 - style.Tier * 0.08 })
			burst(column.frame, color, math.min(style.Burst, MAX_SPARKS // #columns))
			if style.Tier > bestTier then
				bestTier, bestIndex = style.Tier, i
			end
			column.pop.Scale = 1.08
			Components.tween(column.pop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		else
			column.face.Visible = false
		end
		play(column.flipper, 0.18, { Size = UDim2.fromOffset(layout.cardWidth, cardHeight) }, Enum.EasingStyle.Back)
	end

	-- Round-wide effects follow the rarest card of the round.
	local bestCard = round[bestIndex] :: RevealCard?
	local bestDef = if bestCard then CardRegistry.get(bestCard.CardId) else nil
	if bestDef then
		local style = RevealStyle.forRarity(bestDef.Rarity)
		local rarity = Config.Rarities.ById[bestDef.Rarity]
		local color = if rarity then rarity.Color else Theme.Colors.Muted
		if style.Rays and columns[bestIndex] then
			table.insert(effects, rays(columns[bestIndex].frame, color, layout.cardWidth * 2.6))
		end
		if style.Banner then
			local banner = stageLabel(style.Banner, 52, 50, color)
			table.insert(effects, banner)
			local scale = Create("UIScale", { Scale = 0.3, Parent = banner })
			Components.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		if style.Flash then
			doFlash(0.85)
			task.spawn(shakeStage, token, 12, 10)
		end
	end
	task.wait(if Components.reducedMotion then 0 else 0.35)
	if not alive(token) then
		return
	end
	busy = false
	setAction(if RevealPlan.isLast(current) then "SEE ALL CARDS" else "NEXT CARD", "Green")
end

local function nextRound()
	local current = plan
	if not current or busy or not RevealPlan.next(current) then
		return
	end
	if current.phase == "summary" then
		showSummary()
	else
		presentHidden()
	end
end

local function onAction()
	local current = plan
	if not current then
		return
	end
	if current.phase == "hidden" then
		revealRound(session)
	elseif current.phase == "revealed" then
		nextRound()
	end
end

-- True while the intro of this session is still running (not closed, not skipped).
local function introRunning(token: number): boolean
	local current = plan
	return alive(token) and current ~= nil and current.phase == "intro"
end

-- 1. Packs side by side: pop in, shake together, burst; then the card backs.
local function intro(token: number, pack: Types.PackDef, packs: number)
	local rarities = {}
	for _, card in currentCards do
		local def = CardRegistry.get(card.CardId)
		if def then
			table.insert(rarities, def.Rarity)
		end
	end
	local tier = RevealStyle.packTier(rarities)
	local art = CardArt.forPack(pack)
	local cardHeight = layout.cardWidth * 1.5
	local packViews: { Frame } = {}
	for _, column in columns do
		column.flipper.Visible = false
		local view = Create("Frame", {
			Name = "PackView",
			Size = UDim2.fromOffset(layout.cardWidth, cardHeight),
			Position = UDim2.fromOffset(layout.cardWidth / 2, cardHeight / 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 5,
			Parent = column.frame,
		})
		if art then
			Create("ImageLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = art,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 5,
				Parent = view,
			})
		else
			local badge = Components.badge(string.sub(pack.DisplayName, 1, 1), pack.Color, UDim2.fromScale(1, 1))
			badge.ZIndex = 5
			badge.Parent = view
		end
		local scale = Create("UIScale", { Scale = 0, Parent = view })
		Components.tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		table.insert(packViews, view)
	end
	setAction(nil)
	if not Components.reducedMotion then
		task.wait(0.45)
		local shakes = 4 + tier * 3
		for i = 1, shakes do
			if not introRunning(token) then
				return
			end
			local angle = (if i % 2 == 0 then 1 else -1) * (3 + tier * 2) * (i / shakes)
			for _, view in packViews do
				play(view, 0.06, { Rotation = angle })
			end
			task.wait(0.07)
		end
		if not introRunning(token) then
			return
		end
		doFlash(if tier >= 4 then 0.9 else 0.6)
		for p, view in packViews do
			play(view, 0.25, { Rotation = 0 })
			for _, child in view:GetDescendants() do
				if child:IsA("ImageLabel") then
					play(child, 0.25, { ImageTransparency = 1 })
				elseif child:IsA("Frame") then
					play(child, 0.25, { BackgroundTransparency = 1 })
				end
			end
			burst(columns[p].frame, pack.Color, MAX_SPARKS // packs)
		end
		task.wait(0.3)
	end
	if not introRunning(token) then
		return
	end
	for _, view in packViews do
		view:Destroy()
	end
	for _, column in columns do
		column.flipper.Visible = true
	end
	local current = plan
	if current and RevealPlan.start(current) then
		if current.phase == "summary" then
			showSummary()
		else
			presentHidden()
		end
	end
end

-- 3. Every card of the opening with its details, then CLAIM ALL.
showSummary = function()
	local current = plan
	if current then
		RevealPlan.finish(current)
	end
	busy = false
	clearStage()
	skipButton.Visible = false
	cardCatcher.Visible = false
	local count = #currentCards
	stageLabel(`{count} CARDS UNLOCKED!`, 0, 54, Theme.Colors.Gold)
	-- Framed panel behind the summary grid.
	Components.panel({
		Name = "SummaryPanel",
		Size = UDim2.new(1, -10, 1, -140),
		Position = UDim2.fromOffset(5, 60),
		Color = Theme.Colors.PanelDeep,
		Trim = Theme.Colors.Gold,
		Parent = stage,
	})
	local big = count <= 5
	local tileWidth = if big then 190 else 140
	local tileHeight = tileWidth * 1.5
	local lineHeights: { number } = if big then { 26, 20, 22, 18 } else { 20, 16, 18, 15 }
	local cellHeight = tileHeight + 8
	for _, height in lineHeights do
		cellHeight += height + 2
	end
	local grid = Create("ScrollingFrame", {
		Name = "Summary",
		Size = UDim2.new(1, -24, 1, -156),
		Position = UDim2.fromOffset(12, 68),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.Gold,
		ZIndex = 2,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = stage,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(tileWidth, cellHeight),
			CellPadding = UDim2.fromOffset(if big then 16 else 10, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, card in currentCards do
		local def = CardRegistry.get(card.CardId)
		if def then
			local rarity = Config.Rarities.ById[def.Rarity]
			local cell = Create("Frame", {
				Name = "Card" .. i,
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Parent = grid,
			})
			-- CardTile shows the +N% variant tag over the printed income.
			local tile = CardTile.new(def, { Variant = card.Variant, IsNew = card.IsNew, Income = card.Income })
			tile.Size = UDim2.fromOffset(tileWidth, tileHeight)
			tile.Parent = cell
			local variantLabel = RevealStyle.variantLabel(card.Variant, card.Income, def.BaseIncome)
			local variantDef = Config.Variants.ById[card.Variant]
			local lines: { { text: string, color: Color3? } } = {
				{ text = string.upper(def.Name), color = Theme.Colors.Text },
				{
					text = if rarity then rarity.DisplayName else def.Rarity,
					color = if rarity then rarity.Color else nil,
				},
				{ text = `+{Format.rate(card.Income)}/S`, color = Theme.Colors.Cash },
			}
			if variantLabel then
				table.insert(lines, { text = variantLabel, color = if variantDef then variantDef.Color else nil })
			end
			local y = tileHeight + 6
			for l, line in lines do
				Components.label({
					Text = line.text,
					Size = UDim2.new(1, 0, 0, lineHeights[l]),
					Position = UDim2.fromOffset(0, y),
					Color = line.color,
					Parent = cell,
				})
				y += lineHeights[l] + 2
			end
		end
	end
	setAction("CLAIM ALL", "Gold")
end

local function build()
	local screen: ScreenGui = Create("ScreenGui", {
		Name = "PackReveal",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		Enabled = false,
		IgnoreGuiInset = true,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local backdrop = Create("Frame", {
		Name = "Backdrop",
		Active = true, -- swallows clicks so the world/HUD behind can't be used
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.PanelDeep,
		BackgroundTransparency = 0.12,
		Parent = screen,
	}, {
		-- Lighter centre, darker edges: a forest clearing behind the cards.
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 120, 120)),
				ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 100, 100)),
			}),
		}),
	})
	-- A few faint paw prints and leaves around the edges (static decoration).
	Components.paw(backdrop, UDim2.fromScale(0.08, 0.84), 90, Theme.Colors.Gold, 0.9, -20)
	Components.paw(backdrop, UDim2.fromScale(0.93, 0.18), 70, Theme.Colors.Gold, 0.9, 25)
	Components.leaf(backdrop, UDim2.fromScale(0.05, 0.12), 120, -35, 0.75)
	Components.leaf(backdrop, UDim2.fromScale(0.96, 0.9), 120, 145, 0.75)
	local root = Create("Frame", {
		Name = "Root",
		Size = UDim2.fromOffset(ROOT_SIZE.X, ROOT_SIZE.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	-- Scales the whole scene to the screen (phones included).
	Components.autoScale(root)
	stage = Create("Frame", {
		Name = "Stage",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = root,
	})
	-- Clicking a face-down card reveals the round, like CLICK TO REVEAL.
	cardCatcher = Create("TextButton", {
		Name = "CardClick",
		Visible = false,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 470),
		Position = UDim2.fromOffset(0, 110),
		ZIndex = 2,
		Parent = root,
	})
	cardCatcher.Activated:Connect(function()
		local current = plan
		if current and current.phase == "hidden" then
			revealRound(session)
		end
	end)
	actionButton = Components.button({
		Text = "CLICK TO REVEAL",
		Style = "Gold",
		Size = UDim2.fromOffset(300, 64),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = root,
		OnClick = function()
			local current = plan
			if current and current.phase == "summary" then
				PackReveal.close()
			else
				onAction()
			end
		end,
	})
	actionButton.ZIndex = 10
	skipButton = Components.button({
		Text = "SKIP TO SUMMARY",
		Style = "Brown",
		Size = UDim2.fromOffset(220, 46),
		Position = UDim2.new(1, -8, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		Parent = root,
		OnClick = function()
			if plan and not busy then
				showSummary()
			end
		end,
	})
	skipButton.ZIndex = 10
	flash = Create("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = screen,
	})
	gui = screen
end

function PackReveal.isOpen(): boolean
	return gui ~= nil and (gui :: ScreenGui).Enabled
end

-- Plays the scene for an opening the server has already granted. `packs` packs were opened
-- together, `cardsPerPack` cards each; `cards` are in server order (pack by pack).
function PackReveal.play(
	pack: Types.PackDef,
	cards: { RevealCard },
	packs: number?,
	cardsPerPack: number?,
	closed: (() -> ())?
)
	if not gui then
		build()
	end
	local screen = gui :: ScreenGui
	session += 1
	local token = session
	onClosed = closed
	busy = false
	local packCount = math.max(1, packs or 1)
	local perPack = cardsPerPack or pack.CardsPerOpen
	currentCards = cards
	currentPack = pack
	plan = RevealPlan.new(cards, packCount, perPack)
	layout = layoutFor(packCount)
	clearStage()
	stage.Position = UDim2.fromScale(0.5, 0.5)
	skipButton.Visible = true
	screen.Enabled = true

	-- Start downloading this opening's card art now, while the packs animate.
	local ids = {}
	local back = CardArt.backFor(pack)
	if back then
		table.insert(ids, back)
	end
	for _, card in cards do
		local def = CardRegistry.get(card.CardId)
		local image = if def then frontImage(def) else nil
		if image then
			table.insert(ids, image)
		end
	end
	ImagePreloader.preload(ids, "pack opening")

	if not blur then
		local effect = Instance.new("BlurEffect")
		effect.Name = "PackRevealBlur"
		effect.Size = 0
		effect.Parent = Lighting
		blur = effect
		play(effect, 0.3, { Size = 18 })
	end

	roundLabel = stageLabel("", 0, 40, Theme.Colors.Muted)
	buildColumns(packCount)
	task.spawn(intro, token, pack, packCount)
end

-- Open All: many packs at once, so the scene skips the per-card rounds and shows the
-- summary of every card straight away (scrollable), then CLAIM ALL. Purely visual too.
function PackReveal.summary(cards: { RevealCard }, closed: (() -> ())?)
	if not gui then
		build()
	end
	local screen = gui :: ScreenGui
	session += 1
	onClosed = closed
	busy = false
	currentCards = cards
	-- A plan that goes straight to its summary phase, so CLAIM ALL closes the scene.
	plan = RevealPlan.new(cards, 1, math.max(1, #cards))
	layout = layoutFor(6)
	clearStage()
	stage.Position = UDim2.fromScale(0.5, 0.5)
	screen.Enabled = true
	local ids = {}
	for _, card in cards do
		local def = CardRegistry.get(card.CardId)
		local image = if def then frontImage(def) else nil
		if image and not table.find(ids, image) then
			table.insert(ids, image)
		end
	end
	ImagePreloader.preload(ids, "open all")
	if not blur then
		local effect = Instance.new("BlurEffect")
		effect.Name = "PackRevealBlur"
		effect.Size = 0
		effect.Parent = Lighting
		blur = effect
		play(effect, 0.3, { Size = 18 })
	end
	showSummary()
end

-- Closes the scene (CLAIM ALL). Safe to call any time; the cards were granted already.
function PackReveal.close()
	session += 1
	busy = false
	plan = nil
	currentCards = {}
	if gui then
		(gui :: ScreenGui).Enabled = false
		cardCatcher.Visible = false
		clearStage()
	end
	if blur then
		blur:Destroy()
		blur = nil
	end
	local callback = onClosed
	onClosed = nil
	if callback then
		callback()
	end
end

return PackReveal
