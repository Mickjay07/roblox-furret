--!strict
-- Passive income: every tick, each loaded player earns the income of their display stands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Logic.Economy)
local Wallet = require(Shared.Logic.Wallet)

local DataService = require(script.Parent.DataService)

local EconomyService = {}

-- Server-only income multipliers (game passes, boosts) plug in here later.
function EconomyService:ExtraMultiplier(_player: Player): number
	return 1
end

function EconomyService:Start()
	local tick = Config.Economy.IncomeTickSeconds
	task.spawn(function()
		while true do
			task.wait(tick)
			for _, player in Players:GetPlayers() do
				local data = DataService:GetData(player)
				if data then
					local earned = Economy.totalIncome(data, EconomyService:ExtraMultiplier(player)) * tick
					if earned > 0 then
						Wallet.add(data, "Cash", earned)
						DataService:Changed(player, "Currency")
					end
				end
			end
		end
	end)
end

return EconomyService
