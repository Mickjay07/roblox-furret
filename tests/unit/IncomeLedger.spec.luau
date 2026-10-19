local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local ProfileSchema = Loader.require("src/shared/Data/ProfileSchema")
local Inventory = Loader.require("src/shared/Logic/Inventory")
local IncomeLedger = Loader.require("src/shared/Logic/IncomeLedger")
local Economy = Loader.require("src/shared/Logic/Economy")

-- Player with a 1/s card on stand 1 and a 15/s card on stand 2.
local function setup()
	local data = ProfileSchema.defaults()
	data.Display["1"] = Inventory.add(data, 1, "burrow_sable_scout", "Normal", 0)
	data.Display["2"] = Inventory.add(data, 1, "burrow_burrow_boss", "Normal", 0)
	return data
end

describe("IncomeLedger", function()
	it("accrues each stand's effective income onto that stand, not into Cash", function()
		local data = setup()
		expect(IncomeLedger.accrue(data, 10)).toBe(160)
		expect(IncomeLedger.pending(data, "1")).toBe(10)
		expect(IncomeLedger.pending(data, "2")).toBe(150)
		expect(data.Currency.Cash).toBe(0)
		expect(IncomeLedger.pendingTotal(data)).toBe(160)
	end)

	it("uses the same multipliers as the central income formula", function()
		local data = setup()
		data.Upgrades.IncomeBoost = 2
		IncomeLedger.accrue(data, 1)
		expect(IncomeLedger.pendingTotal(data)).toBeNear(Economy.totalIncome(data), 1e-9)
		IncomeLedger.accrue(data, 1, 2)
		expect(IncomeLedger.pendingTotal(data)).toBeNear(Economy.totalIncome(data) * 3, 1e-9)
	end)

	it("ignores empty and locked stands", function()
		local data = setup()
		data.Display["99"] = Inventory.add(data, 1, "burrow_burrow_boss", "Normal", 0)
		IncomeLedger.accrue(data, 10)
		expect(IncomeLedger.pending(data, "99")).toBe(0)
		expect(IncomeLedger.accrue(data, 0)).toBe(0)
		expect(IncomeLedger.accrue(data, -5)).toBe(0)
		expect(IncomeLedger.accrue(data, 0 / 0)).toBe(0)
	end)

	it("caps each stand at StandCapSeconds of its income", function()
		local data = setup()
		local cap = Config.Economy.Income.StandCapSeconds
		IncomeLedger.accrue(data, cap * 10)
		expect(IncomeLedger.pending(data, "1")).toBe(cap * 1)
		expect(IncomeLedger.accrue(data, 100)).toBe(0)
	end)

	it("collects one stand, and collecting again pays nothing", function()
		local data = setup()
		IncomeLedger.accrue(data, 10)
		expect(IncomeLedger.collect(data, "2")).toBe(150)
		expect(data.Currency.Cash).toBe(150)
		expect(IncomeLedger.collect(data, "2")).toBe(0)
		expect(data.Currency.Cash).toBe(150)
		expect(IncomeLedger.pending(data, "1")).toBe(10)
	end)

	it("collects all stands centrally exactly once", function()
		local data = setup()
		IncomeLedger.accrue(data, 10)
		expect(IncomeLedger.collectAll(data)).toBe(160)
		expect(IncomeLedger.collectAll(data)).toBe(0)
		expect(data.Currency.Cash).toBe(160)
		expect(data.Stats.CashEarned).toBe(160)
	end)

	it("pays whole cash and keeps the fractional remainder on the stand", function()
		local data = setup()
		data.Upgrades.IncomeBoost = 1 -- x1.1
		IncomeLedger.accrue(data, 1)
		expect(IncomeLedger.collect(data, "1")).toBe(1)
		expect(IncomeLedger.pending(data, "1")).toBeNear(0.1, 1e-9)
	end)

	it("keeps a stand's earnings when its card is removed", function()
		local data = setup()
		IncomeLedger.accrue(data, 10)
		data.Display["2"] = nil
		expect(IncomeLedger.pending(data, "2")).toBe(150)
		expect(IncomeLedger.collect(data, "2")).toBe(150)
	end)

	it("awards capped offline earnings onto the stands from the saved timestamp", function()
		local data = setup()
		local settings = Config.Economy.Income
		IncomeLedger.markOnline(data, 1000)
		local added, seconds = IncomeLedger.applyOffline(data, 1000 + 60)
		expect(seconds).toBe(60)
		expect(added).toBe(16 * 60 * settings.OfflineRate)
		expect(data.Currency.Cash).toBe(0)

		local data2 = setup()
		IncomeLedger.markOnline(data2, 1000)
		local _, counted = IncomeLedger.applyOffline(data2, 1000 + settings.OfflineCapSeconds * 5)
		expect(counted).toBe(settings.OfflineCapSeconds)
	end)

	it("awards nothing for a first join, a clock in the past, or no stands", function()
		local data = setup()
		expect((IncomeLedger.applyOffline(data, 5000))).toBe(0) -- LastOnline = 0
		IncomeLedger.markOnline(data, 5000)
		expect((IncomeLedger.applyOffline(data, 4000))).toBe(0)
		local empty = ProfileSchema.defaults()
		IncomeLedger.markOnline(empty, 1)
		expect((IncomeLedger.applyOffline(empty, 100000))).toBe(0)
	end)

	it("does not double-count after a crash when LastOnline is kept current", function()
		-- The server updates LastOnline every tick, so a saved profile's timestamp always
		-- matches its saved earnings: offline time starts where the saved state ends.
		local data = setup()
		IncomeLedger.markOnline(data, 1000)
		IncomeLedger.accrue(data, 30)
		IncomeLedger.markOnline(data, 1030)
		local saved = ProfileSchema.deepCopy(data)
		local added = IncomeLedger.applyOffline(saved, 1030 + 10)
		expect(added).toBe(16 * 10 * Config.Economy.Income.OfflineRate)
	end)

	it("sanitize drops invalid amounts and pays out earnings on stands that no longer exist", function()
		local data = setup()
		data.Income.Pending["1"] = 5
		data.Income.Pending["50"] = 42.7
		data.Income.Pending["x"] = 3
		data.Income.Pending["2"] = 0 / 0
		expect(IncomeLedger.sanitize(data)).toBe(true)
		expect(IncomeLedger.pending(data, "1")).toBe(5)
		expect(data.Income.Pending["50"]).toBeNil()
		expect(data.Income.Pending["2"]).toBeNil()
		expect(data.Currency.Cash).toBe(42 + 3)
		expect(IncomeLedger.sanitize(data)).toBe(false)
	end)
end)
