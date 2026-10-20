--!strict
-- Monetization. An id of 0 means "not created on the Roblox website yet": the item is shown
-- as unavailable and is never offered for purchase.
--
-- GAME PASSES (GamePasses, MultiOpen) are permanent. Roblox is the source of truth for
-- ownership: MonetizationService asks UserOwnsGamePassAsync on join and after the server-side
-- PromptGamePassPurchaseFinished, and mirrors confirmed answers into Purchases.Entitlements
-- (a cache that a failed query never clears). No ProcessReceipt for passes.
--
-- DEVELOPER PRODUCTS (DeveloperProducts, LimitedBundles) are repeatable. They are granted
-- only in MarketplaceService.ProcessReceipt (Lib/ReceiptProcessor): idempotent through
-- Purchases.Receipts, saved before PurchaseGranted is returned. `Grants` says what one
-- purchase gives: Packs = { [packId] = count } go into the pack inventory (data.Packs, the
-- same place cash-bought packs go), Currency = { [currency] = amount } into the wallet.
--
-- Prices are set on the Roblox website, never in code. GetProductInfo is read at server start
-- (InfoType.GamePass for passes, InfoType.Product for products) and published for the UI;
-- ExpectedPriceRobux is the owner's intended price, compared and logged on mismatch.

return table.freeze({
	-- Permanent passes other than Multi Opening.
	GamePasses = table.freeze({
		VIP = table.freeze({
			Key = "VIP",
			GamePassId = 2040244736,
			DisplayName = "VIP",
			Description = "+25% income from every stand",
			Icon = "ui.shop.vip" :: string?,
			Order = 1,
			-- Applied in Economy.incomeMultiplier (shared, so the HUD shows the real rate).
			IncomeMultiplier = 1.25,
			ExpectedPriceRobux = nil :: number?,
		}),
		AfkCash2x = table.freeze({
			Key = "AfkCash2x",
			GamePassId = 2038205144,
			DisplayName = "2x AFK Time Cash",
			Description = "Double the cash your stands earn while you're away",
			Icon = nil :: string?,
			Order = 2,
			-- Applied once to the offline earnings credited at join (IncomeLedger.applyOffline).
			OfflineMultiplier = 2,
			ExpectedPriceRobux = nil :: number?,
		}),
		OpenAll = table.freeze({
			Key = "OpenAll",
			-- No game pass id has been provided yet: shown as unavailable, never sold.
			GamePassId = 0,
			DisplayName = "Open All",
			Description = "Open every pack in your bag at once",
			Icon = "ui.shop.open_all" :: string?,
			Order = 5,
			ExpectedPriceRobux = nil :: number?,
		}),
	}),

	-- Multi Opening game passes (owner design): 3x first, then 6x (requires 3x).
	MultiOpen = table.freeze({
		MultiOpen3 = table.freeze({
			Key = "MultiOpen3",
			GamePassId = 2038324873,
			DisplayName = "Open 3 at Once",
			Description = "Open 3 packs together, 3 cards per click",
			Icon = "ui.shop.open3" :: string?,
			Order = 3,
			Packs = 3,
			Requires = nil :: string?,
			ExpectedPriceRobux = 100 :: number?,
		}),
		MultiOpen6 = table.freeze({
			Key = "MultiOpen6",
			GamePassId = 2039938706,
			DisplayName = "Open 6 at Once",
			Description = "Open 6 packs together (needs Open 3)",
			Icon = "ui.shop.open6" :: string?,
			Order = 4,
			Packs = 6,
			Requires = "MultiOpen3" :: string?,
			ExpectedPriceRobux = nil :: number?,
		}),
	}),

	-- Repeatable Robux purchases.
	DeveloperProducts = table.freeze({
		Packs1 = table.freeze({
			Key = "Packs1",
			ProductId = 3720277269,
			DisplayName = "1 Pack",
			Description = "1 Pack 1 booster, straight to your bag",
			Icon = "pack.pack1.front" :: string?,
			Section = "Packs",
			Order = 1,
			Grants = table.freeze({ Packs = table.freeze({ pack1 = 1 }) }),
			ExpectedPriceRobux = 75 :: number?,
		}),
		Packs3 = table.freeze({
			Key = "Packs3",
			ProductId = 3720277334,
			DisplayName = "3 Packs",
			Description = "3 Pack 1 boosters, straight to your bag",
			Icon = "pack.pack1.front" :: string?,
			Section = "Packs",
			Order = 2,
			Grants = table.freeze({ Packs = table.freeze({ pack1 = 3 }) }),
			ExpectedPriceRobux = 199 :: number?,
		}),
		Packs10 = table.freeze({
			Key = "Packs10",
			ProductId = 3720277406,
			DisplayName = "10 Packs",
			Description = "10 Pack 1 boosters, straight to your bag",
			Icon = "pack.pack1.front" :: string?,
			Section = "Packs",
			Order = 3,
			Grants = table.freeze({ Packs = table.freeze({ pack1 = 10 }) }),
			ExpectedPriceRobux = 499 :: number?,
		}),
		TreatsSmall = table.freeze({
			Key = "TreatsSmall",
			ProductId = 0,
			DisplayName = "Bag of Treats",
			Description = "100 Treats",
			Icon = nil :: string?,
			Section = "Currency",
			Order = 10,
			Grants = table.freeze({ Currency = table.freeze({ Treats = 100 }) }),
			ExpectedPriceRobux = nil :: number?,
		}),
		TreatsLarge = table.freeze({
			Key = "TreatsLarge",
			ProductId = 0,
			DisplayName = "Crate of Treats",
			Description = "600 Treats",
			Icon = nil :: string?,
			Section = "Currency",
			Order = 11,
			Grants = table.freeze({ Currency = table.freeze({ Treats = 600 }) }),
			ExpectedPriceRobux = nil :: number?,
		}),
	}),

	-- Limited-time Robux bundles: Developer Products with a sale window (Unix seconds,
	-- server time). Same fields as DeveloperProducts plus StartsAt / EndsAt; Section is
	-- "Limited". Add entries here once the products exist on the Roblox website.
	LimitedBundles = table.freeze({} :: { [string]: any }),
})
