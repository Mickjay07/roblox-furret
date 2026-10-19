--!strict
-- Pack opening sequence (spec §7.5, roadmap A7). Purely visual: the server has already
-- consumed the pack and added the cards before this plays, so closing it, skipping it or
-- disconnecting never loses or duplicates a reward.
--
--   1. The pack appears in the centre over a blurred, dimmed world and shakes (harder when
--      a rarer card is inside), then bursts open with a flash.
--   2. The five cards are revealed one by one: card back, flip, then rarity effects
--      (Logic/RevealStyle: glow, sparkles, rotating rays, flash and banner for the rarest)
--      with the card's name, rarity, income and variant bonus ("SHINY +2%").
--   3. A summary of all five cards with a CONTINUE button.
--
-- Tap anywhere to advance; SKIP jumps to the summary. With Reduced Motion on, the summary
-- shows straight away. Each play() starts a new session; anything still running from an
-- older session checks the session number and stops, so closing mid-animation is safe.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local CardArt = require(Shared.Logic.CardArt)
local CardRegistry = require(Shared.Logic.CardRegistry)
local RevealStyle = require(Shared.Logic.RevealStyle)
local Format = require(Shared.Util.Format)

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
}

local PackReveal = {}

local CARD_SIZE = Vector2.new(280, 420)

local gui: ScreenGui? = nil
local root: Frame
local stage: Frame
local flash: Frame
local hint: TextLabel
local skipButton: TextButton
local blur: BlurEffect? = nil
local session = 0
local advanceRequested = false
local skipRequested = false
local onClosed: (() -> ())? = nil

local function alive(token: number): boolean
	return token == session
end

-- Waits up to `seconds`; returns early when the player taps. False if the session ended.
local function hold(token: number, seconds: number, tapToAdvance: boolean): boolean
	advanceRequested = false
	local elapsed = 0
	while elapsed < seconds do
		if not alive(token) or skipRequested then
			return false
		end
		if tapToAdvance and advanceRequested then
			break
		end
		elapsed += task.wait(0.03)
	end
	return alive(token) and not skipRequested
end

local function play(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), goal):Play()
end

local function clearStage()
	for _, child in stage:GetChildren() do
		child:Destroy()
	end
end

local function doFlash(strength: number)
	flash.BackgroundTransparency = 1 - strength
	play(flash, 0.45, { BackgroundTransparency = 1 })
end

local function shakeStage(token: number, intensity: number, times: number)
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

local function burst(parent: Instance, color: Color3, count: number)
	for _ = 1, count do
		local size = math.random(10, 22)
		local spark = Create("Frame", {
			Name = "Spark",
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromScale(0.5, 0.45),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = math.random(0, 90),
			BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), math.random() * 0.5),
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = parent,
		}, { Components.corner(UDim.new(0.25, 0)) })
		local angle = math.random() * math.pi * 2
		local distance = math.random(180, 380)
		play(spark, 0.9, {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.45, math.sin(angle) * distance),
			BackgroundTransparency = 1,
			Rotation = spark.Rotation + math.random(90, 360),
		}, Enum.EasingStyle.Quart)
		task.delay(1, function()
			spark:Destroy()
		end)
	end
end

