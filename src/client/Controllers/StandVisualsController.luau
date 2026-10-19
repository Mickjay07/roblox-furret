--!strict
-- Floating 2D ferret illustrations above occupied display stands (spec §9: "one of the most
-- important features"). Built locally on every client from the stand attributes the server
-- maintains (CardId, Variant, CardIncome), for every plot, so visitors see other players'
-- ferrets too.
--
--   * Artwork comes only from Logic/CardArt (the shared Config.Assets mapping). Until an
--     image has a Roblox asset id, a placeholder card (rarity colour, name, income) is shown.
--   * The aspect ratio of the art is preserved; the illustration always faces the camera.
--   * One RenderStepped loop floats every illustration (no per-card loops); disabled when the
--     player turns on Reduced Motion.
--   * The art prints the card's base (Normal) income. When a variant or grade changes it, an
--     income tag shows CardIncome, which the server computes with the central formula.
--   * Rarity effects follow Config.Visuals.RarityEffects and only run near the camera.
--   * Everything created here is destroyed when a stand is cleared or its plot released.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CardArt = require(Shared.Logic.CardArt)
local CardRegistry = require(Shared.Logic.CardRegistry)
local Format = require(Shared.Util.Format)

local ArtDiagnostics = require(script.Parent.Parent.Lib.ArtDiagnostics)
local UI = script.Parent.Parent.UI
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)

local StandVisualsController = {}

local Settings = Config.Visuals.Illustration

type Visual = {
	stand: Model,
	anchor: BasePart,
	key: string?,
	gui: BillboardGui?,
	effects: { Instance },
	phase: number,
	boost: number,
	connections: { RBXScriptConnection },
}

local visuals: { [Model]: Visual } = {}

local function clear(visual: Visual)
	if visual.gui then
		visual.gui:Destroy()
		visual.gui = nil
	end
	for _, effect in visual.effects do
		effect:Destroy()
	end
	table.clear(visual.effects)
	visual.key = nil
end

-- Placeholder shown until the card's artwork has a Roblox asset id.
local function placeholder(parent: Instance, def: any, income: number)
	local rarity = Config.Rarities.ById[def.Rarity]
	local color = if rarity then rarity.Color else Theme.Colors.Muted
	local frame = Create("Frame", {
		Name = "Placeholder",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		Parent = parent,
	}, {
		Components.corner(UDim.new(0.08, 0)),
		Create("UIStroke", { Color = Color3.fromRGB(20, 20, 26), Thickness = 3 }),
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)),
		}),
	})
	Components.label({
		Text = string.upper(def.Name),
		Size = UDim2.fromScale(0.9, 0.16),
		Position = UDim2.fromScale(0.05, 0.36),
		Parent = frame,
	})
	Components.label({
		Text = if rarity then rarity.DisplayName else def.Rarity,
		Size = UDim2.fromScale(0.8, 0.1),
		Position = UDim2.fromScale(0.1, 0.54),
		Parent = frame,
	})
	Components.label({
		Text = `+{Format.short(income)}/S`,
		Size = UDim2.fromScale(0.8, 0.11),
		Position = UDim2.fromScale(0.1, 0.7),
		Color = Theme.Colors.Cash,
		Parent = frame,
	})
end

local function addEffects(visual: Visual, rarityId: string)
	local effect = Config.Visuals.RarityEffects[rarityId]
	if not effect then
		return
	end
	visual.boost = effect.FloatBoost
	if effect.ParticleRate > 0 then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "RaritySparkles"
		emitter.Rate = effect.ParticleRate
		emitter.Color = ColorSequence.new(effect.ParticleColor or Color3.new(1, 1, 1))
		emitter.LightEmission = 0.7
		emitter.Lifetime = NumberRange.new(1, 1.6)
		emitter.Speed = NumberRange.new(0.4, 0.9)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.25),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Enabled = false
		emitter.Parent = visual.anchor
		table.insert(visual.effects, emitter)
	end
	if effect.LightBrightness > 0 then
		local light = Instance.new("PointLight")
		light.Name = "RarityGlow"
		light.Brightness = effect.LightBrightness
		light.Range = effect.LightRange
		light.Color = effect.LightColor or Color3.new(1, 1, 1)
		light.Enabled = false
		light.Parent = visual.anchor
		table.insert(visual.effects, light)
	end
end

