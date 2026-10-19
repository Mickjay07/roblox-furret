--!strict
-- Monetization. An Id of 0 means "not created on the Roblox website yet": the item is hidden
-- and never offered.
--
-- MultiOpen entries are GAME PASSES (permanent; not Developer Products, no ProcessReceipt).
-- Roblox is the source of truth for ownership: MonetizationService asks
-- UserOwnsGamePassAsync on join and after a purchase, and mirrors the answer into
-- Purchases.Entitlements (a cache that a failed query never clears). Prices are set on the
-- Roblox website, never in code: GetProductInfo(Enum.InfoType.GamePass) is read at server
-- start; ExpectedPriceRobux (3x only, owner design) is compared and a mismatch logged.

return table.freeze({
	GamePasses = table.freeze({
		VIP = table.freeze({
			Id = 0,
			DisplayName = "VIP",
			Description = "+25% income, gold name tag.",
			IncomeMultiplier = 1.25,
		}),
		DoubleIncome = table.freeze({
			Id = 0,
			DisplayName = "2x Income",
			Description = "Doubles income from display stands.",
			IncomeMultiplier = 2,
		}),
	}),

	-- Multi Opening game passes (owner design): 3x first, then 6x (requires 3x).
	MultiOpen = table.freeze({
		MultiOpen3 = table.freeze({
			Key = "MultiOpen3",
			GamePassId = 2038324873,
			DisplayName = "3x Multi Opening",
			Packs = 3,
			Requires = nil :: string?,
			ExpectedPriceRobux = 100 :: number?,
		}),
		MultiOpen6 = table.freeze({
			Key = "MultiOpen6",
			GamePassId = 2039938706,
			DisplayName = "6x Multi Opening",
			Packs = 6,
			Requires = "MultiOpen3" :: string?,
			ExpectedPriceRobux = nil :: number?,
		}),
	}),

	DeveloperProducts = table.freeze({
		TreatsSmall = table.freeze({ Id = 0, DisplayName = "Bag of Treats", Treats = 100 }),
		TreatsLarge = table.freeze({ Id = 0, DisplayName = "Crate of Treats", Treats = 600 }),
	}),
})
