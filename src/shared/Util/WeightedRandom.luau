--!strict
-- Weighted random selection, the core of any pack-opening / rarity roll.
-- Pure Luau with no Roblox API dependencies, so it is unit-tested under Lune.

export type Entry<T> = {
	value: T,
	weight: number,
}

local WeightedRandom = {}

-- `roll` returns a number in [0, 1). Defaults to math.random; pass a seeded
-- function (e.g. from Random.new(seed)) for deterministic results.
function WeightedRandom.pick<T>(entries: { Entry<T> }, roll: (() -> number)?): T
	assert(#entries > 0, "WeightedRandom.pick: entries is empty")

	local total = 0
	for _, entry in entries do
		assert(entry.weight >= 0, "WeightedRandom.pick: negative weight")
		total += entry.weight
	end
	assert(total > 0, "WeightedRandom.pick: total weight is zero")

	local target = (if roll then roll() else math.random()) * total
	local cumulative = 0
	for _, entry in entries do
		cumulative += entry.weight
		if target < cumulative then
			return entry.value
		end
	end

	-- Floating point safety net: return the last entry with non-zero weight.
	for i = #entries, 1, -1 do
		if entries[i].weight > 0 then
			return entries[i].value
		end
	end
	error("unreachable")
end

return WeightedRandom
