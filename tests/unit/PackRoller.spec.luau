local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local CardRegistry = Loader.require("src/shared/Logic/CardRegistry")
local PackRoller = Loader.require("src/shared/Logic/PackRoller")

local function sequence(values: { number })
	local i = 0
	return function()
		i += 1
		return values[(i - 1) % #values + 1]
	end
end

describe("PackRoller", function()
	local pack = Config.Packs.ById.burrow_pack

	it("opens CardsPerOpen cards from the pack's collections", function()
		local results = PackRoller.open(pack, { roll = sequence({ 0.1, 0.5, 0.2 }) })
		expect(#results).toBe(pack.CardsPerOpen)
		for _, result in results do
			local def = CardRegistry.get(result.CardId)
			expect(def.Collection).toBe("Burrow")
			expect(Config.Variants.ById[result.Variant] ~= nil).toBe(true)
		end
	end)

	it("is deterministic for the same roll sequence", function()
		local a = PackRoller.open(pack, { roll = sequence({ 0.3, 0.7, 0.05, 0.9 }) })
		local b = PackRoller.open(pack, { roll = sequence({ 0.3, 0.7, 0.05, 0.9 }) })
		expect(a).toEqual(b)
	end)

	it("odds sum to 1 and cover every eligible card", function()
		for _, p in Config.Packs.List do
			local total, count = 0, 0
			for _, probability in PackRoller.odds(p) do
				total += probability
				count += 1
			end
			expect(total).toBeNear(1, 1e-9)
			expect(count > 0).toBe(true)
		end
	end)

	it("never rolls a card whose unlock requirement is not met", function()
		local midnight = Config.Packs.ById.midnight_pack
		local isUnlocked = function(def)
			return def.Unlock == nil
		end
		math.randomseed(7)
		for _ = 1, 2000 do
			local result = PackRoller.rollCard(midnight, { isUnlocked = isUnlocked })
			expect(CardRegistry.get(result.CardId).Unlock).toBeNil()
		end
		expect(PackRoller.odds(midnight, { isUnlocked = isUnlocked }).midnight_the_great_dook).toBeNil()
	end)

	it("luck increases the chance of rarer cards", function()
		local base = PackRoller.odds(pack)
		local lucky = PackRoller.odds(pack, { luck = 0.5 })
		expect(lucky.burrow_burrow_boss).toBeGreaterThan(base.burrow_burrow_boss)
		expect(lucky.burrow_sable_scout).toBeLessThan(base.burrow_sable_scout)
	end)

	it("matches the configured distribution over many rolls", function()
		math.randomseed(99)
		local counts = {}
		local n = 30000
		for _ = 1, n do
			local id = PackRoller.rollCard(pack).CardId
			counts[id] = (counts[id] or 0) + 1
		end
		for cardId, probability in PackRoller.odds(pack) do
			expect((counts[cardId] or 0) / n).toBeNear(probability, 0.01)
		end
	end)

	it("formats 1-in-X odds", function()
		expect(PackRoller.oneIn(0.25)).toBe(4)
		expect(PackRoller.oneIn(1 / 313)).toBe(313)
		expect(PackRoller.oneIn(0)).toBe(math.huge)
	end)
end)
