--!strict
-- Monetization placeholders. An Id of 0 means "not created on the Roblox website yet": the
-- item is hidden and never offered. Purchase handling (MarketplaceService.ProcessReceipt
-- with receipt de-duplication in Purchases.Receipts) is not implemented yet.

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
		TripleOpen = table.freeze({
			Id = 0,
			DisplayName = "Triple Open",
			Description = "Open three packs at once.",
		}),
	}),

	DeveloperProducts = table.freeze({
		TreatsSmall = table.freeze({ Id = 0, DisplayName = "Bag of Treats", Treats = 100 }),
		TreatsLarge = table.freeze({ Id = 0, DisplayName = "Crate of Treats", Treats = 600 }),
	}),
})
