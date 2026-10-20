--!strict
-- BuyPack puts packs in the pack inventory; OpenPack opens 1, 3 or 6 owned packs with
-- server-side rolls (owner decision Q1; A7 opening sequence); OpenAllPacks (Open All game
-- pass) opens every owned pack. Randomness comes from the server's own
-- Random. OpenPack is idempotent per client request id (Lib/PackOpenRequests), so repeated
-- clicks or retries can never consume a second pack or grant a second reward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Entitlements = require(Shared.Logic.Entitlements)
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

	-- Sends everything an opening changed, once.
	local function replicate(player: Player, data: Types.PlayerData, opening: PackShop.Opening)
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
	end

	-- Opening sizes: 1, plus every Multi Opening product's pack count (3, 6).
	local sizes: { [number]: boolean } = { [1] = true }
	for _, product in Entitlements.products() do
		sizes[product.Packs :: number] = true
	end
	local openArgs: { Validate.Checker } = { Validate.oneOf(Config.Packs.ById), Validate.id(64), Validate.oneOf(sizes) }
	Net.onInvoke(
		Remotes.Functions.OpenPack,
		openArgs,
		function(player: Player, packId: string, requestId: string, packs: number)
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
			}, packs)
			if not opening then
				-- A failure (nothing changed) or a replay of an already-granted opening.
				return response
			end
			replicate(player, data, opening)
			return response
		end
	)

	-- Open All game pass: every owned pack, checked on the server (entitlement, counts,
	-- space); the request id makes a repeated click replay instead of opening more.
	Net.onInvoke(Remotes.Functions.OpenAllPacks, { Validate.id(64) }, function(player: Player, requestId: string)
		local data = DataService:GetData(player)
		if not data then
			return { ok = false, error = "Data not loaded" }
		end
		local response, opening = requests:openAll(data, player.UserId, requestId, {
			ownerId = player.UserId,
			now = os.time(),
			roll = function()
				return rng:NextNumber()
			end,
		}, Config.Game.Limits.MaxOpenAll)
		if opening then
			replicate(player, data, opening)
		end
		return response
	end)

	Players.PlayerRemoving:Connect(function(player)
		requests:forget(player.UserId)
	end)
end

return PackService
