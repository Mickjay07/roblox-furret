--!strict
-- Buying and opening packs. All checks happen before anything changes, so a rejected
-- purchase leaves the data untouched.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)
local Economy = require(script.Parent.Economy)
local Inventory = require(script.Parent.Inventory)
local PackRoller = require(script.Parent.PackRoller)
local Progression = require(script.Parent.Progression)
local Wallet = require(script.Parent.Wallet)

export type Context = {
	ownerId: number,
	now: number,
	roll: (() -> number)?,
}

export type OpenedCard = {
	InstanceId: string,
	CardId: string,
	Variant: string,
	IsNew: boolean,
	OneIn: number,
}

export type Purchase = {
	PackId: string,
	Amount: number,
	Cost: number,
	Cards: { OpenedCard },
	XpGained: number,
	LevelsGained: number,
	TreatsGained: number,
	-- Map keys that changed, for replication.
	NewInstanceIds: { string },
	DiscoveredIds: { string },
}

local PackShop = {}

function PackShop.isUnlocked(data: Types.PlayerData, pack: Types.PackDef): boolean
	return Progression.meets(data, pack.Unlock)
end

-- Validates and performs a purchase of `amount` packs. Returns (true, Purchase) or
-- (false, message for the player).
function PackShop.buy(data: Types.PlayerData, packId: string, amount: number, ctx: Context): (boolean, any)
	local pack = Config.Packs.ById[packId]
	if not pack then
		return false, "That pack doesn't exist"
	end
	if amount % 1 ~= 0 or amount < 1 or amount > Config.Game.Limits.MaxPacksPerPurchase then
		return false, "Invalid amount"
	end
	if not PackShop.isUnlocked(data, pack) then
		return false, Progression.describeMissing(data, pack.Unlock) or "Pack is locked"
	end
	local cardCount = amount * pack.CardsPerOpen
	if Inventory.freeSpace(data) < cardCount then
		return false, "Not enough backpack space - sell or display some cards"
	end
	local cost = pack.Price * amount
	if not Wallet.spend(data, pack.Currency, cost) then
		return false, `Not enough {pack.Currency}`
	end

	local options: PackRoller.RollOptions = {
		luck = Economy.luck(data),
		roll = ctx.roll,
		isUnlocked = function(def: Types.CardDef): boolean
			return Progression.meets(data, def.Unlock)
		end,
	}
	local odds = PackRoller.odds(pack, options)

	local purchase: Purchase = {
		PackId = packId,
		Amount = amount,
		Cost = cost,
		Cards = {},
		XpGained = pack.Xp * amount,
		LevelsGained = 0,
		TreatsGained = 0,
		NewInstanceIds = {},
		DiscoveredIds = {},
	}
	for _ = 1, amount do
		for _, rolled in PackRoller.open(pack, options) do
			local instanceId, isNew = Inventory.add(data, ctx.ownerId, rolled.CardId, rolled.Variant, ctx.now)
			-- Space and validity were checked above, so this cannot fail.
			assert(instanceId, "PackShop: failed to add rolled card")
			table.insert(purchase.Cards, {
				InstanceId = instanceId,
				CardId = rolled.CardId,
				Variant = rolled.Variant,
				IsNew = isNew == true,
				OneIn = PackRoller.oneIn(odds[rolled.CardId] or 0),
			})
			table.insert(purchase.NewInstanceIds, instanceId)
			if not table.find(purchase.DiscoveredIds, rolled.CardId) then
				table.insert(purchase.DiscoveredIds, rolled.CardId)
			end
		end
	end

	data.Stats.PacksOpened = (data.Stats.PacksOpened or 0) + amount
	local level, xp, gained = Progression.addXp(data.Progression.Level, data.Progression.Xp, purchase.XpGained)
	data.Progression.Level, data.Progression.Xp = level, xp
	purchase.LevelsGained = gained
	if gained > 0 then
		purchase.TreatsGained = gained * Config.Economy.Progression.TreatsPerLevel
		Wallet.add(data, "Treats", purchase.TreatsGained)
	end
	return true, purchase
end

return PackShop
