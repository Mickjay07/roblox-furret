-- Minimal test harness for Lune. Specs call describe/it/expect; run.luau reports results.

local TestKit = {}

local results = { passed = 0, failed = 0, failures = {} :: { string } }
local prefix = ""

function TestKit.describe(name: string, body: () -> ())
	local previous = prefix
	prefix = prefix .. name .. " > "
	body()
	prefix = previous
end

function TestKit.it(name: string, body: () -> ())
	local ok, err = pcall(body)
	if ok then
		results.passed += 1
	else
		results.failed += 1
		table.insert(results.failures, `{prefix}{name}\n    {err}`)
	end
end

function TestKit.expect(actual: any)
	local function fail(message: string)
		error(message, 3)
	end
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				fail(`expected {tostring(expected)}, got {tostring(actual)}`)
			end
		end,
		toBeNear = function(expected: number, tolerance: number)
			if math.abs(actual - expected) > tolerance then
				fail(`expected {actual} to be within {tolerance} of {expected}`)
			end
		end,
		toEqual = function(expected: any)
			local function deepEqual(a: any, b: any): boolean
				if type(a) ~= "table" or type(b) ~= "table" then
					return a == b
				end
				for k, v in a do
					if not deepEqual(v, b[k]) then
						return false
					end
				end
				for k in b do
					if a[k] == nil then
						return false
					end
				end
				return true
			end
			if not deepEqual(actual, expected) then
				fail("tables are not deeply equal")
			end
		end,
		toBeGreaterThan = function(expected: number)
			if not (actual > expected) then
				fail(`expected {actual} > {expected}`)
			end
		end,
		toBeLessThan = function(expected: number)
			if not (actual < expected) then
				fail(`expected {actual} < {expected}`)
			end
		end,
		toBeNil = function()
			if actual ~= nil then
				fail(`expected nil, got {tostring(actual)}`)
			end
		end,
		toThrow = function()
			if pcall(actual) then
				fail("expected function to throw")
			end
		end,
	}
end

function TestKit.results()
	return results
end

return TestKit
