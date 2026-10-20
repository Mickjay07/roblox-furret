--!strict
-- Stand earnings (spec §10, owner decision Q3): every tick each occupied stand accumulates
-- income; players collect one stand or all stands (CollectEarnings). Capped offline earnings
-- are credited onto the stands once per join, using the server-saved LastOnline time, after
-- the game pass check (2x AFK Time Cash doubles exactly those offline earnings, once).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Economy = require(Shared.Logic.Economy)
local IncomeLedger = require(Shared.Logic.IncomeLedger)
local Format = require(Shared.Util.Format)
local Validate = require(Shared.Util.Validate)

local Net = require(script.Parent.Parent.Lib.Net)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)

local EconomyService = {}

-- Server-only income multipliers (game passes, boosts) plug in here later.
function EconomyService:ExtraMultiplier(_player: Player): number
	return 1
end

-- Longest wait for the join-time game pass check before offline earnings are credited
-- (then the cached Purchases.Entitlements decide the 2x AFK Time Cash multiplier).
local PASS_CHECK_TIMEOUT = 10

-- Players whose offline earnings have not been credited yet. Until then the tick loop
-- leaves LastOnline alone, so the away time is still measured from the saved timestamp.
local offlinePending: { [Player]: Types.PlayerData } = {}

-- Credits capped offline earnings exactly once per loaded profile.
local function creditOffline(player: Player, data: Types.PlayerData)
	if offlinePending[player] ~= data then
		return
	end
	offlinePending[player] = nil
	local now = os.time()
	local multiplier = Economy.offlineMultiplier(data)
	local added, seconds = IncomeLedger.applyOffline(data, now, EconomyService:ExtraMultiplier(player), multiplier)
	IncomeLedger.markOnline(data, now)
	if added >= 1 and player.Parent ~= nil then
		DataService:Changed(player, "Income")
		local capped = seconds >= Config.Economy.Income.OfflineCapSeconds
		DataService:Notify(
			player,
			`Your stands earned ${Format.short(added, 1e6)} while you were away`
				.. (if multiplier > 1 then ` ({multiplier}x AFK Time Cash)` else "")
				.. (if capped then ` (max {Format.duration(Config.Economy.Income.OfflineCapSeconds)} counted)` else "")
				.. ". Collect it!",
			"success"
		)
	end
end

function EconomyService:Start()
	DataService.ProfileLoaded:Connect(function(player, data)
		IncomeLedger.sanitize(data)
		offlinePending[player] = data
		task.spawn(function()
			-- 2x AFK Time Cash is a game pass: wait for Roblox to confirm ownership first.
			MonetizationService:WaitForVerification(player, PASS_CHECK_TIMEOUT)
			creditOffline(player, data)
		end)
	end)

	DataService.ProfileReleasing:Connect(function(player, data)
		-- Left before the pass check finished: credit now so the earnings are not lost.
		creditOffline(player, data)
		offlinePending[player] = nil
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
				if data and offlinePending[player] ~= data then
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
