--!strict
-- Stand earnings (spec §10, owner decision Q3): every tick each occupied stand accumulates
-- income; players collect one stand or all stands (CollectEarnings). Capped offline earnings
-- are credited onto the stands when a profile loads, using the server-saved LastOnline time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local IncomeLedger = require(Shared.Logic.IncomeLedger)
local Format = require(Shared.Util.Format)
local Validate = require(Shared.Util.Validate)

local Net = require(script.Parent.Parent.Lib.Net)
local DataService = require(script.Parent.DataService)

local EconomyService = {}

-- Server-only income multipliers (game passes, boosts) plug in here later.
function EconomyService:ExtraMultiplier(_player: Player): number
	return 1
end

function EconomyService:Start()
	DataService.ProfileLoaded:Connect(function(player, data)
		IncomeLedger.sanitize(data)
		local now = os.time()
		local added, seconds = IncomeLedger.applyOffline(data, now, EconomyService:ExtraMultiplier(player))
		IncomeLedger.markOnline(data, now)
		if added >= 1 then
			local capped = seconds >= Config.Economy.Income.OfflineCapSeconds
			DataService:Notify(
				player,
				`Your stands earned ${Format.short(added, 1e6)} while you were away`
					.. (if capped
						then ` (max {Format.duration(Config.Economy.Income.OfflineCapSeconds)} counted)`
						else "")
					.. ". Collect it!",
				"success"
			)
		end
	end)

	DataService.ProfileReleasing:Connect(function(_player, data)
		IncomeLedger.markOnline(data, os.time())
	end)

	Net.onInvoke(Remotes.Functions.CollectEarnings, { Validate.integer(0, 100) }, function(player: Player, slot: number)
		local data = DataService:GetData(player)
		if not data then
			return { ok = false, error = "Data not loaded" }
		end
		local collected = if slot == 0
			then IncomeLedger.collectAll(data)
			else IncomeLedger.collect(data, tostring(slot))
		if collected > 0 then
			DataService:Changed(player, "Income")
			DataService:Changed(player, "Currency")
		end
		return { ok = true, collected = collected }
	end)

	local tick = Config.Economy.IncomeTickSeconds
	task.spawn(function()
		while true do
			task.wait(tick)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local data = DataService:GetData(player)
				if data then
					-- Keeping LastOnline current means a crash can never be counted as offline
					-- time twice: the saved timestamp always matches the saved earnings.
					IncomeLedger.markOnline(data, now)
					if IncomeLedger.accrue(data, tick, EconomyService:ExtraMultiplier(player)) > 0 then
						DataService:Changed(player, "Income")
					end
				end
			end
		end
	end)
end

return EconomyService
