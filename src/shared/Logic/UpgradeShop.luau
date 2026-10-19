--!strict
-- Buying permanent upgrades.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)
local Economy = require(script.Parent.Economy)
local Wallet = require(script.Parent.Wallet)

local UpgradeShop = {}

-- Returns (true, newLevel) or (false, message).
function UpgradeShop.buy(data: Types.PlayerData, upgradeId: string): (boolean, any)
	local def = Config.Upgrades.ById[upgradeId]
	if not def then
		return false, "Unknown upgrade"
	end
	local level = Economy.upgradeLevel(data, upgradeId)
	local cost = Economy.upgradeCost(def, level)
	if cost == nil then
		return false, "Already at max level"
	end
	if not Wallet.spend(data, def.Currency, cost) then
		return false, `Not enough {def.Currency}`
	end
	data.Upgrades[upgradeId] = level + 1
	return true, level + 1
end

return UpgradeShop
