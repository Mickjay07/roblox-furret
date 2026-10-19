--!strict
-- BuyPack: server-side purchase and roll. Randomness comes from the server's own Random.

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

function PackService:Start()
	Net.onInvoke(Remotes.Functions.BuyPack, {
		Validate.oneOf(Config.Packs.ById),
		Validate.integer(1, Config.Game.Limits.MaxPacksPerPurchase),
	}, function(player: Player, packId: string, amount: number)
		local data = DataService:GetData(player)
		if not data then
			return { ok = false, error = "Data not loaded" }
		end
		local ok, result = PackShop.buy(data, packId, amount, {
			ownerId = player.UserId,
			now = os.time(),
			roll = function()
				return rng:NextNumber()
			end,
		})
		if not ok then
			return { ok = false, error = result }
		end
		local purchase: PackShop.Purchase = result
		DataService:Patched(player, "Cards", purchase.NewInstanceIds)
		DataService:Patched(player, "Discovered", purchase.DiscoveredIds)
		DataService:Changed(player, "Currency")
		DataService:Changed(player, "Progression")
		DataService:Changed(player, "Stats")
		if purchase.LevelsGained > 0 then
			DataService:Notify(
				player,
				`Level up! You reached level {data.Progression.Level} (+{purchase.TreatsGained} Treats)`,
				"success"
			)
		end
		return {
			ok = true,
			packId = packId,
			cards = purchase.Cards,
			levelsGained = purchase.LevelsGained,
			treatsGained = purchase.TreatsGained,
		}
	end)
end

return PackService
