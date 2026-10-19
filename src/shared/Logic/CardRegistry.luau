--!strict
-- Read-only index over Config.Cards: lookup by id, by collection and by rarity.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)

local CardRegistry = {}

local byId: { [string]: Types.CardDef } = {}
local byCollection: { [string]: { Types.CardDef } } = {}
local byRarity: { [string]: { Types.CardDef } } = {}

for _, def in Config.Cards.List do
	assert(byId[def.Id] == nil, `CardRegistry: duplicate card id {def.Id}`)
	byId[def.Id] = def
	byCollection[def.Collection] = byCollection[def.Collection] or {}
	table.insert(byCollection[def.Collection], def)
	byRarity[def.Rarity] = byRarity[def.Rarity] or {}
	table.insert(byRarity[def.Rarity], def)
end

for _, list in byCollection do
	table.sort(list, function(a, b)
		return a.CollectionNumber < b.CollectionNumber
	end)
end

function CardRegistry.get(cardId: string): Types.CardDef?
	return byId[cardId]
end

function CardRegistry.exists(cardId: any): boolean
	return type(cardId) == "string" and byId[cardId] ~= nil
end

function CardRegistry.all(): { Types.CardDef }
	return Config.Cards.List
end

function CardRegistry.count(): number
	return #Config.Cards.List
end

function CardRegistry.inCollection(collectionId: string): { Types.CardDef }
	return byCollection[collectionId] or {}
end

function CardRegistry.ofRarity(rarityId: string): { Types.CardDef }
	return byRarity[rarityId] or {}
end

-- Whether a card can roll as the given variant.
function CardRegistry.allowsVariant(def: Types.CardDef, variantId: string): boolean
	if Config.Variants.ById[variantId] == nil then
		return false
	end
	return def.Variants == nil or table.find(def.Variants, variantId) ~= nil
end

return CardRegistry
