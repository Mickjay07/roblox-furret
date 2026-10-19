-- Card income audit: the income printed on each card's artwork is the card's base income per
-- second, and every income number in the game (card tiles, stands, CASH/S, stand earnings,
-- Collect All) derives from it through the single formula in Logic/Economy:
--   card income  = BaseIncome x VariantMultiplier x GradeMultiplier
--   stand income = card income x player multiplier (upgrades + completed collections)
local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local ProfileSchema = Loader.require("src/shared/Data/ProfileSchema")
local Inventory = Loader.require("src/shared/Logic/Inventory")
local Economy = Loader.require("src/shared/Logic/Economy")
local IncomeLedger = Loader.require("src/shared/Logic/IncomeLedger")
local PlotView = Loader.require("src/shared/Logic/PlotView")
local Format = Loader.require("src/shared/Util/Format")

-- Read from the artwork (assets/source/Pack 1): the "+N/s" printed on each Normal card.
local PRINTED = {
	pack1_sandy = 70,
	pack1_boba = 118,
	pack1_sky = 420,
	pack1_kingston = 750,
	pack1_aurora = 1200,
	pack1_frost = 1500,
}
local ORDER = { "pack1_sandy", "pack1_boba", "pack1_sky", "pack1_kingston", "pack1_aurora", "pack1_frost" }

local function instance(cardId: string, variant: string?, grade: number?)
	return { CardId = cardId, Variant = variant or "Normal", Grade = grade, Obtained = 0, Favorite = false }
end

-- A player with all six Pack 1 cards on stands 1-6 (2 extra stands unlocked). Owning every
-- Pack 1 card completes the Pack 1 collection, so its income bonus applies.
local function fullPack1Display(variants: { [string]: string }?)
	local data = ProfileSchema.defaults()
	data.Upgrades.DisplaySlots = 2
	for slot, cardId in ORDER do
		local variant = if variants then variants[cardId] else nil
		data.Display[tostring(slot)] = Inventory.add(data, 1, cardId, variant or "Normal", 0)
	end
	return data
end

describe("Card income matches the artwork", function()
	it("configures every Pack 1 card's BaseIncome as the income printed on its art", function()
		local count = 0
		for _, def in Config.Cards.List do
			if def.Collection == "Pack1" then
				count += 1
				expect(PRINTED[def.Id] ~= nil).toBe(true)
				expect(def.BaseIncome).toBe(PRINTED[def.Id])
			end
		end
		expect(count).toBe(6)
	end)

	it("gives a Normal copy exactly the printed income", function()
		for cardId, printed in PRINTED do
			expect(Economy.cardIncome(instance(cardId))).toBe(printed)
		end
	end)
end)

describe("Variant income is applied once", function()
	it("multiplies the printed (Normal) income by the variant multiplier exactly once", function()
		local shiny = Config.Variants.ById.Shiny.IncomeMultiplier
		-- Owner decision: Shiny earns 2% more than the Normal card.
		expect(shiny).toBe(1.02)
		for cardId, printed in PRINTED do
			expect(Economy.cardIncome(instance(cardId, "Shiny"))).toBe(printed * shiny)
			for _, variant in Config.Variants.List do
				expect(Economy.cardIncome(instance(cardId, variant.Id))).toBe(printed * variant.IncomeMultiplier)
			end
		end
		-- Sandy Shiny earns 71.4/s (+2%), not 70 x 1.02 x 1.02 = 72.828/s.
		expect(Economy.cardIncome(instance("pack1_sandy", "Shiny"))).toBeNear(71.4, 1e-9)
	end)

	it("accrues a Shiny stand at printed + 2% per second, with no second multiplier", function()
		local data = ProfileSchema.defaults()
		data.Display["1"] = Inventory.add(data, 1, "pack1_boba", "Shiny", 0)
		expect(IncomeLedger.standIncome(data, "1")).toBeNear(120.36, 1e-9)
		IncomeLedger.accrue(data, 10)
		expect(IncomeLedger.pending(data, "1")).toBeNear(1203.6, 1e-9)
		expect(Economy.totalIncome(data)).toBeNear(120.36, 1e-9)
	end)

	it("applies grade on top of the variant, once each", function()
		local grade10 = Config.Grading.Multipliers[10]
		expect(Economy.cardIncome(instance("pack1_sky", "Shiny", 10))).toBeNear(420 * 1.02 * grade10, 1e-9)
	end)

	it("publishes the same card income on the physical stands", function()
		local data = fullPack1Display({ pack1_sandy = "Shiny", pack1_frost = "Gold" })
		local states = PlotView.standStates(data, 12)
		for slot, cardId in ORDER do
			local state = states[slot]
			expect(state.CardId).toBe(cardId)
			expect(state.CardIncome).toBe(Economy.cardIncome(data.Cards[data.Display[tostring(slot)]]))
		end
		expect(states[1].CardIncome).toBeNear(71.4, 1e-9)
		expect(states[2].CardIncome).toBe(118)
		expect(states[6].CardIncome).toBe(1500 * Config.Variants.ById.Gold.IncomeMultiplier)
		expect(states[7].CardIncome).toBeNil()
	end)
end)

