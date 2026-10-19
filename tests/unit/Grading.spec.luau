local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local Grading = Loader.require("src/shared/Logic/Grading")

describe("Grading", function()
	it("floors the average of the sub-grades", function()
		local subs = { Corners = 6, Centering = 4, Surface = 7, Edges = 8 }
		expect(Grading.score(subs)).toBe(6.25)
		expect(Grading.grade(subs)).toBe(6)
		expect(Grading.grade({ Corners = 10, Centering = 10, Surface = 10, Edges = 10 })).toBe(10)
		expect(Grading.label(10)).toBe("GEM MINT")
	end)

	it("rolls every sub-grade within 1..10", function()
		math.randomseed(3)
		for _ = 1, 500 do
			local subs = Grading.rollSubGrades()
			for _, name in Config.Grading.SubGrades do
				expect(subs[name] >= 1 and subs[name] <= 10).toBe(true)
			end
		end
	end)

	it("prices grading from the card's sale value", function()
		local def = Config.Cards.List[1]
		local c = Config.Grading.Cost
		expect(Grading.cost(def)).toBe(math.floor(c.BaseCost + def.BaseSaleValue * c.SaleValueFactor))
	end)
end)
