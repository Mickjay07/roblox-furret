local TestKit = require("../TestKit")
local WeightedRandom = require("../../src/shared/Util/WeightedRandom")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local entries = {
	{ value = "common", weight = 70 },
	{ value = "rare", weight = 25 },
	{ value = "legendary", weight = 5 },
}

local function fixed(n: number)
	return function()
		return n
	end
end

describe("WeightedRandom.pick", function()
	it("maps roll boundaries onto cumulative weights", function()
		expect(WeightedRandom.pick(entries, fixed(0))).toBe("common")
		expect(WeightedRandom.pick(entries, fixed(0.6999))).toBe("common")
		expect(WeightedRandom.pick(entries, fixed(0.70))).toBe("rare")
		expect(WeightedRandom.pick(entries, fixed(0.9499))).toBe("rare")
		expect(WeightedRandom.pick(entries, fixed(0.95))).toBe("legendary")
	end)

	it("never returns a zero-weight entry, even at roll ~1", function()
		local withZero = {
			{ value = "a", weight = 1 },
			{ value = "never", weight = 0 },
		}
		expect(WeightedRandom.pick(withZero, fixed(0.999999999))).toBe("a")
	end)

	it("approximates the configured distribution", function()
		math.randomseed(1234)
		local counts = { common = 0, rare = 0, legendary = 0 }
		local n = 100000
		for _ = 1, n do
			local v = WeightedRandom.pick(entries)
			counts[v] += 1
		end
		expect(counts.common / n).toBeNear(0.70, 0.01)
		expect(counts.rare / n).toBeNear(0.25, 0.01)
		expect(counts.legendary / n).toBeNear(0.05, 0.005)
	end)

	it("rejects invalid input", function()
		expect(function()
			WeightedRandom.pick({})
		end).toThrow()
		expect(function()
			WeightedRandom.pick({ { value = 1, weight = 0 } })
		end).toThrow()
		expect(function()
			WeightedRandom.pick({ { value = 1, weight = -1 } })
		end).toThrow()
	end)
end)
