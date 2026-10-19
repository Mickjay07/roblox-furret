--!strict
-- BuyUpgrade remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UpgradeShop = require(Shared.Logic.UpgradeShop)
local Validate = require(Shared.Util.Validate)

local Net = require(script.Parent.Parent.Lib.Net)
local DataService = require(script.Parent.DataService)

local UpgradeService = {}

function UpgradeService:Start()
	Net.onInvoke(Remotes.Functions.BuyUpgrade, {
		Validate.oneOf(Config.Upgrades.ById),
	}, function(player: Player, upgradeId: string)
		local data = DataService:GetData(player)
		if not data then
			return { ok = false, error = "Data not loaded" }
		end
		local ok, level = UpgradeShop.buy(data, upgradeId)
		if not ok then
			return { ok = false, error = level }
		end
		DataService:Changed(player, "Currency")
		DataService:Changed(player, "Upgrades")
		return { ok = true, level = level }
	end)
end

return UpgradeService