local function rays(parent: Instance, color: Color3): Frame
	local holder = Create("Frame", {
		Name = "Rays",
		Size = UDim2.fromOffset(900, 900),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = parent,
	})
	for i = 0, 7 do
		Create("Frame", {
			Size = UDim2.new(0, 46, 1, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = i * 22.5,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.78,
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
	-- Endless slow spin; destroying the frame stops the tween.
	TweenService
		:Create(holder, TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
		:Play()
	return holder
end

-- The card face shown after the flip: the uploaded art stretched to the card frame (so
-- the flip squash reads correctly), or the standard placeholder tile.
local function cardFace(def: Types.CardDef, card: RevealCard): GuiObject
	local art = CardArt.forCard(def)
	if art and Config.Assets.FullCardArt then
		return Create("ImageLabel", {
			Name = "Face",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = art,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = 4,
		})
	end
	local tile = CardTile.new(def, { Variant = card.Variant, IsNew = card.IsNew, Income = card.Income })
	tile.Size = UDim2.fromScale(1, 1)
	tile.ZIndex = 4
	return tile
end

local function cardBack(pack: Types.PackDef): Frame
	local back = Create("Frame", {
		Name = "Back",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = pack.Color,
		ZIndex = 4,
	}, {
		Components.corner(UDim.new(0, 18)),
		Components.stroke(Color3.new(1, 1, 1), 5),
		Create("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 120)),
		}),
	})
	local mark = Components.label({ Text = "?", Size = UDim2.fromScale(0.5, 0.4), Parent = back })
	mark.Position = UDim2.fromScale(0.5, 0.5)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.ZIndex = 5
	return back
end

local function infoText(parent: Instance, text: string, y: number, height: number, color: Color3?): TextLabel
	local label = Components.label({
		Text = text,
		Size = UDim2.new(0, 520, 0, height),
		Position = UDim2.new(0.5, 0, 0, y),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = color,
		StrokeThickness = 3,
		Parent = parent,
	})
	label.ZIndex = 6
	label.TextTransparency = 1
	play(label, 0.3, { TextTransparency = 0 })
	return label
end

-- 1. The pack in the centre: pop in, shake (more for rarer contents), burst open.
local function introPack(token: number, pack: Types.PackDef, cards: { RevealCard }): boolean
	local rarities = {}
	for _, card in cards do
		local def = CardRegistry.get(card.CardId)
		if def then
			table.insert(rarities, def.Rarity)
		end
	end
	local tier = RevealStyle.packTier(rarities)

	local holder = Create("Frame", {
		Name = "Pack",
		Size = UDim2.fromOffset(300, 450),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = stage,
	})
	local scale = Create("UIScale", { Scale = 0, Parent = holder })
	local art = CardArt.forPack(pack)
	if art then
		Create("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = art,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
			Parent = holder,
		})
	else
		local badge = Components.badge(string.sub(pack.DisplayName, 1, 1), pack.Color, UDim2.fromScale(1, 1))
		badge.ZIndex = 3
		badge.Parent = holder
	end
	local title = infoText(stage, string.upper(pack.DisplayName), 540, 46)

	play(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	if not hold(token, 0.5, false) then
		return false
	end
	-- Anticipation: the rarer the best card inside, the longer and harder the shake.
	local shakes = 4 + tier * 3
	for i = 1, shakes do
		if not alive(token) or skipRequested then
			return false
		end
		local angle = (if i % 2 == 0 then 1 else -1) * (3 + tier * 2) * (i / shakes)
		play(holder, 0.06, { Rotation = angle })
		task.wait(0.07)
	end
	holder.Rotation = 0
	doFlash(if tier >= 4 then 0.9 else 0.6)
	play(scale, 0.25, { Scale = 1.6 })
	for _, child in holder:GetDescendants() do
		if child:IsA("ImageLabel") then
			play(child, 0.25, { ImageTransparency = 1 })
		elseif child:IsA("Frame") then
			play(child, 0.25, { BackgroundTransparency = 1 })
		end
	end
	burst(stage, pack.Color, 16)
	if not hold(token, 0.3, false) then
		return false
	end
	holder:Destroy()
	title:Destroy()
	return true
end

-- 2. One card: back, flip, rarity effects and details.
local function revealCard(token: number, pack: Types.PackDef, card: RevealCard, index: number, total: number): boolean
	local def = CardRegistry.get(card.CardId)
	if not def then
		return true
	end
	clearStage()
	local rarity = Config.Rarities.ById[def.Rarity]
	local color = if rarity then rarity.Color else Theme.Colors.Muted
	local style = RevealStyle.forRarity(def.Rarity)

	local counter = infoText(stage, `CARD {index} / {total}`, 0, 34, Theme.Colors.Muted)
	counter.TextTransparency = 0

	local flipper = Create("Frame", {
		Name = "Flipper",
		Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = stage,
	})
	local pop = Create("UIScale", { Scale = 0.2, Parent = flipper })
	local back = cardBack(pack)
	back.Parent = flipper
	play(pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	if not hold(token, 0.45 + (style.Tier - 1) * 0.15, false) then
		return false
	end

	-- Flip: squash the back to nothing, swap faces, unsquash the front.
	play(flipper, 0.14, { Size = UDim2.fromOffset(0, CARD_SIZE.Y) }, Enum.EasingStyle.Quad)
	task.wait(0.15)
	if not alive(token) then
		return false
	end
	back:Destroy()
	cardFace(def, card).Parent = flipper
	play(flipper, 0.18, { Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y) }, Enum.EasingStyle.Back)

	-- Rarity effects, bigger for rarer cards.
	if style.Glow then
		local glow = Create("Frame", {
			Name = "Glow",
			Size = UDim2.fromOffset(CARD_SIZE.X + 40, CARD_SIZE.Y + 40),
			Position = UDim2.fromScale(0.5, 0.45),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = stage,
		}, { Components.corner(UDim.new(0, 30)) })
		play(glow, 0.3, { BackgroundTransparency = 0.55 - style.Tier * 0.08 })
	end
	if style.Rays then
		rays(stage, color)
	end
	if style.Burst > 0 then
		burst(stage, color, style.Burst)
	end
	if style.Flash then
		doFlash(0.85)
		task.spawn(shakeStage, token, 12, 10)
	end
	play(pop, 0.12, { Scale = 1.08 })
	task.delay(0.12, function()
		if alive(token) then
			play(pop, 0.2, { Scale = 1 })
		end
	end)

	-- Details: name, rarity, income (server-computed) and variant bonus.
	if style.Banner then
		local banner = infoText(stage, style.Banner, 44, 54, color)
		local bannerScale = Create("UIScale", { Scale = 0.3, Parent = banner })
		play(bannerScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	infoText(stage, string.upper(def.Name), 562, 44)
	infoText(stage, if rarity then rarity.DisplayName else def.Rarity, 606, 30, color)
	local extra = {}
	local variantLabel = RevealStyle.variantLabel(card.Variant, card.Income, def.BaseIncome)
	if variantLabel then
		table.insert(extra, variantLabel)
	end
	if card.IsNew then
		table.insert(extra, "NEW!")
	end
	table.insert(extra, `1 IN {Format.commas(card.OneIn)}`)
	infoText(stage, `+{Format.rate(card.Income)}/S`, 640, 34, Theme.Colors.Cash)
	local variantDef = Config.Variants.ById[card.Variant]
	infoText(
		stage,
		table.concat(extra, "   "),
		678,
		28,
		if variantLabel and variantDef then variantDef.Color else Theme.Colors.Muted
	)

	hint.Visible = true
	local continued = hold(token, style.Hold, true)
	hint.Visible = false
	return continued
end

-- 3. All five cards with their details and CONTINUE.
local function showSummary(cards: { RevealCard })
	clearStage()
	skipButton.Visible = false
	hint.Visible = false
	local title = infoText(stage, "PACK OPENED!", 0, 56)
	title.TextTransparency = 0
	local row = Create("Frame", {
		Name = "Summary",
		Size = UDim2.new(1, 0, 0, 470),
		Position = UDim2.fromOffset(0, 80),
		BackgroundTransparency = 1,
		Parent = stage,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 16),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, card in cards do
		local def = CardRegistry.get(card.CardId)
		if def then
			local rarity = Config.Rarities.ById[def.Rarity]
			local cell = Create("Frame", {
				Name = "Card" .. i,
				Size = UDim2.fromOffset(196, 470),
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Parent = row,
			})
			local tile = CardTile.new(def, { Variant = card.Variant, IsNew = card.IsNew, Income = card.Income })
			tile.Size = UDim2.fromOffset(196, 294)
			tile.Parent = cell
			type Line = { text: string, color: Color3?, height: number }
			local lines: { Line } = {
				{ text = string.upper(def.Name), color = Theme.Colors.Text, height = 30 },
				{
					text = if rarity then rarity.DisplayName else def.Rarity,
					color = if rarity then rarity.Color else nil,
					height = 24,
				},
				{ text = `+{Format.rate(card.Income)}/S`, color = Theme.Colors.Cash, height = 26 },
			}
			local variantLabel = RevealStyle.variantLabel(card.Variant, card.Income, def.BaseIncome)
			local variantDef = Config.Variants.ById[card.Variant]
			if variantLabel then
				table.insert(lines, {
					text = variantLabel,
					color = if variantDef then variantDef.Color else nil,
					height = 22,
				})
			end
			local y = 302
			for _, line in lines do
				Components.label({
					Text = line.text,
					Size = UDim2.new(1, 0, 0, line.height),
					Position = UDim2.fromOffset(0, y),
					Color = line.color,
					Parent = cell,
				})
				y += line.height + 6
			end
			local scale = Create("UIScale", { Scale = 0, Parent = cell })
			task.delay(if Components.reducedMotion then 0 else (i - 1) * 0.08, function()
				Components.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
	end
	Components.button({
		Text = "CONTINUE",
		Style = "Green",
		Size = UDim2.fromOffset(260, 64),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = stage,
		OnClick = function()
			PackReveal.close()
		end,
	})
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
	-- Full-screen tap catcher: advances to the next card.
	local backdrop: TextButton = Create("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 8, 14),
		BackgroundTransparency = 0.25,
		Parent = screen,
	})
	backdrop.Activated:Connect(function()
		advanceRequested = true
	end)
	root = Create("Frame", {
		Name = "Root",
		Size = UDim2.fromOffset(1100, 760),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Components.autoScale(root)
	stage = Create("Frame", {
		Name = "Stage",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = root,
	})
	hint = Components.label({
		Text = "TAP TO CONTINUE",
		Size = UDim2.new(0, 360, 0, 30),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = Theme.Colors.Muted,
		Parent = root,
	})
	hint.Visible = false
	skipButton = Components.button({
		Text = "SKIP",
		Style = "Gray",
		Size = UDim2.fromOffset(130, 50),
		Position = UDim2.new(1, -8, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		Parent = root,
		OnClick = function()
			skipRequested = true
		end,
	})
	flash = Create("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Active = false,
		Parent = screen,
	})
	gui = screen
end

function PackReveal.isOpen(): boolean
	return gui ~= nil and (gui :: ScreenGui).Enabled
end

-- Plays the sequence for an opening the server has already granted.
function PackReveal.play(pack: Types.PackDef, cards: { RevealCard }, closed: (() -> ())?)
	if not gui then
		build()
	end
	local screen = gui :: ScreenGui
	session += 1
	local token = session
	onClosed = closed
	advanceRequested, skipRequested = false, false
	clearStage()
	stage.Position = UDim2.fromScale(0.5, 0.5)
	skipButton.Visible = true
	screen.Enabled = true

	if not blur then
		local effect = Instance.new("BlurEffect")
		effect.Name = "PackRevealBlur"
		effect.Size = 0
		effect.Parent = Lighting
		blur = effect
		play(effect, 0.3, { Size = 18 })
	end

	if Components.reducedMotion then
		showSummary(cards)
		return
	end
	task.spawn(function()
		local completed = introPack(token, pack, cards)
		if completed then
			for index, card in cards do
				if not revealCard(token, pack, card, index, #cards) then
					break
				end
			end
		end
		-- Finished, skipped or tapped through: the summary, unless the player closed it.
		if alive(token) then
			showSummary(cards)
		end
	end)
end

-- Closes the sequence (CONTINUE, or the player leaving the screen). Safe to call any time.
function PackReveal.close()
	session += 1
	if gui then
		(gui :: ScreenGui).Enabled = false
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
