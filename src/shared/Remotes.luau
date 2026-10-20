--!strict
-- Every RemoteEvent / RemoteFunction name. The server creates them in
-- ReplicatedStorage.Remotes at startup (server/Lib/Net); clients look them up by these names.
--
-- Functions are client -> server requests that return a Result table:
--   { ok = true, ... } or { ok = false, error = "message for the player" }.
-- Events listed here are server -> client only; the server ignores anything clients fire.

local Remotes = {
	Functions = {
		GetSnapshot = "GetSnapshot",
		UpdateSetting = "UpdateSetting",
		-- (packId, amount) -> { owned } buys packs into the pack inventory
		BuyPack = "BuyPack",
		-- (packId, requestId, packs) opens 1, 3 or 6 owned packs together (3 and 6 need the
		-- Multi Opening unlocks) -> { packs, cardsPerPack, cards = { RevealCard },
		-- levelsGained, treatsGained }. Repeating a requestId returns the same result.
		OpenPack = "OpenPack",
		-- (passKey) asks the server to prompt a game pass (VIP, 2x AFK, Multi Opening...); the
		-- server checks prerequisites first. Ownership is only ever set from UserOwnsGamePassAsync.
		PromptGamePass = "PromptGamePass",
		-- (productKey) asks the server to prompt a Developer Product. Nothing is granted here:
		-- products are granted only in ProcessReceipt, after Roblox charged the player.
		PromptProduct = "PromptProduct",
		-- (slot) collects one stand's earnings; slot 0 collects every stand -> { collected }
		CollectEarnings = "CollectEarnings",
		-- () moves your character to your own plot
		TeleportHome = "TeleportHome",
		-- (instanceIds) -> { earned }
		SellCards = "SellCards",
		-- (instanceId, favorite)
		SetFavorite = "SetFavorite",
		-- (instanceId, slot) where slot 0 = first empty stand
		PlaceCard = "PlaceCard",
		-- (instanceId)
		RemoveCard = "RemoveCard",
		-- () fills every stand with the best cards
		PlaceBest = "PlaceBest",
		-- (upgradeId) -> { level }
		BuyUpgrade = "BuyUpgrade",
	},
	-- Created only in Roblox Studio by DevService (never on live servers).
	DevFunctions = {
		-- (commandLine: string) -> { ok, message }
		DevCommand = "DevCommand",
	},
	Events = {
		-- (key: string, value: any) replaces a whole top-level PlayerData field.
		DataChanged = "DataChanged",
		-- (key: string, set: { [string]: any }, remove: { string }) patches a map field.
		DataPatched = "DataPatched",
		-- (message: string, kind: string) shows a toast notification.
		Notify = "Notify",
	},
}

return Remotes
