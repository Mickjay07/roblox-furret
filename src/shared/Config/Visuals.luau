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
		-- Display stands (Ferret Frenzy style): wooden body, gold rim, forest-green felt top for
		-- an unlocked stand, grey stone for a locked one, gold glow ring when a card is shown.
		Pedestal = rgb(52, 120, 70),
		PedestalLocked = rgb(112, 118, 110),
		PedestalBase = rgb(128, 84, 46),
		PedestalRim = rgb(236, 186, 74),
		PedestalGlow = rgb(255, 222, 130),
		StandPlate = rgb(22, 58, 36),
		StandPlateText = rgb(255, 214, 110),
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
	-- HUD artwork layout (Config.Assets "ui.*" images).
	Hud = table.freeze({
		-- Currency bar (ui.currency_bar): the money value is a separate TextLabel drawn over
		-- the bar's empty green area. Aspect = image width / height, and the text box is
		-- given as fractions of the bar (inset from each edge). These are starting values:
		-- check them in Studio against the real image and adjust here if the text isn't
		-- centred on the green area (docs/TESTING.md §1.17).
		CurrencyBar = table.freeze({
			Aspect = 4,
			Width = 360, -- px at UI scale 1 (the whole HUD scales with the screen)
			TextInsetLeft = 0.3,
			TextInsetRight = 0.07,
			TextInsetTop = 0.22,
			TextInsetBottom = 0.22,
			MaxTextSize = 44,
			MinTextSize = 10,
			-- Used only when the art can't be measured (no crop): shifts the bar art (and the
			-- money text, which is its child) left by this fraction of the bar width. From the
			-- Studio screenshot: the visible art started ~13% into its 4:1 box, leaving a gap
			-- before it; -0.12 keeps a hair of margin.
			FallbackOffsetX = -0.12,
		}),
		-- Level bar art (ui.level_bar): the progress fill is a separate Frame drawn inside
		-- the art at these insets (fractions of the art box), so it can grow with XP.
		-- Starting values: check in Studio and adjust here if the fill doesn't sit inside the
		-- bar's empty track (docs/TESTING.md).
		LevelBar = table.freeze({
			Width = 260,
			Aspect = 5, -- art width / height
			FillInsetLeft = 0.08,
			FillInsetRight = 0.06,
			FillInsetTop = 0.32,
			FillInsetBottom = 0.32,
			-- false: the fill is drawn behind the art (for art with a transparent track).
			FillAboveArt = true,
		}),
		-- Collect button art (ui.collect_button): the amount is a separate label beside it.
		CollectButton = table.freeze({
			ArtWidth = 132,
			Height = 60,
			LabelWidth = 190,
		}),
		-- Gap between the left screen edge (inside the device safe area) and the stats panel.
		LeftMargin = 10,
		-- Right rail icons (ui.icon.*): square hit areas; the art is drawn with ScaleType.Fit
		-- and cropped to its visible pixels when they can be measured (Lib/ImageBounds), so
		-- transparent margins don't make one icon look smaller than another.
		IconSize = 84,
		-- Manual multiplier on top of everything, e.g. ["ui.icon.binder"] = 0.95.
		IconScale = table.freeze({} :: { [string]: number }),
		-- Used only when the art can't be measured (no crop). From the Studio screenshot of
		-- 2026-10-19: the backpack's visible art was ~76 px tall against ~105-116 px for the
		-- binder, upgrades and settings icons in equal slots, i.e. its image carries larger
		-- transparent margins; x1.4 brings it to the same visible size.
		IconScaleFallback = table.freeze({ ["ui.icon.backpack"] = 1.4 } :: { [string]: number }),
		ShowCaptions = true,
		-- Optional measured pixel data per image (Width, Height, MinX, MinY, MaxX, MaxY and for
		-- the currency bar Green = { Left, Right, Top, Bottom }). Studio prints these lines as
		-- "[Art] measured ..."; pasting one here skips the runtime measurement.
		ImageBounds = table.freeze({} :: { [string]: any }),
	}),

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
