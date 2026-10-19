--!strict
-- Income, sale value, upgrade effects and costs. Pure functions over PlayerData.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)
local CardRegistry = require(script.Parent.CardRegistry)
local Collections = require(script.Parent.Collections)

local Economy = {}

function Economy.upgradeLevel(data: Types.PlayerData, upgradeId: string): number
	return data.Upgrades[upgradeId] or 0
end

-- Effect total for an upgrade: level * PerLevel.
function Economy.upgradeEffect(data: Types.PlayerData, upgradeId: string): number
	local def = Config.Upgrades.ById[upgradeId]
	if not def then
		return 0
	end
	return Economy.upgradeLevel(data, upgradeId) * def.PerLevel
end

-- Cost to buy the next level, or nil when maxed.
function Economy.upgradeCost(def: Types.UpgradeDef, currentLevel: number): number?
	if currentLevel >= def.MaxLevel then
		return nil
	end
	return math.floor(def.BaseCost * def.CostGrowth ^ currentLevel)
end

function Economy.gradeMultiplier(grade: number?): number
	if grade == nil then
		return 1
	end
	return Config.Grading.Multipliers[grade] or 1
end

local function variantDef(variantId: string): Types.VariantDef
	return Config.Variants.ById[variantId] or Config.Variants.ById[Config.Variants.Default]
end

-- Income per second of one card instance, before player-wide multipliers.
function Economy.cardIncome(instance: Types.CardInstance): number
	local def = CardRegistry.get(instance.CardId)
	if not def then
		return 0
	end
	return def.BaseIncome * variantDef(instance.Variant).IncomeMultiplier * Economy.gradeMultiplier(instance.Grade)
end

-- Cash received for selling one card instance, including the player's sell bonus.
function Economy.cardSaleValue(data: Types.PlayerData, instance: Types.CardInstance): number
	local def = CardRegistry.get(instance.CardId)
	if not def then
		return 0
	end
	local value = def.BaseSaleValue
		* Config.Economy.SaleMultiplier
		* variantDef(instance.Variant).SaleMultiplier
		* Economy.gradeMultiplier(instance.Grade)
		* (1 + Economy.upgradeEffect(data, "SellBonus"))
	return math.floor(value)
end

-- Player-wide income multiplier from upgrades and completed collections.
-- `extra` lets callers fold in server-only sources (game passes, boosts).
function Economy.incomeMultiplier(data: Types.PlayerData, extra: number?): number
	return (1 + Economy.upgradeEffect(data, "IncomeBoost") + Collections.incomeBonus(data)) * (extra or 1)
end

function Economy.displaySlotCount(data: Types.PlayerData): number
	return Config.Game.Display.BaseSlots + math.floor(Economy.upgradeEffect(data, "DisplaySlots"))
end

function Economy.backpackCapacity(data: Types.PlayerData): number
	return Config.Game.Backpack.BaseCapacity + math.floor(Economy.upgradeEffect(data, "BackpackSpace"))
end

function Economy.luck(data: Types.PlayerData): number
	return Economy.upgradeEffect(data, "Luck")
end

-- Total income per second from displayed cards.
function Economy.totalIncome(data: Types.PlayerData, extra: number?): number
	local slots = Economy.displaySlotCount(data)
	local base = 0
	for slotKey, instanceId in data.Display do
		local slot = tonumber(slotKey)
		local instance = data.Cards[instanceId]
		if slot and slot >= 1 and slot <= slots and instance then
			base += Economy.cardIncome(instance)
		end
	end
	return base * Economy.incomeMultiplier(data, extra)
end

return Economy
