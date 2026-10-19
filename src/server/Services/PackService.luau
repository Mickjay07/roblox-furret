--!strict
-- BuyPack puts packs in the pack inventory; OpenPack opens ONE owned pack with server-side
-- rolls (owner decision Q1; A7 opening sequence). Randomness comes from the server's own
-- Random. OpenPack is idempotent per client request id (Lib/PackOpenRequests), so repeated
-- clicks or retries can never consume a second pack or grant a second reward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PackShop = require(Shared.Logic.PackShop)
local Validate = require(Shared.Util.Validate)

local Net = require(script.Parent.Parent.Lib.Net)
local PackOpenRequests = require(script.Parent.Parent.Lib.PackOpenRequests)
local DataService = require(script.Parent.DataService)

local PackService = {}

local rng = Random.new()
local requests = PackOpenRequests.new()

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

	local openArgs: { Validate.Checker } = { Validate.oneOf(Config.Packs.ById), Validate.id(64) }
	Net.onInvoke(Remotes.Functions.OpenPack, openArgs, function(player: Player, packId: string, requestId: string)
		local data = DataService:GetData(player)
		if not data then
			return { ok = false, error = "Data not loaded" }
		end
		local response, opening = requests:open(data, player.UserId, packId, requestId, {
			ownerId = player.UserId,
			now = os.time(),
			roll = function()
				return rng:NextNumber()
			end,
		})
		if not opening then
			-- A failure (nothing changed) or a replay of an already-granted opening.
			return response
		end
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
		return response
	end)

	Players.PlayerRemoving:Connect(function(player)
		requests:forget(player.UserId)
	end)
end

return PackService
