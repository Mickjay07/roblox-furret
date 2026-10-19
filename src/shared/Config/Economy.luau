--!strict
-- Currencies, starting resources, income and progression tuning.

return table.freeze({
	Currencies = table.freeze({
		Cash = table.freeze({ DisplayName = "Cash", Color = Color3.fromRGB(120, 230, 90) }),
		Treats = table.freeze({ DisplayName = "Treats", Color = Color3.fromRGB(240, 170, 80) }),
	}),

	StartingCurrency = table.freeze({
		Cash = 1500,
		Treats = 0,
	} :: { [string]: number }),

	-- Granted exactly once per player (guarded by Flags.StarterGranted in saved data).
	StarterCards = table.freeze({ "burrow_sable_scout", "burrow_sock_bandit" }),

	IncomeTickSeconds = 1,

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
