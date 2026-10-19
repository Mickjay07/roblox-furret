--!strict
-- Display stands: owned cards placed in numbered slots earn income.
local Types = require(script.Parent.Parent.Types)
local Economy = require(script.Parent.Economy)
local Inventory = require(script.Parent.Inventory)

local Display = {}

local function firstEmptySlot(data: Types.PlayerData): number?
	for slot = 1, Economy.displaySlotCount(data) do
		local id = data.Display[tostring(slot)]
		if id == nil or data.Cards[id] == nil then
			return slot
		end
	end
	return nil
end

-- Places a card in `slot` (0 = first empty slot). A card already displayed elsewhere moves;
-- a card already in the target slot is returned to the backpack.
function Display.place(data: Types.PlayerData, instanceId: string, slot: number): (boolean, string?)
	if not Inventory.owns(data, instanceId) then
		return false, "You don't own that card"
	end
	local target = if slot == 0 then firstEmptySlot(data) else slot
	if target == nil then
		return false, "All stands are full - remove a card or buy more stands"
	end
	if target % 1 ~= 0 or target < 1 or target > Economy.displaySlotCount(data) then
		return false, "That stand is locked"
	end
	local current = Inventory.displaySlotOf(data, instanceId)
	if current then
		data.Display[current] = nil
	end
	data.Display[tostring(target)] = instanceId
	return true
end

function Display.remove(data: Types.PlayerData, instanceId: string): (boolean, string?)
	local slot = Inventory.displaySlotOf(data, instanceId)
	if not slot then
		return false, "That card isn't on a stand"
	end
	data.Display[slot] = nil
	return true
end

-- Fills every unlocked slot with the highest-income cards the player owns.
function Display.placeBest(data: Types.PlayerData)
	local ranked = {}
	for id, instance in data.Cards do
		table.insert(ranked, { id = id, income = Economy.cardIncome(instance) })
	end
	table.sort(ranked, function(a, b)
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.id < b.id
	end)
	table.clear(data.Display)
	for slot = 1, math.min(Economy.displaySlotCount(data), #ranked) do
		data.Display[tostring(slot)] = ranked[slot].id
	end
end

-- Drops entries pointing at missing cards or locked slots (e.g. after data repair).
function Display.sanitize(data: Types.PlayerData): boolean
	local changed = false
	local slots = Economy.displaySlotCount(data)
	local seen = {}
	for key, id in data.Display do
		local slot = tonumber(key)
		if not slot or slot < 1 or slot > slots or slot % 1 ~= 0 or data.Cards[id] == nil or seen[id] then
			data.Display[key] = nil
			changed = true
		else
			seen[id] = true
		end
	end
	return changed
end

return Display
