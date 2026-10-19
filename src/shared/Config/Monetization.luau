--!strict
-- Monetization. An Id of 0 means "not created on the Roblox website yet": the item is hidden
-- and never offered.
--
-- MultiOpen entries are DEVELOPER PRODUCTS (not game passes) used as one-time unlocks:
-- MonetizationService handles them in MarketplaceService.ProcessReceipt (idempotent via
-- Purchases.Receipts) and records ownership in Purchases.Entitlements. Prices are set on
-- the Roblox website, never in code; ExpectedPriceRobux is only checked against
-- MarketplaceService:GetProductInfo at server start and a mismatch is logged.

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

	-- Multi Opening unlocks (owner design): 3x first, then 6x (requires 3x).
	MultiOpen = table.freeze({
		MultiOpen3 = table.freeze({
			Key = "MultiOpen3",
			ProductId = 2038324873,
			DisplayName = "3x Multi Opening",
			Packs = 3,
			Requires = nil :: string?,
			ExpectedPriceRobux = 100 :: number?,
		}),
		MultiOpen6 = table.freeze({
			Key = "MultiOpen6",
			ProductId = 2039938706,
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