local function render(visual: Visual)
	local stand = visual.stand
	local cardId = stand:GetAttribute("CardId")
	local variant = stand:GetAttribute("Variant")
	local income = stand:GetAttribute("CardIncome")
	local key = if type(cardId) == "string" then `{cardId}:{tostring(variant)}:{tostring(income)}` else nil
	if key == visual.key then
		return
	end
	clear(visual)
	if key == nil or type(cardId) ~= "string" then
		return
	end
	local def = CardRegistry.get(cardId)
	if not def then
		return
	end
	visual.key = key
	-- Display only: the value comes from the server (Economy.cardIncome), never recomputed here.
	local cardIncome: number = if type(income) == "number" then income else def.BaseIncome

	local width = Settings.WidthStuds
	local height = width / CardArt.aspect(def.Artwork)
	local gui: BillboardGui = Create("BillboardGui", {
		Name = "Illustration",
		Adornee = visual.anchor,
		Size = UDim2.new(width, 0, height, 0),
		StudsOffset = Vector3.new(0, Settings.HeightOffset, 0),
		LightInfluence = 0,
		MaxDistance = Settings.MaxDistance,
		AlwaysOnTop = false,
		ClipsDescendants = false,
	})
	local art = CardArt.forCard(def)
	if art then
		Create("ImageLabel", {
			Name = "Art",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = art,
			ScaleType = Enum.ScaleType.Fit,
			Parent = gui,
		})
		ArtDiagnostics.watch("Stand", def.Artwork, art)
	else
		ArtDiagnostics.fallback("Stand", def.Artwork)
		placeholder(gui, def, cardIncome)
	end
	local variantDef = if type(variant) == "string" then Config.Variants.ById[variant] else nil
	if variantDef and variantDef.Id ~= Config.Variants.Default then
		local tag = Create("Frame", {
			Name = "Variant",
			Size = UDim2.fromScale(0.6, 0.1),
			Position = UDim2.fromScale(0.5, -0.06),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = variantDef.Color,
			Parent = gui,
		}, { Components.corner(UDim.new(0.3, 0)) })
		Components.label({
			Text = variantDef.DisplayName,
			Size = UDim2.fromScale(0.9, 0.85),
			Position = UDim2.fromScale(0.05, 0.075),
			Parent = tag,
		})
	end
	-- The printed art shows the base income; tag the real income when it differs.
	if art and math.abs(cardIncome - def.BaseIncome) > 1e-6 then
		local incomeTag = Create("Frame", {
			Name = "Income",
			Size = UDim2.fromScale(0.7, 0.1),
			Position = UDim2.fromScale(0.5, 0.7),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Theme.Colors.Cash:Lerp(Color3.new(0, 0, 0), 0.35),
			Parent = gui,
		}, { Components.corner(UDim.new(0.3, 0)) })
		Components.label({
			Text = `+{Format.short(cardIncome)}/S`,
			Size = UDim2.fromScale(0.9, 0.85),
			Position = UDim2.fromScale(0.05, 0.075),
			Parent = incomeTag,
		})
	end
	gui.Parent = visual.anchor
	visual.gui = gui
	addEffects(visual, def.Rarity)
end

local function track(stand: Model)
	if visuals[stand] then
		return
	end
	local anchor = stand:WaitForChild("Anchor", 5)
	if not anchor or not anchor:IsA("BasePart") then
		return
	end
	local visual: Visual = {
		stand = stand,
		anchor = anchor,
		key = nil,
		gui = nil,
		effects = {},
		phase = math.random() * math.pi * 2,
		boost = 1,
		connections = {},
	}
	visuals[stand] = visual
	for _, attribute in { "CardId", "Variant", "CardIncome" } do
		table.insert(
			visual.connections,
			stand:GetAttributeChangedSignal(attribute):Connect(function()
				render(visual)
			end)
		)
	end
	table.insert(
		visual.connections,
		stand.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				clear(visual)
				for _, connection in visual.connections do
					connection:Disconnect()
				end
				visuals[stand] = nil
			end
		end)
	)
	render(visual)
end

local function isStand(instance: Instance): boolean
	return instance:IsA("Model") and instance:GetAttribute("Slot") ~= nil
end

-- Read access for other client controllers (stand prompts, earnings labels).
function StandVisualsController:IllustrationHeight(stand: Model): number
	local visual = visuals[stand]
	if visual and visual.gui then
		return Settings.HeightOffset + visual.gui.Size.Y.Scale / 2
	end
	return 2
end

function StandVisualsController:Start()
	-- Studio Output: how every artwork key resolves (key, AssetId, final content id).
	ArtDiagnostics.report()
	local plots = workspace:WaitForChild("Plots")
	for _, descendant in plots:GetDescendants() do
		if isStand(descendant) then
			task.spawn(track, descendant :: Model)
		end
	end
	plots.DescendantAdded:Connect(function(descendant)
		if isStand(descendant) then
			task.spawn(track, descendant :: Model)
		end
	end)

	-- One loop floats every illustration.
	RunService.RenderStepped:Connect(function()
		if Components.reducedMotion then
			return
		end
		local t = os.clock() * Settings.FloatSpeed
		for _, visual in visuals do
			local gui = visual.gui
			if gui then
				gui.StudsOffset = Vector3.new(
					0,
					Settings.HeightOffset + math.sin(t + visual.phase) * Settings.FloatAmplitude * visual.boost,
					0
				)
			end
		end
	end)

	-- Effects only near the camera (cheap twice-a-second check).
	task.spawn(function()
		while true do
			local camera = workspace.CurrentCamera
			if camera then
				local position = camera.CFrame.Position
				for _, visual in visuals do
					local near = (visual.anchor.Position - position).Magnitude <= Settings.EffectDistance
						and not Components.reducedMotion
					for _, effect in visual.effects do
						-- effects only ever holds ParticleEmitters and PointLights.
						(effect :: any).Enabled = near
					end
				end
			end
			task.wait(0.5)
		end
	end)
end

return StandVisualsController
