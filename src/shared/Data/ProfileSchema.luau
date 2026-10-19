--!strict
-- Player data schema: defaults, versioned migrations and reconciliation.
--
-- Rules:
--   * Bump VERSION whenever the saved shape changes, and add MIGRATIONS[oldVersion].
--   * Migrations must be pure functions of the old data. Never drop fields you cannot rebuild.
--   * Data saved by a NEWER version than this server knows is rejected, never overwritten.
local Types = require(script.Parent.Parent.Types)
local Validate = require(script.Parent.Parent.Util.Validate)

local ProfileSchema = {}

ProfileSchema.VERSION = 1

-- MIGRATIONS[n] upgrades data from version n to n + 1.
ProfileSchema.MIGRATIONS = {} :: { [number]: (data: any) -> any }

function ProfileSchema.defaults(): Types.PlayerData
	return {
		SchemaVersion = ProfileSchema.VERSION,
		-- Starting currency is granted by Account.grantStarter (once), not by defaults.
		Currency = { Cash = 0, Treats = 0 },
		Cards = {},
		NextCardSerial = 1,
		Discovered = {},
		Packs = {},
		Display = {},
		Income = { LastOnline = 0, Pending = {} },
		Upgrades = {},
		Collections = { Claimed = {} },
		Quests = { Active = {}, Completed = {} },
		DailyRewards = { LastClaimDay = 0, Streak = 0 },
		Settings = {
			MusicVolume = 0.5,
			SfxVolume = 0.8,
			Notifications = true,
			ReducedMotion = false,
		},
		Progression = { Level = 1, Xp = 0 },
		Stats = {
			PacksOpened = 0,
			CardsObtained = 0,
			CardsSold = 0,
			CashEarned = 0,
			CashSpent = 0,
			PlayTimeSeconds = 0,
			Joins = 0,
			FirstJoin = 0,
			LastJoin = 0,
		},
		Flags = { StarterGranted = false },
		Purchases = { Receipts = {}, Entitlements = {} },
	}
end

-- Validators for each player-editable setting. Keys not listed here cannot be changed.
ProfileSchema.SETTINGS = {
	MusicVolume = Validate.number(0, 1),
	SfxVolume = Validate.number(0, 1),
	Notifications = Validate.boolean(),
	ReducedMotion = Validate.boolean(),
} :: { [string]: Validate.Checker }

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value :: any do
		out[k] = deepCopy(v)
	end
	return out :: any
end
ProfileSchema.deepCopy = deepCopy

-- Fills fields missing from `data` with defaults, without touching existing values.
-- Records (non-empty default tables) are reconciled recursively; maps (empty default tables
-- such as Cards) are left as they are. A field whose type no longer matches is reset and
-- reported, so the caller can log it.
function ProfileSchema.reconcile(data: { [string]: any }, defaults: { [string]: any }?, path: string?): { string }
	local template = defaults or (ProfileSchema.defaults() :: any)
	local repaired: { string } = {}
	for key, default in template :: { [string]: any } do
		local fieldPath = if path then `{path}.{key}` else key
		local current = data[key]
		if current == nil then
			data[key] = deepCopy(default)
		elseif type(current) ~= type(default) then
			data[key] = deepCopy(default)
			table.insert(repaired, fieldPath)
		elseif type(default) == "table" and next(default) ~= nil then
			for _, sub in ProfileSchema.reconcile(current, default, fieldPath) do
				table.insert(repaired, sub)
			end
		end
	end
	return repaired
end

-- Upgrades loaded data to the current version. Returns (true, data, repairedFields) or
-- (false, reason). On failure the caller must NOT fall back to defaults.
function ProfileSchema.migrate(
	data: any,
	migrations: { [number]: (any) -> any }?,
	currentVersion: number?
): (boolean, any, { string }?)
	local target = currentVersion or ProfileSchema.VERSION
	local steps = migrations or ProfileSchema.MIGRATIONS
	if type(data) ~= "table" then
		return false, "data is not a table"
	end
	local version = data.SchemaVersion
	if type(version) ~= "number" or version % 1 ~= 0 or version < 0 then
		return false, "missing or invalid SchemaVersion"
	end
	if version > target then
		return false, `data version {version} is newer than server version {target}`
	end
	local migrated = data
	while migrated.SchemaVersion < target do
		local from = migrated.SchemaVersion
		local step = steps[from]
		if not step then
			return false, `no migration from version {from}`
		end
		local ok, result = pcall(step, deepCopy(migrated))
		if not ok or type(result) ~= "table" then
			return false, `migration from version {from} failed: {result}`
		end
		result.SchemaVersion = from + 1
		migrated = result
	end
	local repaired = if target == ProfileSchema.VERSION then ProfileSchema.reconcile(migrated) else {}
	return true, migrated, repaired
end

return ProfileSchema
