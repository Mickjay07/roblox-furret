local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local Economy = Loader.require("src/shared/Logic/Economy")
local ProfileSchema = Loader.require("src/shared/Data/ProfileSchema")

local function card(cardId, variant, grade)
	return { CardId = cardId, Variant = variant or "Normal", Grade = grade, Obtained = 0, Favorite = false }
end

describe("Economy", function()
	it("applies variant and grade multipliers to card income", function()
		local base = Config.Cards.List[1].BaseIncome
		local id = Config.Cards.List[1].Id
		expect(Economy.cardIncome(card(id))).toBe(base)
		expect(Economy.cardIncome(card(id, "Gold"))).toBe(base * Config.Variants.ById.Gold.IncomeMultiplier)
		expect(Economy.cardIncome(card(id, "Normal", 10))).toBe(base * Config.Grading.Multipliers[10])
		expect(Economy.cardIncome(card("missing"))).toBe(0)
	end)

	it("only counts cards in unlocked display slots", function()
		local data = ProfileSchema.defaults()
		data.Cards["1-1"] = card("burrow_sable_scout")
		data.Cards["1-2"] = card("burrow_burrow_boss")
		data.Display["1"] = "1-1"
		data.Display["99"] = "1-2" -- beyond the slot count: ignored
		data.Display["2"] = "1-404" -- not owned: ignored
		expect(Economy.totalIncome(data)).toBe(1)
	end)

	it("adds upgrade and collection bonuses to the income multiplier", function()
		local data = ProfileSchema.defaults()
		data.Upgrades.IncomeBoost = 3
		expect(Economy.incomeMultiplier(data)).toBeNear(1.3, 1e-9)
		for _, def in Config.Cards.List do
			if def.Collection == "Burrow" then
				data.Discovered[def.Id] = { First = 0, Count = 1, Variants = {} }
			end
		end
		expect(Economy.incomeMultiplier(data)).toBeNear(1.35, 1e-9)
		expect(Economy.incomeMultiplier(data, 2)).toBeNear(2.7, 1e-9)
	end)

	it("grows upgrade costs geometrically and stops at max level", function()
		local def = Config.Upgrades.ById.DisplaySlots
		expect(Economy.upgradeCost(def, 0)).toBe(def.BaseCost)
		expect(Economy.upgradeCost(def, 2)).toBe(math.floor(def.BaseCost * def.CostGrowth ^ 2))
		expect(Economy.upgradeCost(def, def.MaxLevel)).toBeNil()
	end)

	it("derives slots, capacity and luck from upgrades", function()
		local data = ProfileSchema.defaults()
		expect(Economy.displaySlotCount(data)).toBe(Config.Game.Display.BaseSlots)
		data.Upgrades.DisplaySlots = 2
		data.Upgrades.BackpackSpace = 1
		data.Upgrades.Luck = 4
		expect(Economy.displaySlotCount(data)).toBe(Config.Game.Display.BaseSlots + 2)
		expect(Economy.backpackCapacity(data)).toBe(Config.Game.Backpack.BaseCapacity + 50)
		expect(Economy.luck(data)).toBeNear(0.2, 1e-9)
	end)

	it("includes the sell bonus in sale value and floors it", function()
		local data = ProfileSchema.defaults()
		local def = Config.Cards.List[1]
		expect(Economy.cardSaleValue(data, card(def.Id))).toBe(def.BaseSaleValue)
		data.Upgrades.SellBonus = 1
		expect(Economy.cardSaleValue(data, card(def.Id))).toBe(math.floor(def.BaseSaleValue * 1.08))
	end)
end)
