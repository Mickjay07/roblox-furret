local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local ConfigCheck = Loader.require("src/shared/Logic/ConfigCheck")
local CardRegistry = Loader.require("src/shared/Logic/CardRegistry")

describe("Config", function()
	it("passes every cross-reference check", function()
		local problems = ConfigCheck.run()
		if #problems > 0 then
			error(table.concat(problems, "\n    "))
		end
	end)

	it("defines at least 30 cards", function()
		expect(CardRegistry.count() >= 30).toBe(true)
	end)

	it("gives every collection at least one card and a matching pack", function()
		for _, collection in Config.Collections.List do
			expect(#CardRegistry.inCollection(collection.Id) > 0).toBe(true)
			local hasPack = false
			for _, pack in Config.Packs.List do
				if table.find(pack.Collections, collection.Id) then
					hasPack = true
				end
			end
			expect(hasPack).toBe(true)
		end
	end)

	it("orders packs by price so progression goes up", function()
		local list = Config.Packs.List
		for i = 2, #list do
			expect(list[i].Price).toBeGreaterThan(list[i - 1].Price)
		end
	end)

	it("has variants with non-decreasing multipliers by order", function()
		local list = Config.Variants.List
		for i = 2, #list do
			expect(list[i].IncomeMultiplier >= list[i - 1].IncomeMultiplier).toBe(true)
		end
	end)

	it("reports broken references in a modified config", function()
		local function copy(t)
			if type(t) ~= "table" then
				return t
			end
			local out = {}
			for k, v in t do
				out[k] = copy(v)
			end
			return out
		end
		local broken = copy(Config)
		broken.Economy.StarterCards = { "does_not_exist" }
		broken.Cards.List[1].Rarity = "Ultra"
		broken.Packs.List[1].Collections = { "Nowhere" }
		local text = table.concat(ConfigCheck.run(broken), "\n")
		expect(string.find(text, "starter card does_not_exist", 1, true) ~= nil).toBe(true)
		expect(string.find(text, "unknown rarity Ultra", 1, true) ~= nil).toBe(true)
		expect(string.find(text, "unknown collection Nowhere", 1, true) ~= nil).toBe(true)
	end)
end)
