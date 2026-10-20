--!strict
-- Buying packs into the pack inventory and opening them. All checks happen before anything
-- changes, so a rejected request leaves the data untouched.
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

export type Opening = {
	PackId: string,
	Amount: number,
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

function PackShop.owned(data: Types.PlayerData, packId: string): number
	return data.Packs[packId] or 0
end

-- Adds packs to the inventory without charging (starter packs, rewards).
function PackShop.grant(data: Types.PlayerData, packId: string, amount: number)
	assert(Config.Packs.ById[packId], `PackShop.grant: unknown pack {packId}`)
	assert(amount % 1 == 0 and amount > 0, "PackShop.grant: invalid amount")
	data.Packs[packId] = PackShop.owned(data, packId) + amount
end

local function validAmount(amount: number): boolean
	return amount % 1 == 0 and amount >= 1 and amount <= Config.Game.Limits.MaxPacksPerPurchase
end

-- Buys `amount` packs into the pack inventory (owner decision Q1: packs are opened later).
-- Returns (true, cost) or (false, message for the player). Nothing changes on failure.
function PackShop.buy(data: Types.PlayerData, packId: string, amount: number): (boolean, any)
	local pack = Config.Packs.ById[packId]
	if not pack then
		return false, "That pack doesn't exist"
	end
	if pack.ShopHidden then
		-- Premium packs are only granted (Robux products, rewards), never sold for currency.
		return false, "That pack isn't sold for Cash"
	end
	if not validAmount(amount) then
		return false, "Invalid amount"
	end
	if not PackShop.isUnlocked(data, pack) then
		return false, Progression.describeMissing(data, pack.Unlock) or "Pack is locked"
	end
	local cost = pack.Price * amount
	if not Wallet.spend(data, pack.Currency, cost) then
		return false, `Not enough {pack.Currency}`
	end
	data.Packs[packId] = PackShop.owned(data, packId) + amount
	return true, cost
end

-- Opens `amount` owned packs. All checks happen before anything changes, so a rejected
-- opening leaves the data untouched. Returns (true, Opening) or (false, message).
function PackShop.open(data: Types.PlayerData, packId: string, amount: number, ctx: Context): (boolean, any)
	local pack = Config.Packs.ById[packId]
	if not pack then
		return false, "That pack doesn't exist"
	end
	if not validAmount(amount) then
		return false, "Invalid amount"
	end
	if PackShop.owned(data, packId) < amount then
		return false, "You don't have that many packs"
	end
	if Inventory.freeSpace(data) < amount * pack.CardsPerOpen then
		return false, "Not enough backpack space - sell or display some cards"
	end

	local remaining = PackShop.owned(data, packId) - amount
	if remaining > 0 then
		data.Packs[packId] = remaining
	else
		data.Packs[packId] = nil
	end

	local options: PackRoller.RollOptions = {
		luck = Economy.luck(data),
		roll = ctx.roll,
		isUnlocked = function(def: Types.CardDef): boolean
			return Progression.meets(data, def.Unlock)
		end,
	}
	local odds = PackRoller.odds(pack, options)

	local opening: Opening = {
		PackId = packId,
		Amount = amount,
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
			table.insert(opening.Cards, {
				InstanceId = instanceId,
				CardId = rolled.CardId,
				Variant = rolled.Variant,
				IsNew = isNew == true,
				OneIn = PackRoller.oneIn(odds[rolled.CardId] or 0),
			})
			table.insert(opening.NewInstanceIds, instanceId)
			if not table.find(opening.DiscoveredIds, rolled.CardId) then
				table.insert(opening.DiscoveredIds, rolled.CardId)
			end
		end
	end

	data.Stats.PacksOpened = (data.Stats.PacksOpened or 0) + amount
	local level, xp, gained = Progression.addXp(data.Progression.Level, data.Progression.Xp, opening.XpGained)
	data.Progression.Level, data.Progression.Xp = level, xp
	opening.LevelsGained = gained
	if gained > 0 then
		opening.TreatsGained = gained * Config.Economy.Progression.TreatsPerLevel
		Wallet.add(data, "Treats", opening.TreatsGained)
	end
	return true, opening
end

return PackShop
