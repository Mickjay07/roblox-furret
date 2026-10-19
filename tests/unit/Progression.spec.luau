local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local Progression = Loader.require("src/shared/Logic/Progression")
local Collections = Loader.require("src/shared/Logic/Collections")
local ProfileSchema = Loader.require("src/shared/Data/ProfileSchema")

describe("Progression", function()
	it("uses the configured XP curve", function()
		local p = Config.Economy.Progression
		expect(Progression.xpToNext(1)).toBe(math.floor(p.XpBase))
		expect(Progression.xpToNext(4)).toBe(math.floor(p.XpBase * 4 ^ p.XpExponent))
	end)

	it("handles multiple level-ups and keeps leftover XP", function()
		local need1, need2 = Progression.xpToNext(1), Progression.xpToNext(2)
		local level, xp, gained = Progression.addXp(1, 0, need1 + need2 + 3)
		expect(level).toBe(3)
		expect(xp).toBe(3)
		expect(gained).toBe(2)
	end)

	it("caps at the max level", function()
		local max = Config.Economy.Progression.MaxLevel
		local level, xp = Progression.addXp(max - 1, 0, 1e12)
		expect(level).toBe(max)
		expect(xp).toBe(0)
	end)

	it("checks level and collection requirements", function()
		local data = ProfileSchema.defaults()
		expect(Progression.meets(data, nil)).toBe(true)
		expect(Progression.meets(data, { Level = 2 })).toBe(false)
		expect(Progression.describeMissing(data, { Level = 2 })).toBe("Reach level 2")
		data.Progression.Level = 2
		expect(Progression.meets(data, { Level = 2 })).toBe(true)
		expect(Progression.meets(data, { CollectionComplete = "Burrow" })).toBe(false)
		for _, def in Config.Cards.List do
			if def.Collection == "Burrow" then
				data.Discovered[def.Id] = { First = 0, Count = 1, Variants = {} }
			end
		end
		expect(Progression.meets(data, { CollectionComplete = "Burrow" })).toBe(true)
	end)
end)

describe("Collections", function()
	it("reports per-collection and overall progress", function()
		local data = ProfileSchema.defaults()
		data.Discovered.burrow_sable_scout = { First = 0, Count = 2, Variants = { Normal = true } }
		local progress = Collections.progress(data, "Burrow")
		expect(progress.Discovered).toBe(1)
		expect(progress.Total).toBe(6)
		expect(progress.Complete).toBe(false)
		local found, total = Collections.overall(data)
		expect(found).toBe(1)
		expect(total).toBe(#Config.Cards.List)
		expect(#Collections.all(data)).toBe(#Config.Collections.List)
	end)
end)
