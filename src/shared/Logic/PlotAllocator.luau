--!strict
-- Plot ownership on one server (owner decision Q4: a free plot is assigned automatically on
-- join). Unique ownership, lowest free index first, released on leave. Pure and testable.

export type PlotAllocator = {
	assign: (self: PlotAllocator, userId: number) -> number?,
	release: (self: PlotAllocator, userId: number) -> number?,
	plotOf: (self: PlotAllocator, userId: number) -> number?,
	ownerOf: (self: PlotAllocator, index: number) -> number?,
	isOwner: (self: PlotAllocator, userId: number, index: number) -> boolean,
	freeCount: (self: PlotAllocator) -> number,
	count: (self: PlotAllocator) -> number,
}

local PlotAllocator = {}

function PlotAllocator.new(count: number): PlotAllocator
	assert(count >= 1 and count % 1 == 0, "PlotAllocator: count must be a positive integer")
	local owners: { [number]: number } = {} -- plot index -> userId
	local plots: { [number]: number } = {} -- userId -> plot index

	local self = {}

	-- Returns the player's plot (existing or newly assigned), or nil when every plot is taken.
	function self.assign(_, userId: number): number?
		local existing = plots[userId]
		if existing then
			return existing
		end
		for index = 1, count do
			if owners[index] == nil then
				owners[index] = userId
				plots[userId] = index
				return index
			end
		end
		return nil
	end

	-- Frees the player's plot. Returns the released index, or nil if they had none.
	function self.release(_, userId: number): number?
		local index = plots[userId]
		if index then
			plots[userId] = nil
			owners[index] = nil
		end
		return index
	end

	function self.plotOf(_, userId: number): number?
		return plots[userId]
	end

	function self.ownerOf(_, index: number): number?
		return owners[index]
	end

	function self.isOwner(_, userId: number, index: number): boolean
		return owners[index] ~= nil and owners[index] == userId
	end

	function self.freeCount(_): number
		local used = 0
		for _ in owners do
			used += 1
		end
		return count - used
	end

	function self.count(_): number
		return count
	end

	return (self :: any) :: PlotAllocator
end

return PlotAllocator
