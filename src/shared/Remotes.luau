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
		-- (packId, amount) -> { cards = { OpenedCard }, levelsGained, treatsGained }
		OpenPack = "OpenPack",
		-- (slot) collects one stand's earnings; slot 0 collects every stand -> { collected }
		CollectEarnings = "CollectEarnings",
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
