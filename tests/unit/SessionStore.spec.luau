local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local ProfileSchema = Loader.require("src/shared/Data/ProfileSchema")
local SessionStore = Loader.require("src/server/Lib/SessionStore")
local MockDataStore = Loader.require("src/server/Lib/MockDataStore")

local KEY = "Player_1"

-- Builds a SessionStore for one "server" against a shared store with a controllable clock.
local function server(store, jobId: string, env)
	return SessionStore.new({
		store = store,
		jobId = jobId,
		settings = Config.Game.Data,
		defaults = ProfileSchema.defaults,
		migrate = function(raw)
			return ProfileSchema.migrate(raw)
		end,
		clock = function()
			return env.now
		end,
		wait = function(seconds)
			env.waited += seconds
			env.now += seconds
		end,
		log = function(message)
			table.insert(env.logs, message)
		end,
	})
end

local function newEnv()
	return { now = 1000, waited = 0, logs = {} }
end

describe("SessionStore", function()
	it("creates defaults for a brand-new key and locks it", function()
		local store, env = MockDataStore.new(), newEnv()
		local profile = server(store, "A", env):load(KEY)
		expect(profile ~= nil).toBe(true)
		expect(profile.IsNew).toBe(true)
		expect(profile.Data.SchemaVersion).toBe(ProfileSchema.VERSION)
		expect(store:peek(KEY).Meta.LockJobId).toBe("A")
	end)

	it("loads existing data instead of defaults", function()
		local store, env = MockDataStore.new(), newEnv()
		local data = ProfileSchema.defaults()
		data.Currency.Cash = 777
		store:poke(KEY, { Data = data, Meta = { LockTime = 0, SavedAt = 0, SaveCount = 3 } })
		local profile = server(store, "A", env):load(KEY)
		expect(profile.IsNew).toBe(false)
		expect(profile.Data.Currency.Cash).toBe(777)
	end)

	it("saves changes and releases the lock", function()
		local store, env = MockDataStore.new(), newEnv()
		local a = server(store, "A", env)
		local profile = a:load(KEY)
		profile.Data.Currency.Cash = 50
		expect(a:save(profile)).toBe(true)
		expect(store:peek(KEY).Data.Currency.Cash).toBe(50)
		expect(store:peek(KEY).Meta.LockJobId).toBe("A")
		profile.Data.Currency.Cash = 60
		expect(a:release(profile)).toBe(true)
		local record = store:peek(KEY)
		expect(record.Data.Currency.Cash).toBe(60)
		expect(record.Meta.LockJobId).toBeNil()
		expect(profile.Active).toBe(false)
		-- A released profile can never be written again.
		profile.Data.Currency.Cash = 999
		expect(a:save(profile)).toBe(false)
		expect(store:peek(KEY).Data.Currency.Cash).toBe(60)
	end)

	it("refuses to load a key locked by another live server, without writing", function()
		local store, env = MockDataStore.new(), newEnv()
		server(store, "A", env):load(KEY)
		local writesBefore = store.writes
		local profile, reason = server(store, "B", env):load(KEY)
		expect(profile).toBeNil()
		expect(string.find(reason, "another server", 1, true) ~= nil).toBe(true)
		expect(store.writes).toBe(writesBefore)
		expect(store:peek(KEY).Meta.LockJobId).toBe("A")
		expect(env.waited).toBe(Config.Game.Data.ContestedLockRetries * Config.Game.Data.ContestedLockDelay)
	end)

	it("loads once the other server releases (fast rejoin)", function()
		local store, env = MockDataStore.new(), newEnv()
		local a = server(store, "A", env)
		local profileA = a:load(KEY)
		profileA.Data.Currency.Cash = 5
		a:release(profileA)
		local profileB = server(store, "B", env):load(KEY)
		expect(profileB ~= nil).toBe(true)
		expect(profileB.Data.Currency.Cash).toBe(5)
	end)

	it("takes over a lock that expired (crashed server)", function()
		local store, env = MockDataStore.new(), newEnv()
		server(store, "A", env):load(KEY)
		env.now += Config.Game.Data.LockExpirySeconds + 1
		local profile = server(store, "B", env):load(KEY)
		expect(profile ~= nil).toBe(true)
		expect(store:peek(KEY).Meta.LockJobId).toBe("B")
	end)

	it("a server that lost its lock cannot overwrite the new owner's data", function()
		local store, env = MockDataStore.new(), newEnv()
		local a = server(store, "A", env)
		local profileA = a:load(KEY)
		local lost = false
		profileA.OnLost = function()
			lost = true
		end
		env.now += Config.Game.Data.LockExpirySeconds + 1
		local b = server(store, "B", env)
		local profileB = b:load(KEY)
		profileB.Data.Currency.Cash = 1000
		b:save(profileB)

		profileA.Data.Currency.Cash = 1 -- stale session tries to save
		expect(a:save(profileA)).toBe(false)
		expect(lost).toBe(true)
		expect(profileA.Active).toBe(false)
		expect(store:peek(KEY).Data.Currency.Cash).toBe(1000)
	end)

	it("retries transient DataStore errors", function()
		local store, env = MockDataStore.new(), newEnv()
		store:failNext(Config.Game.Data.LoadRetries - 1)
		local profile = server(store, "A", env):load(KEY)
		expect(profile ~= nil).toBe(true)
		expect(env.waited > 0).toBe(true)
	end)

	it("never falls back to defaults when loading keeps failing", function()
		local store, env = MockDataStore.new(), newEnv()
		local data = ProfileSchema.defaults()
		data.Currency.Cash = 123456
		store:poke(KEY, { Data = data, Meta = { LockTime = 0, SavedAt = 0, SaveCount = 1 } })
		store:failNext(Config.Game.Data.LoadRetries)
		local profile, reason = server(store, "A", env):load(KEY)
		expect(profile).toBeNil()
		expect(string.find(reason, "unavailable", 1, true) ~= nil).toBe(true)
		expect(store:peek(KEY).Data.Currency.Cash).toBe(123456)
	end)

	it("rejects data from a newer schema version and leaves it untouched", function()
		local store, env = MockDataStore.new(), newEnv()
		store:poke(KEY, {
			Data = { SchemaVersion = ProfileSchema.VERSION + 1, Future = true },
			Meta = { LockTime = 0, SavedAt = 0, SaveCount = 1 },
		})
		local profile, reason = server(store, "A", env):load(KEY)
		expect(profile).toBeNil()
		expect(string.find(reason, "rejected", 1, true) ~= nil).toBe(true)
		expect(store:peek(KEY).Data.Future).toBe(true)
		expect(store:peek(KEY).Meta.LockJobId).toBeNil()
	end)

	it("rejects malformed records rather than resetting them", function()
		local store, env = MockDataStore.new(), newEnv()
		store:poke(KEY, "garbage")
		local profile = server(store, "A", env):load(KEY)
		expect(profile).toBeNil()
		expect(store:peek(KEY)).toBe("garbage")
	end)

	it("does not double-load the same key on one server", function()
		local store, env = MockDataStore.new(), newEnv()
		local a = server(store, "A", env)
		expect(a:load(KEY) ~= nil).toBe(true)
		local again, reason = a:load(KEY)
		expect(again).toBeNil()
		expect(string.find(reason, "already active", 1, true) ~= nil).toBe(true)
	end)

	it("reports a failed save without losing the profile", function()
		local store, env = MockDataStore.new(), newEnv()
		local a = server(store, "A", env)
		local profile = a:load(KEY)
		profile.Data.Currency.Cash = 10
		store:failNext(Config.Game.Data.SaveRetries)
		expect(a:save(profile)).toBe(false)
		expect(profile.Active).toBe(true)
		-- Next autosave succeeds.
		expect(a:save(profile)).toBe(true)
		expect(store:peek(KEY).Data.Currency.Cash).toBe(10)
	end)

	it("keeps the starter grant flag across sessions (no duplicate rewards)", function()
		local Account = Loader.require("src/shared/Logic/Account")
		local store, env = MockDataStore.new(), newEnv()
		local a = server(store, "A", env)
		local first = a:load(KEY)
		expect(Account.grantStarter(first.Data)).toBe(true)
		a:release(first)
		local second = server(store, "B", env):load(KEY)
		expect(Account.grantStarter(second.Data)).toBe(false)
		expect(second.Data.Currency.Cash).toBe(Config.Economy.StartingCurrency.Cash)
	end)
end)