describe("Variant bonus tag", function()
	it("shows Shiny as +2% above the printed income on every Pack 1 card", function()
		for cardId, printed in PRINTED do
			local income = Economy.cardIncome(instance(cardId, "Shiny"))
			expect(Format.bonusPercent(income, printed)).toBe("+2%")
			expect(Format.bonusPercent(Economy.cardIncome(instance(cardId)), printed)).toBeNil()
		end
	end)

	it("formats other bonuses and keeps Shiny's sale value multiplier", function()
		expect(Format.bonusPercent(70 * 3, 70)).toBe("+200%")
		expect(Format.bonusPercent(70 * 1.025, 70)).toBe("+2.5%")
		expect(Format.bonusPercent(70, 70)).toBeNil()
		expect(Format.bonusPercent(5, 0)).toBeNil()
		expect(Config.Variants.ById.Shiny.SaleMultiplier).toBe(1.5)
	end)
end)

describe("Total CASH/S", function()
	it("equals the sum of the printed incomes of the placed cards, times the intended bonuses", function()
		local data = fullPack1Display()
		local printedSum = 0
		for _, printed in PRINTED do
			printedSum += printed
		end
		expect(printedSum).toBe(4058)
		-- Owning all six completes Pack 1: its configured completion bonus is the only bonus.
		local bonus = Config.Collections.ById.Pack1.CompletionIncomeBonus
		expect(Economy.incomeMultiplier(data)).toBeNear(1 + bonus, 1e-12)
		expect(Economy.totalIncome(data)).toBeNear(printedSum * (1 + bonus), 1e-9)
	end)

	it("equals the sum of every stand's income, with variants and upgrades", function()
		local data = fullPack1Display({ pack1_sandy = "Shiny", pack1_sky = "Holo" })
		data.Upgrades.IncomeBoost = 3
		local standSum = 0
		for slot = 1, 12 do
			standSum += IncomeLedger.standIncome(data, tostring(slot))
		end
		expect(Economy.totalIncome(data)).toBeNear(standSum, 1e-9)
		local cardSum = 70 * 1.02 + 118 + 420 * Config.Variants.ById.Holo.IncomeMultiplier + 750 + 1200 + 1500
		local multiplier = 1 + 0.3 + Config.Collections.ById.Pack1.CompletionIncomeBonus
		expect(Economy.totalIncome(data)).toBeNear(cardSum * multiplier, 1e-9)
	end)

	it("excludes cards on locked stands and counts nothing for empty stands", function()
		local data = ProfileSchema.defaults() -- 4 stands unlocked
		data.Display["1"] = Inventory.add(data, 1, "pack1_sandy", "Normal", 0)
		data.Display["5"] = Inventory.add(data, 1, "pack1_frost", "Normal", 0) -- locked stand
		expect(Economy.totalIncome(data)).toBe(70)
		expect(IncomeLedger.standIncome(data, "5")).toBe(0)
		expect(IncomeLedger.standIncome(data, "2")).toBe(0)
	end)
end)

describe("Stand earnings and Collect All", function()
	it("accrues each stand at its own income and Collect All pays their sum once", function()
		local data = fullPack1Display({ pack1_kingston = "Shiny" })
		local cashBefore = data.Currency.Cash
		local seconds = 60
		IncomeLedger.accrue(data, seconds)
		local expectedTotal = 0
		for slot = 1, 6 do
			local key = tostring(slot)
			local perSecond = IncomeLedger.standIncome(data, key)
			expect(IncomeLedger.pending(data, key)).toBeNear(perSecond * seconds, 1e-9)
			expectedTotal += math.floor(IncomeLedger.pending(data, key))
		end
		expect(IncomeLedger.pendingTotal(data)).toBeNear(Economy.totalIncome(data) * seconds, 1e-6)
		local collected = IncomeLedger.collectAll(data)
		expect(collected).toBe(expectedTotal)
		expect(data.Currency.Cash).toBe(cashBefore + expectedTotal)
		expect(IncomeLedger.collectAll(data)).toBe(0)
	end)

	it("collecting stands one by one pays the same as Collect All", function()
		local a = fullPack1Display({ pack1_sandy = "Shiny" })
		local b = fullPack1Display({ pack1_sandy = "Shiny" })
		IncomeLedger.accrue(a, 37)
		IncomeLedger.accrue(b, 37)
		local single = 0
		for slot = 1, 8 do
			single += IncomeLedger.collect(a, tostring(slot))
		end
		expect(single).toBe(IncomeLedger.collectAll(b))
		expect(a.Currency.Cash).toBe(b.Currency.Cash)
	end)

	it("caps a stand at StandCapSeconds of its own (variant-adjusted) income", function()
		local data = ProfileSchema.defaults()
		data.Display["1"] = Inventory.add(data, 1, "pack1_sandy", "Shiny", 0)
		local cap = Config.Economy.Income.StandCapSeconds
		IncomeLedger.accrue(data, cap * 3)
		expect(IncomeLedger.pending(data, "1")).toBeNear(70 * 1.02 * cap, 1e-6)
	end)
end)
