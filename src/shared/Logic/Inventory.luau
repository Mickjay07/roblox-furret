--!strict
-- Owned card instances. Each instance has a unique id "<userId>-<serial>": the serial comes
-- from the player's own persistent counter, and the user id makes it unique across players
-- (ready for future trading).
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)
local CardRegistry = require(script.Parent.CardRegistry)
local Economy = require(script.Parent.Economy)

local Inventory = {}

function Inventory.count(data: Types.PlayerData): number
	local n = 0
	for _ in data.Cards do
		n += 1
	end
	return n
end

function Inventory.freeSpace(data: Types.PlayerData): number
	return math.max(0, Economy.backpackCapacity(data) - Inventory.count(data))
end

function Inventory.owns(data: Types.PlayerData, instanceId: any): boolean
	return type(instanceId) == "string" and data.Cards[instanceId] ~= nil
end

-- Returns the display slot key holding this instance, if any.
function Inventory.displaySlotOf(data: Types.PlayerData, instanceId: string): string?
	for slot, id in data.Display do
		if id == instanceId then
			return slot
		end
	end
	return nil
end

-- Adds a new card instance. Returns (instanceId, isNewDiscovery) or (nil, reason).
-- `ignoreCapacity` is only for one-off grants such as starter cards.
function Inventory.add(
	data: Types.PlayerData,
	ownerId: number,
	cardId: string,
	variant: string,
	now: number,
	ignoreCapacity: boolean?
): (string?, boolean | string)
	local def = CardRegistry.get(cardId)
	if not def then
		return nil, "unknown card"
	end
	if not CardRegistry.allowsVariant(def, variant) then
		return nil, "invalid variant"
	end
	if not ignoreCapacity and Inventory.freeSpace(data) < 1 then
		return nil, "backpack full"
	end

	local serial = data.NextCardSerial
	data.NextCardSerial = serial + 1
	local instanceId = `{ownerId}-{serial}`
	assert(data.Cards[instanceId] == nil, "Inventory.add: instance id collision")

	data.Cards[instanceId] = {
		CardId = cardId,
		Variant = variant,
		Grade = nil,
		Obtained = now,
		Favorite = false,
	}

	local entry = data.Discovered[cardId]
	local isNew = entry == nil
	if not entry then
		entry = { First = now, Count = 0, Variants = {} }
		data.Discovered[cardId] = entry
	end
	entry.Count += 1
	entry.Variants[variant] = true
	data.Stats.CardsObtained = (data.Stats.CardsObtained or 0) + 1
	return instanceId, isNew
end

-- Removes an instance (and clears it from any display slot). Returns the removed instance.
function Inventory.remove(data: Types.PlayerData, instanceId: string): Types.CardInstance?
	local instance = data.Cards[instanceId]
	if not instance then
		return nil
	end
	local slot = Inventory.displaySlotOf(data, instanceId)
	if slot then
		data.Display[slot] = nil
	end
	data.Cards[instanceId] = nil
	return instance
end

-- Variant ids ordered from most to least valuable, for sorting.
function Inventory.variantOrder(variant: string): number
	local def = Config.Variants.ById[variant]
	return if def then def.Order else 0
end

return Inventory
