--!strict
-- Selling and favouriting owned cards.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)
local Economy = require(script.Parent.Economy)
local Inventory = require(script.Parent.Inventory)
local Wallet = require(script.Parent.Wallet)

local Market = {}

-- Sells every listed card or none (all-or-nothing). Favourite and displayed cards are
-- protected. Returns (true, cashEarned) or (false, message).
function Market.sell(data: Types.PlayerData, instanceIds: { string }): (boolean, any)
	if #instanceIds == 0 or #instanceIds > Config.Game.Limits.MaxCardsPerSell then
		return false, "Invalid selection"
	end
	local seen = {}
	local total = 0
	for _, id in instanceIds do
		if seen[id] then
			return false, "Invalid selection"
		end
		seen[id] = true
		local instance = data.Cards[id]
		if not instance then
			return false, "You don't own that card"
		end
		if instance.Favorite then
			return false, "Unfavourite a card before selling it"
		end
		if Inventory.displaySlotOf(data, id) then
			return false, "Remove a card from its stand before selling it"
		end
		total += Economy.cardSaleValue(data, instance)
	end
	for _, id in instanceIds do
		Inventory.remove(data, id)
	end
	Wallet.add(data, "Cash", total)
	data.Stats.CardsSold = (data.Stats.CardsSold or 0) + #instanceIds
	return true, total
end

function Market.setFavorite(data: Types.PlayerData, instanceId: string, favorite: boolean): (boolean, string?)
	local instance = data.Cards[instanceId]
	if not instance then
		return false, "You don't own that card"
	end
	instance.Favorite = favorite
	return true
end

return Market
