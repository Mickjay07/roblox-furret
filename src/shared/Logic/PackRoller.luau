--!strict
-- Pack opening rolls: rarity -> card -> variant. Pure; randomness is injected via `roll`
-- (returns [0, 1)), so results are deterministic under test.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)
local WeightedRandom = require(script.Parent.Parent.Util.WeightedRandom)
local CardRegistry = require(script.Parent.CardRegistry)

export type RollOptions = {
	luck: number?,
	roll: (() -> number)?,
	-- Filters cards by their unlock requirement. Nil allows every card.
	isUnlocked: ((def: Types.CardDef) -> boolean)?,
}

export type RollResult = {
	CardId: string,
	Variant: string,
}

local PackRoller = {}

-- Cards of a given rarity that this pack can drop.
local function eligibleByRarity(pack: Types.PackDef, options: RollOptions?): { [string]: { Types.CardDef } }
	local isUnlocked = options and options.isUnlocked
	local out: { [string]: { Types.CardDef } } = {}
	for _, collectionId in pack.Collections do
		for _, def in CardRegistry.inCollection(collectionId) do
			if pack.RarityWeights[def.Rarity] and (isUnlocked == nil or isUnlocked(def)) then
				out[def.Rarity] = out[def.Rarity] or {}
				table.insert(out[def.Rarity], def)
			end
		end
	end
	return out
end

-- Rarity weights after dropping rarities with no eligible cards and applying luck.
local function rarityEntries(
	pack: Types.PackDef,
	eligible: { [string]: { Types.CardDef } },
	luck: number
): { WeightedRandom.Entry<string> }
	local entries = {}
	for _, rarity in Config.Rarities.List do
		local weight = pack.RarityWeights[rarity.Id]
		if weight and eligible[rarity.Id] then
			if rarity.LuckAffected then
				weight *= 1 + luck
			end
			table.insert(entries, { value = rarity.Id, weight = weight })
		end
	end
	return entries
end

local function variantEntries(def: Types.CardDef, luck: number): { WeightedRandom.Entry<string> }
	local entries = {}
	for _, variant in Config.Variants.List do
		if CardRegistry.allowsVariant(def, variant.Id) then
			local weight = variant.DropWeight
			if variant.LuckAffected then
				weight *= 1 + luck
			end
			table.insert(entries, { value = variant.Id, weight = weight })
		end
	end
	return entries
end

function PackRoller.rollCard(pack: Types.PackDef, options: RollOptions?): RollResult
	local luck = (options and options.luck) or 0
	local roll = options and options.roll
	local eligible = eligibleByRarity(pack, options)
	local entries = rarityEntries(pack, eligible, luck)
	assert(#entries > 0, `PackRoller: pack {pack.Id} has no eligible cards`)

	local rarityId = WeightedRandom.pick(entries, roll)
	local pool = eligible[rarityId]
	local index = math.clamp(math.floor((if roll then roll() else math.random()) * #pool) + 1, 1, #pool)
	local def = pool[index]
	local variant = WeightedRandom.pick(variantEntries(def, luck), roll)
	return { CardId = def.Id, Variant = variant }
end

function PackRoller.open(pack: Types.PackDef, options: RollOptions?): { RollResult }
	local results = {}
	for _ = 1, pack.CardsPerOpen do
		table.insert(results, PackRoller.rollCard(pack, options))
	end
	return results
end

-- Probability per card roll of each card in the pack (ignores variants), for "1 IN X" labels.
function PackRoller.odds(pack: Types.PackDef, options: RollOptions?): { [string]: number }
	local luck = (options and options.luck) or 0
	local eligible = eligibleByRarity(pack, options)
	local entries = rarityEntries(pack, eligible, luck)
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	local out = {}
	for _, entry in entries do
		local pool = eligible[entry.value]
		for _, def in pool do
			out[def.Id] = (entry.weight / total) / #pool
		end
	end
	return out
end

-- "1 IN X" denominator, rounded to a friendly integer.
function PackRoller.oneIn(probability: number): number
	if probability <= 0 then
		return math.huge
	end
	return math.max(1, math.floor(1 / probability + 0.5))
end

return PackRoller
