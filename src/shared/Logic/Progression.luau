--!strict
-- Player level / XP and unlock requirements.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)
local CardRegistry = require(script.Parent.CardRegistry)

local Progression = {}

-- XP required to advance from `level` to `level + 1`.
function Progression.xpToNext(level: number): number
	local p = Config.Economy.Progression
	return math.floor(p.XpBase * level ^ p.XpExponent)
end

-- Adds XP and resolves level-ups. Returns the new level, leftover XP and levels gained.
function Progression.addXp(level: number, xp: number, gained: number): (number, number, number)
	local maxLevel = Config.Economy.Progression.MaxLevel
	local newLevel, newXp = level, xp + gained
	while newLevel < maxLevel and newXp >= Progression.xpToNext(newLevel) do
		newXp -= Progression.xpToNext(newLevel)
		newLevel += 1
	end
	if newLevel >= maxLevel then
		newXp = 0
	end
	return newLevel, newXp, newLevel - level
end

function Progression.isCollectionComplete(data: Types.PlayerData, collectionId: string): boolean
	local cards = CardRegistry.inCollection(collectionId)
	if #cards == 0 then
		return false
	end
	for _, def in cards do
		if data.Discovered[def.Id] == nil then
			return false
		end
	end
	return true
end

function Progression.meets(data: Types.PlayerData, requirement: Types.UnlockRequirement?): boolean
	if requirement == nil then
		return true
	end
	if requirement.Level and data.Progression.Level < requirement.Level then
		return false
	end
	if
		requirement.CollectionComplete and not Progression.isCollectionComplete(data, requirement.CollectionComplete)
	then
		return false
	end
	return true
end

-- Human-readable reason a requirement is not met, or nil if it is.
function Progression.describeMissing(data: Types.PlayerData, requirement: Types.UnlockRequirement?): string?
	if requirement == nil then
		return nil
	end
	if requirement.Level and data.Progression.Level < requirement.Level then
		return `Reach level {requirement.Level}`
	end
	if
		requirement.CollectionComplete and not Progression.isCollectionComplete(data, requirement.CollectionComplete)
	then
		local collection = Config.Collections.ById[requirement.CollectionComplete]
		return `Complete {if collection then collection.DisplayName else requirement.CollectionComplete}`
	end
	return nil
end

return Progression
