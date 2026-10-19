--!strict
-- Currencies, starting resources, income and progression tuning.

return table.freeze({
	Currencies = table.freeze({
		Cash = table.freeze({ DisplayName = "Cash", Color = Color3.fromRGB(120, 230, 90) }),
		Treats = table.freeze({ DisplayName = "Treats", Color = Color3.fromRGB(240, 170, 80) }),
	}),

	-- Spec §32: starting cash $500.
	StartingCurrency = table.freeze({
		Cash = 500,
		Treats = 0,
	} :: { [string]: number }),

	-- Spec §3.3: starter currency and starter card packs, granted exactly once (guarded by
	-- Flags.StarterGranted). Packs go to the pack inventory; the player opens them.
	-- The count is an interim value (the spec does not give one).
	StarterPacks = table.freeze({ pack1 = 3 } :: { [string]: number }),

	IncomeTickSeconds = 1,

	-- Spec §10: each display stand accumulates earnings that the player collects, per stand
	-- or all at once (owner decision Q3). Offline earnings accrue onto the stands too.
	Income = table.freeze({
		-- A stand stops accumulating once it holds this many seconds of its current income.
		StandCapSeconds = 2 * 60 * 60,
		-- Offline time counted on rejoin is capped here (spec: "capped to prevent inflation").
		OfflineCapSeconds = 2 * 60 * 60,
		-- Share of normal income earned while offline (1 = full rate).
		OfflineRate = 1,
	}),

	-- Multiplier on a card's BaseSaleValue when sold (before variant/grade/upgrade bonuses).
	SaleMultiplier = 1,

	-- Level curve: XP needed to go from level L to L + 1 = floor(XpBase * L ^ XpExponent).
	Progression = table.freeze({
		XpBase = 60,
		XpExponent = 1.6,
		MaxLevel = 100,
		TreatsPerLevel = 5,
	}),
})
