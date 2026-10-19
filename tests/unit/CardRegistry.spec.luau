local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local CardRegistry = Loader.require("src/shared/Logic/CardRegistry")

describe("CardRegistry", function()
	it("looks up cards by id", function()
		local def = CardRegistry.get("burrow_sable_scout")
		expect(def ~= nil).toBe(true)
		expect(def.Name).toBe("Sable Scout")
		expect(CardRegistry.get("nope")).toBeNil()
	end)

	it("exists() rejects non-strings and unknown ids", function()
		expect(CardRegistry.exists("burrow_sable_scout")).toBe(true)
		expect(CardRegistry.exists(42)).toBe(false)
		expect(CardRegistry.exists(nil)).toBe(false)
		expect(CardRegistry.exists("burrow_sable_scout ")).toBe(false)
	end)

	it("returns collection cards sorted by collection number", function()
		local cards = CardRegistry.inCollection("Burrow")
		expect(#cards).toBe(6)
		for i, def in cards do
			expect(def.CollectionNumber).toBe(i)
		end
	end)

	it("allows every defined variant when Variants is nil", function()
		local def = CardRegistry.get("burrow_sable_scout")
		expect(CardRegistry.allowsVariant(def, "Normal")).toBe(true)
		expect(CardRegistry.allowsVariant(def, "Rainbow")).toBe(true)
		expect(CardRegistry.allowsVariant(def, "Plaid")).toBe(false)
	end)
end)
