--!strict
-- Card management remotes: display stands, selling, favourites.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Display = require(Shared.Logic.Display)
local Market = require(Shared.Logic.Market)
local Validate = require(Shared.Util.Validate)

local Net = require(script.Parent.Parent.Lib.Net)
local DataService = require(script.Parent.DataService)

local CardService = {}

local NOT_LOADED = { ok = false, error = "Data not loaded" }

local function result(ok: boolean, reason: string?): { [string]: any }
	return if ok then { ok = true } else { ok = false, error = reason or "Something went wrong" }
end

function CardService:Start()
	-- Repair display entries once a profile loads (e.g. after a card was removed by repair).
	DataService.ProfileLoaded:Connect(function(_player, data)
		Display.sanitize(data)
	end)

	Net.onInvoke(Remotes.Functions.PlaceCard, {
		Validate.instanceId(),
		Validate.integer(0, 100),
	}, function(player: Player, instanceId: string, slot: number)
		local data = DataService:GetData(player)
		if not data then
			return NOT_LOADED
		end
		local ok, reason = Display.place(data, instanceId, slot)
		if ok then
			DataService:Changed(player, "Display")
		end
		return result(ok, reason)
	end)

	Net.onInvoke(Remotes.Functions.RemoveCard, { Validate.instanceId() }, function(player: Player, instanceId: string)
		local data = DataService:GetData(player)
		if not data then
			return NOT_LOADED
		end
		local ok, reason = Display.remove(data, instanceId)
		if ok then
			DataService:Changed(player, "Display")
		end
		return result(ok, reason)
	end)

	Net.onInvoke(Remotes.Functions.PlaceBest, {}, function(player: Player)
		local data = DataService:GetData(player)
		if not data then
			return NOT_LOADED
		end
		Display.placeBest(data)
		DataService:Changed(player, "Display")
		return { ok = true }
	end)

	Net.onInvoke(Remotes.Functions.SellCards, {
		Validate.array(Validate.instanceId(), Config.Game.Limits.MaxCardsPerSell),
	}, function(player: Player, instanceIds: { string })
		local data = DataService:GetData(player)
		if not data then
			return NOT_LOADED
		end
		local ok, earned = Market.sell(data, instanceIds)
		if not ok then
			return { ok = false, error = earned }
		end
		DataService:Patched(player, "Cards", instanceIds)
		DataService:Changed(player, "Currency")
		DataService:Changed(player, "Stats")
		return { ok = true, earned = earned }
	end)

	Net.onInvoke(Remotes.Functions.SetFavorite, {
		Validate.instanceId(),
		Validate.boolean(),
	}, function(player: Player, instanceId: string, favorite: boolean)
		local data = DataService:GetData(player)
		if not data then
			return NOT_LOADED
		end
		local ok, reason = Market.setFavorite(data, instanceId, favorite)
		if ok then
			DataService:Patched(player, "Cards", { instanceId })
		end
		return result(ok, reason)
	end)
end

return CardService
