local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local ProfileSchema = Loader.require("src/shared/Data/ProfileSchema")

describe("ProfileSchema", function()
	it("creates independent default tables", function()
		local a, b = ProfileSchema.defaults(), ProfileSchema.defaults()
		a.Currency.Cash = 5
		expect(b.Currency.Cash).toBe(0)
		expect(a.SchemaVersion).toBe(ProfileSchema.VERSION)
		expect(a.Flags.StarterGranted).toBe(false)
	end)

	it("reconcile fills missing fields without overwriting existing ones", function()
		local data = ProfileSchema.defaults()
		data.Currency.Cash = 1234
		data.Settings = { MusicVolume = 0.1 }
		data.Stats = nil
		data.Cards["7-1"] = { CardId = "x" }
		local repaired = ProfileSchema.reconcile(data)
		expect(#repaired).toBe(0)
		expect(data.Currency.Cash).toBe(1234)
		expect(data.Settings.MusicVolume).toBe(0.1)
		expect(data.Settings.SfxVolume).toBe(0.8)
		expect(data.Stats.PacksOpened).toBe(0)
		expect(data.Cards["7-1"].CardId).toBe("x")
	end)

	it("reconcile resets and reports fields with the wrong type", function()
		local data = ProfileSchema.defaults()
		data.Currency = "corrupt"
		data.Progression.Level = "nine"
		local repaired = ProfileSchema.reconcile(data)
		table.sort(repaired)
		expect(repaired).toEqual({ "Currency", "Progression.Level" })
		expect(data.Currency.Cash).toBe(0)
		expect(data.Progression.Level).toBe(1)
	end)

	it("migrate rejects non-tables, missing versions and newer data", function()
		expect((ProfileSchema.migrate(nil))).toBe(false)
		expect((ProfileSchema.migrate({ Currency = {} }))).toBe(false)
		local ok, reason = ProfileSchema.migrate({ SchemaVersion = ProfileSchema.VERSION + 1 })
		expect(ok).toBe(false)
		expect(string.find(reason, "newer", 1, true) ~= nil).toBe(true)
	end)

	it("migrate applies steps in order and stamps each version", function()
		local seen = {}
		local migrations = {
			[1] = function(d)
				table.insert(seen, 1)
				d.Renamed = d.Old
				d.Old = nil
				return d
			end,
			[2] = function(d)
				table.insert(seen, 2)
				d.Added = true
				return d
			end,
		}
		local original = { SchemaVersion = 1, Old = "value" }
		local ok, data = ProfileSchema.migrate(original, migrations, 3)
		expect(ok).toBe(true)
		expect(seen).toEqual({ 1, 2 })
		expect(data.SchemaVersion).toBe(3)
		expect(data.Renamed).toBe("value")
		expect(data.Added).toBe(true)
		-- The input is never mutated, so a failed load leaves the caller's copy intact.
		expect(original.Old).toBe("value")
	end)

	it("migrate fails cleanly when a step is missing or errors", function()
		local ok1 = ProfileSchema.migrate({ SchemaVersion = 1 }, {}, 2)
		expect(ok1).toBe(false)
		local ok2, reason = ProfileSchema.migrate({ SchemaVersion = 1 }, {
			[1] = function()
				error("boom")
			end,
		}, 2)
		expect(ok2).toBe(false)
		expect(string.find(reason, "boom", 1, true) ~= nil).toBe(true)
	end)

	it("adds the Packs and Income fields to existing v1 profiles without a version bump", function()
		local old = ProfileSchema.defaults()
		old.Packs = nil
		old.Income = nil
		old.Currency.Cash = 77
		local ok, data = ProfileSchema.migrate(old)
		expect(ok).toBe(true)
		expect(data.SchemaVersion).toBe(1)
		expect(next(data.Packs)).toBeNil()
		expect(data.Income.LastOnline).toBe(0)
		expect(next(data.Income.Pending)).toBeNil()
		expect(data.Currency.Cash).toBe(77)
	end)

	it("migrates current-version data by reconciling it", function()
		local ok, data = ProfileSchema.migrate({ SchemaVersion = ProfileSchema.VERSION, Currency = { Cash = 9 } })
		expect(ok).toBe(true)
		expect(data.Currency.Cash).toBe(9)
		expect(data.Currency.Treats).toBe(0)
		expect(data.Flags.StarterGranted).toBe(false)
	end)
end)
