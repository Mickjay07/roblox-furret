--!strict
-- Collection ("binder") progress, derived from Discovered.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)
local CardRegistry = require(script.Parent.CardRegistry)

export type Progress = {
	CollectionId: string,
	Discovered: number,
	Total: number,
	Complete: boolean,
}

local Collections = {}

function Collections.progress(data: Types.PlayerData, collectionId: string): Progress
	local cards = CardRegistry.inCollection(collectionId)
	local found = 0
	for _, def in cards do
		if data.Discovered[def.Id] ~= nil then
			found += 1
		end
	end
	return {
		CollectionId = collectionId,
		Discovered = found,
		Total = #cards,
		Complete = #cards > 0 and found == #cards,
	}
end

function Collections.all(data: Types.PlayerData): { Progress }
	local out = {}
	for _, def in Config.Collections.List do
		table.insert(out, Collections.progress(data, def.Id))
	end
	return out
end

-- Total discovered / total cards across every collection.
function Collections.overall(data: Types.PlayerData): (number, number)
	local found = 0
	for _, def in CardRegistry.all() do
		if data.Discovered[def.Id] ~= nil then
			found += 1
		end
	end
	return found, CardRegistry.count()
end

-- Sum of CompletionIncomeBonus over completed collections.
function Collections.incomeBonus(data: Types.PlayerData): number
	local bonus = 0
	for _, def in Config.Collections.List do
		if Collections.progress(data, def.Id).Complete then
			bonus += def.CompletionIncomeBonus
		end
	end
	return bonus
end

return Collections
