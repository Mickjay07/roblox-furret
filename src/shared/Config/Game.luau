--!strict
-- Technical game settings: persistence, networking limits, capacities.

return table.freeze({
	GameName = "Ferret Card Tycoon",

	Data = table.freeze({
		-- Changing the store name starts every player from scratch. Use migrations instead.
		StoreName = "PlayerData",
		KeyPrefix = "Player_",
		AutosaveInterval = 90,
		-- A session lock not refreshed for this long is treated as abandoned (crashed server).
		-- Must comfortably exceed AutosaveInterval so throttled saves never look abandoned.
		LockExpirySeconds = 600,
		LoadRetries = 5,
		SaveRetries = 5,
		RetryBaseDelay = 1,
		-- When another server still holds the lock (e.g. a fast rejoin), wait and retry.
		ContestedLockRetries = 6,
		ContestedLockDelay = 5,
		ShutdownTimeout = 25,
		-- In Studio without "Enable Studio Access to API Services", use an in-memory store.
		UseMockStoreInStudio = true,
	}),

	-- Token-bucket rate limits per remote: Rate tokens/second refill, up to Burst tokens.
	RateLimits = table.freeze({
		Default = table.freeze({ Rate = 4, Burst = 8 }),
		GetSnapshot = table.freeze({ Rate = 0.5, Burst = 3 }),
		UpdateSetting = table.freeze({ Rate = 3, Burst = 6 }),
		BuyPack = table.freeze({ Rate = 2, Burst = 4 }),
		OpenPack = table.freeze({ Rate = 2, Burst = 4 }),
		PromptGamePass = table.freeze({ Rate = 0.5, Burst = 2 }),
		PromptProduct = table.freeze({ Rate = 0.5, Burst = 2 }),
		CollectEarnings = table.freeze({ Rate = 8, Burst = 16 }),
		SellCards = table.freeze({ Rate = 2, Burst = 4 }),
		PlaceCard = table.freeze({ Rate = 6, Burst = 12 }),
		RemoveCard = table.freeze({ Rate = 6, Burst = 12 }),
		PlaceBest = table.freeze({ Rate = 1, Burst = 3 }),
		TeleportHome = table.freeze({ Rate = 0.5, Burst = 2 }),
		DevCommand = table.freeze({ Rate = 5, Burst = 10 }),
		SetFavorite = table.freeze({ Rate = 6, Burst = 12 }),
		BuyUpgrade = table.freeze({ Rate = 3, Burst = 6 }),
	}),

	Limits = table.freeze({
		MaxPacksPerPurchase = 10,
		MaxCardsPerSell = 50,
		MaxIdLength = 64,
	}),

	-- Developer tools (roadmap A1). They only ever exist inside Roblox Studio
	-- (RunService:IsStudio()); this flag can additionally switch them off in Studio.
	Dev = table.freeze({
		EnabledInStudio = true,
	}),

	Display = table.freeze({
		BaseSlots = 4,
	}),

	Backpack = table.freeze({
		BaseCapacity = 300,
	}),

	-- Shown when artwork asset ids are empty: a coloured tile with the species initial.
	Art = table.freeze({
		Placeholder = "",
	}),
})
