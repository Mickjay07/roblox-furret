--!strict
-- Account-level operations: starter grant, join bookkeeping, settings.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local PackShop = require(script.Parent.PackShop)

local Account = {}

-- Grants starting currency and starter packs exactly once (spec §3.3). The flag is stored in the
-- player's saved data; combined with the session lock this prevents duplicate grants.
function Account.grantStarter(data: Types.PlayerData): boolean
	if data.Flags.StarterGranted then
		return false
	end
	data.Flags.StarterGranted = true
	for currency, amount in Config.Economy.StartingCurrency do
		data.Currency[currency] = (data.Currency[currency] or 0) + amount
	end
	for packId, count in Config.Economy.StarterPacks do
		PackShop.grant(data, packId, count)
	end
	return true
end

function Account.recordJoin(data: Types.PlayerData, now: number)
	data.Stats.Joins = (data.Stats.Joins or 0) + 1
	if (data.Stats.FirstJoin or 0) == 0 then
		data.Stats.FirstJoin = now
	end
	data.Stats.LastJoin = now
end

function Account.addPlayTime(data: Types.PlayerData, seconds: number)
	if seconds > 0 and seconds < 7 * 24 * 3600 then
		data.Stats.PlayTimeSeconds = (data.Stats.PlayTimeSeconds or 0) + math.floor(seconds)
	end
end

function Account.updateSetting(data: Types.PlayerData, key: any, value: any): (boolean, string?)
	if type(key) ~= "string" then
		return false, "invalid setting"
	end
	local validator = ProfileSchema.SETTINGS[key]
	if not validator then
		return false, "unknown setting"
	end
	local ok, reason = validator(value)
	if not ok then
		return false, reason
	end
	data.Settings[key] = value
	return true
end

return Account
