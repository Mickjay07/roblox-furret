--!strict
-- Currency operations on PlayerData. Amounts must be non-negative finite numbers.
local Types = require(script.Parent.Parent.Types)

local Wallet = {}

local function valid(amount: number): boolean
	return amount == amount and amount >= 0 and amount ~= math.huge
end

function Wallet.balance(data: Types.PlayerData, currency: string): number
	return data.Currency[currency] or 0
end

function Wallet.canAfford(data: Types.PlayerData, currency: string, amount: number): boolean
	return valid(amount) and Wallet.balance(data, currency) >= amount
end

function Wallet.add(data: Types.PlayerData, currency: string, amount: number)
	assert(valid(amount), "Wallet.add: invalid amount")
	data.Currency[currency] = Wallet.balance(data, currency) + amount
	if currency == "Cash" then
		data.Stats.CashEarned = (data.Stats.CashEarned or 0) + amount
	end
end

-- Deducts `amount`; returns false (and changes nothing) if the player cannot afford it.
function Wallet.spend(data: Types.PlayerData, currency: string, amount: number): boolean
	if not Wallet.canAfford(data, currency, amount) then
		return false
	end
	data.Currency[currency] = Wallet.balance(data, currency) - amount
	if currency == "Cash" then
		data.Stats.CashSpent = (data.Stats.CashSpent or 0) + amount
	end
	return true
end

return Wallet
