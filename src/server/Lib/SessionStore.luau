--!strict
-- Session-locked player profiles on top of a DataStore-like object.
--
-- Guarantees:
--   * A profile is only ever written by the server holding its session lock. Saves check the
--     lock inside UpdateAsync, so a server that lost the lock can never overwrite newer data.
--   * A failed or contested load NEVER produces default data. The caller gets (nil, reason)
--     and must not let the player play (kick them).
--   * Defaults are only created when the key genuinely has no record yet.
--   * Data saved by a newer schema version is rejected rather than downgraded.
--
-- Dependencies are injected so the logic is unit-testable with MockDataStore under Lune.
--
-- Record layout in the DataStore:
--   { Data = <PlayerData>, Meta = { LockJobId = string?, LockTime = number,
--     SavedAt = number, SaveCount = number } }

export type StoreLike = {
	UpdateAsync: (self: any, key: string, transform: (any, any) -> any) -> any,
}

export type Settings = {
	LockExpirySeconds: number,
	LoadRetries: number,
	SaveRetries: number,
	RetryBaseDelay: number,
	ContestedLockRetries: number,
	ContestedLockDelay: number,
}

export type Deps = {
	store: StoreLike,
	jobId: string,
	settings: Settings,
	defaults: () -> any,
	-- (ok, migratedData, repairedFields?) or (false, reason)
	migrate: (raw: any) -> (boolean, any, { string }?),
	clock: (() -> number)?,
	wait: ((seconds: number) -> ())?,
	log: ((message: string) -> ())?,
}

export type Profile = {
	Key: string,
	Data: any,
	IsNew: boolean,
	-- False once released or once the lock was lost; a dead profile is never saved again.
	Active: boolean,
	LoadedAt: number,
	-- Called once if a save discovers another server took the lock.
	OnLost: (() -> ())?,
}

export type SessionStore = {
	load: (self: SessionStore, key: string) -> (Profile?, string?),
	save: (self: SessionStore, profile: Profile) -> boolean,
	release: (self: SessionStore, profile: Profile) -> boolean,
	isActive: (self: SessionStore, key: string) -> boolean,
	pendingCount: (self: SessionStore) -> number,
}

local SessionStore = {}

