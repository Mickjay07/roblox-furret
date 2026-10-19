--!strict
-- Visual tuning for the 3D world: palette, stand illustrations and rarity effects (spec §2,
-- §9). Effects are deliberately light: a few particles at most, only near the camera.

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

export type RarityEffect = {
	-- Sparkle particles around the illustration (0 = none).
	ParticleRate: number,
	ParticleColor: Color3?,
	-- Soft point light ("glow"/"aura"); Brightness 0 = none.
	LightBrightness: number,
	LightColor: Color3?,
	LightRange: number,
	-- Extra float amplitude multiplier for very rare cards.
	FloatBoost: number,
}

local function effect(
	rate: number,
	particle: Color3?,
	brightness: number,
	light: Color3?,
	range: number,
	boost: number
): RarityEffect
	return table.freeze({
		ParticleRate = rate,
		ParticleColor = particle,
		LightBrightness = brightness,
		LightColor = light,
		LightRange = range,
		FloatBoost = boost,
	})
end

return table.freeze({
	World = table.freeze({
		Grass = rgb(120, 200, 96),
		GrassDark = rgb(96, 176, 80),
		Path = rgb(244, 214, 160),
		PathEdge = rgb(214, 176, 120),
		Plaza = rgb(252, 232, 196),
		PlazaRing = rgb(255, 196, 120),
		Water = rgb(110, 196, 255),
		PlotFloor = rgb(196, 236, 160),
		PlotBorder = rgb(255, 255, 255),
		PlotFree = rgb(200, 200, 210),
		Wood = rgb(176, 120, 76),
		Roof = rgb(255, 120, 120),
		Pedestal = rgb(255, 250, 240),
		PedestalLocked = rgb(120, 124, 140),
		SignBackground = rgb(40, 36, 58),
		SignText = rgb(255, 255, 255),
		Trunk = rgb(150, 100, 60),
		Leaves = rgb(84, 180, 90),
		LampGlow = rgb(255, 230, 160),
	}),

	Illustration = table.freeze({
		-- Width of the floating card illustration in studs (height follows the art aspect).
		WidthStuds = 4.2,
		-- Height of the illustration centre above the stand top.
		HeightOffset = 4.6,
		FloatAmplitude = 0.3,
		FloatSpeed = 1.6,
		-- Illustrations and labels are not drawn beyond this distance.
		MaxDistance = 160,
		-- Particles and lights only run within this distance of the camera.
		EffectDistance = 70,
	}),

	-- Spec §9: Common gentle idle, Rare subtle blue particles, Epic soft purple glow,
	-- Legendary golden sparkles, Mythic distinctive aura, Secret unique but cheap.
	RarityEffects = table.freeze({
		Common = effect(0, nil, 0, nil, 0, 1),
		Uncommon = effect(0, nil, 0, nil, 0, 1),
		Rare = effect(2, rgb(90, 170, 255), 0, nil, 0, 1),
		Epic = effect(0, nil, 1.2, rgb(190, 110, 255), 10, 1),
		Legendary = effect(4, rgb(255, 210, 70), 1, rgb(255, 205, 90), 10, 1.15),
		Mythic = effect(5, rgb(255, 110, 170), 1.6, rgb(255, 90, 160), 12, 1.3),
		Secret = effect(3, rgb(200, 255, 255), 2, rgb(120, 255, 230), 14, 1.4),
	} :: { [string]: RarityEffect }),
})
