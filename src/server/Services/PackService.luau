--!strict
-- BuyPack puts packs in the pack inventory; OpenPack opens owned packs with server-side rolls
-- (owner decision Q1). Randomness comes from the server's own Random.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PackShop = require(Shared.Logic.PackShop)
local Validate = require(Shared.Util.Validate)

local Net = require(script.Parent.Parent.Lib.Net)
local DataService = require(script.Parent.DataService)

local PackService = {}

local rng = Random.new()

local function packArgs(): { Validate.Checker }
	return {
		Validate.oneOf(Config.Packs.ById),
		Validate.integer(1, Config.Game.Limits.MaxPacksPerPurchase),
	}
end

function PackService:Start()
	Net.onInvoke(Remotes.Functions.BuyPack, packArgs(), function(player: Player, packId: string, amount: number)
		local data = DataService:GetData(player)
		if not data then
			return { ok = false, error = "Data not loaded" }
		end
		local ok, result = PackShop.buy(data, packId, amount)
		if not ok then
			return { ok = false, error = result }
		end
		DataService:Changed(player, "Currency")
		DataService:Changed(player, "Packs")
		return { ok = true, packId = packId, owned = PackShop.owned(data, packId) }
	end)

	Net.onInvoke(Remotes.Functions.OpenPack, packArgs(), function(player: Player, packId: string, amount: number)
		local data = DataService:GetData(player)
		if not data then
			return { ok = false, error = "Data not loaded" }
		end
		local ok, result = PackShop.open(data, packId, amount, {
			ownerId = player.UserId,
			now = os.time(),
			roll = function()
				return rng:NextNumber()
			end,
		})
		if not ok then
			return { ok = false, error = result }
		end
		local opening: PackShop.Opening = result
		DataService:Patched(player, "Cards", opening.NewInstanceIds)
		DataService:Patched(player, "Discovered", opening.DiscoveredIds)
		DataService:Changed(player, "Packs")
		DataService:Changed(player, "Currency")
		DataService:Changed(player, "Progression")
		DataService:Changed(player, "Stats")
		if opening.LevelsGained > 0 then
			DataService:Notify(
				player,
				`Level up! You reached level {data.Progression.Level} (+{opening.TreatsGained} Treats)`,
				"success"
			)
		end
		return {
			ok = true,
			packId = packId,
			cards = opening.Cards,
			levelsGained = opening.LevelsGained,
			treatsGained = opening.TreatsGained,
		}
	end)
end

return PackService
