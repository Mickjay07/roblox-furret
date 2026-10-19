--!strict
-- In-memory stand-in for a GlobalDataStore. Used in Studio when API access is disabled and
-- by the unit tests. Values are deep-copied on read and write to mimic serialization.
-- Data is lost when the server stops.

export type MockDataStore = {
	UpdateAsync: (self: MockDataStore, key: string, transform: (any, any) -> any) -> any,
	GetAsync: (self: MockDataStore, key: string) -> any,
	-- Test helpers
	failNext: (self: MockDataStore, count: number, message: string?) -> (),
	peek: (self: MockDataStore, key: string) -> any,
	poke: (self: MockDataStore, key: string, value: any) -> (),
	writes: number,
}

local MockDataStore = {}

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = copy(v)
	end
	return out
end

function MockDataStore.new(): MockDataStore
	local entries: { [string]: any } = {}
	local failures = 0
	local failMessage = "MockDataStore: simulated failure"

	local self = { writes = 0 }

	local function maybeFail()
		if failures > 0 then
			failures -= 1
			error(failMessage)
		end
	end

	function self.UpdateAsync(_, key: string, transform: (any, any) -> any): any
		maybeFail()
		local result = transform(copy(entries[key]), nil)
		if result == nil then
			return nil
		end
		entries[key] = copy(result)
		self.writes += 1
		return copy(result)
	end

	function self.GetAsync(_, key: string): any
		maybeFail()
		return copy(entries[key])
	end

	function self.failNext(_, count: number, message: string?)
		failures = count
		failMessage = message or failMessage
	end

	function self.peek(_, key: string): any
		return copy(entries[key])
	end

	function self.poke(_, key: string, value: any)
		entries[key] = copy(value)
	end

	return (self :: any) :: MockDataStore
end

return MockDataStore