function SessionStore.new(deps: Deps): SessionStore
	local settings = deps.settings
	local clock: () -> number = deps.clock or function()
		return os.time()
	end
	local wait: (number) -> () = deps.wait or function(_: number) end
	local log: (string) -> () = deps.log or function(_: string) end

	local active: { [string]: Profile } = {}
	local busy: { [string]: boolean } = {}
	local pending = 0

	-- Serializes operations per key so saves and releases never interleave. Passes through
	-- every return value of `fn`.
	local function withKey(key: string, fn: () -> ...any): ...any
		while busy[key] do
			wait(0.1)
		end
		busy[key] = true
		pending += 1
		local results = table.pack(pcall(fn))
		busy[key] = nil
		pending -= 1
		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end

	-- UpdateAsync with exponential backoff. Returns (true, result) or (false, error).
	local function update(key: string, transform: (any) -> any, attempts: number): (boolean, any)
		local lastError: any = nil
		for attempt = 1, attempts do
			local ok, result = pcall(function()
				return deps.store:UpdateAsync(key, function(old)
					return transform(old)
				end)
			end)
			if ok then
				return true, result
			end
			lastError = result
			log(`[SessionStore] UpdateAsync {key} failed (attempt {attempt}/{attempts}): {result}`)
			if attempt < attempts then
				wait(settings.RetryBaseDelay * 2 ^ (attempt - 1))
			end
		end
		return false, lastError
	end

	local self = {}

	function self.load(_, key: string): (Profile?, string?)
		if active[key] then
			return nil, "profile already active on this server"
		end
		return withKey(key, function(): (Profile?, string?)
			if active[key] then
				return nil, "profile already active on this server"
			end
			for attempt = 1, settings.ContestedLockRetries + 1 do
				-- Outcome of the last transform run (UpdateAsync may run it more than once).
				local outcome: string = "none"
				local reason: string? = nil
				local loaded: any = nil
				local isNew = false

				local ok, err = update(key, function(old)
					local now = clock()
					if old == nil then
						outcome, isNew = "ok", true
						loaded = deps.defaults()
						return {
							Data = loaded,
							Meta = { LockJobId = deps.jobId, LockTime = now, SavedAt = now, SaveCount = 0 },
						}
					end
					if type(old) ~= "table" or type(old.Meta) ~= "table" then
						outcome, reason = "invalid", "record is malformed"
						return nil
					end
					local lockOwner = old.Meta.LockJobId
					local lockTime = tonumber(old.Meta.LockTime) or 0
					if lockOwner ~= nil and lockOwner ~= deps.jobId and now - lockTime < settings.LockExpirySeconds then
						outcome = "locked"
						return nil
					end
					local migrated, data, repaired = deps.migrate(old.Data)
					if not migrated then
						outcome, reason = "invalid", tostring(data)
						return nil
					end
					if repaired and #repaired > 0 then
						log(`[SessionStore] {key}: reset malformed fields {table.concat(repaired, ", ")}`)
					end
					if lockOwner ~= nil and lockOwner ~= deps.jobId then
						log(`[SessionStore] {key}: taking over expired lock from {lockOwner}`)
					end
					outcome, isNew, loaded = "ok", false, data
					old.Data = data
					old.Meta.LockJobId = deps.jobId
					old.Meta.LockTime = now
					return old
				end, settings.LoadRetries)

				if not ok then
					return nil, `data store unavailable: {err}`
				elseif outcome == "invalid" then
					return nil, `saved data rejected: {reason}`
				elseif outcome == "ok" then
					local profile: Profile = {
						Key = key,
						Data = loaded,
						IsNew = isNew,
						Active = true,
						LoadedAt = clock(),
						OnLost = nil,
					}
					active[key] = profile
					return profile, nil
				end
				-- Locked by another live session: give it time to release (e.g. fast rejoin).
				if attempt <= settings.ContestedLockRetries then
					log(`[SessionStore] {key} is locked by another server, retrying`)
					wait(settings.ContestedLockDelay)
				end
			end
			return nil, "data is in use on another server"
		end)
	end

	local function write(profile: Profile, releaseLock: boolean): boolean
		if not profile.Active then
			return false
		end
		local lost = false
		local ok, err = update(profile.Key, function(old)
			local now = clock()
			if type(old) ~= "table" or type(old.Meta) ~= "table" or old.Meta.LockJobId ~= deps.jobId then
				lost = true
				return nil
			end
			lost = false
			return {
				Data = profile.Data,
				Meta = {
					LockJobId = if releaseLock then nil else deps.jobId,
					LockTime = now,
					SavedAt = now,
					SaveCount = (tonumber(old.Meta.SaveCount) or 0) + 1,
				},
			}
		end, settings.SaveRetries)

		if ok and lost then
			log(`[SessionStore] {profile.Key}: session lock lost; discarding this session's changes`)
			profile.Active = false
			active[profile.Key] = nil
			if profile.OnLost then
				profile.OnLost()
			end
			return false
		elseif not ok then
			log(`[SessionStore] {profile.Key}: save failed: {err}`)
			return false
		end
		return true
	end

	function self.save(_, profile: Profile): boolean
		return withKey(profile.Key, function()
			return write(profile, false)
		end)
	end

	-- Final save that also releases the lock. The profile is dead afterwards either way.
	function self.release(_, profile: Profile): boolean
		return withKey(profile.Key, function()
			if not profile.Active then
				return false
			end
			local ok = write(profile, true)
			profile.Active = false
			if active[profile.Key] == profile then
				active[profile.Key] = nil
			end
			return ok
		end)
	end

	function self.isActive(_, key: string): boolean
		return active[key] ~= nil
	end

	function self.pendingCount(_): number
		return pending
	end

	return (self :: any) :: SessionStore
end

return SessionStore
