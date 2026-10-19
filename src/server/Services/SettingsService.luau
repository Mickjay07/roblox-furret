--!strict
-- Player settings (volumes, notifications, reduced motion). Only keys with a validator in
-- ProfileSchema.SETTINGS can be changed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Account = require(Shared.Logic.Account)
local Validate = require(Shared.Util.Validate)

local Net = require(script.Parent.Parent.Lib.Net)
local DataService = require(script.Parent.DataService)

local SettingsService = {}

function SettingsService:Start()
	Net.onInvoke(Remotes.Functions.UpdateSetting, {
		Validate.id(Config.Game.Limits.MaxIdLength),
		function(value)
			local t = type(value)
			return t == "boolean" or t == "number", "unsupported value type"
		end,
	}, function(player, key, value)
		local data = DataService:GetData(player)
		if not data then
			return { ok = false, error = "Data not loaded" }
		end
		local ok, reason = Account.updateSetting(data, key, value)
		if not ok then
			return { ok = false, error = reason or "Invalid setting" }
		end
		DataService:Changed(player, "Settings")
		return { ok = true }
	end)
end

return SettingsService
