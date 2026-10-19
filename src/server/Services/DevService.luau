--!strict
-- Developer commands for Studio testing (roadmap A1, spec §31). See server/Lib/DevCommands
-- for the command set and safety model. On live servers this service does nothing: the
-- DevCommand remote is never created, so clients cannot call it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Validate = require(Shared.Util.Validate)

local Lib = script.Parent.Parent.Lib
local DevCommands = require(Lib.DevCommands)
local Net = require(Lib.Net)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local DevService = {}

local rng = Random.new()

function DevService:IsEnabled(): boolean
	return RunService:IsStudio() and Config.Game.Dev.EnabledInStudio
end

-- Returns (handled, ok, message).
local function serviceCommand(player: Player, name: string): (boolean, boolean, string)
	if name == "plots" then
		return true, true, PlotService:Describe()
	elseif name == "save" then
		local ok = DataService:SaveNow(player)
		local info = DataService:Diagnostics(player)
		return true,
			ok,
			if ok
				then `saved {info.Key}{if info.MockStore then " (in-memory mock store: nothing persists)" else ""}`
				else "save failed (see Output)"
	elseif name == "home" then
		local ok = PlotService:TeleportHome(player)
		return true, ok, if ok then "teleported to your plot" else "you have no plot or no character"
	end
	return false, false, ""
end

function DevService:Start()
	if not DevService:IsEnabled() then
		return
	end
	local remoteName = Remotes.DevFunctions.DevCommand
	Net.createOptionalFunction(remoteName)
	Net.onInvoke(remoteName, { Validate.string(DevCommands.MAX_LINE) }, function(player: Player, line: string)
		local name, args = DevCommands.parse(line)
		if not name then
			return { ok = false, error = `bad command: {args}` }
		end
		local data = DataService:GetData(player)
		if not data then
			return { ok = false, error = "Data not loaded" }
		end

		local handled, ok, message = serviceCommand(player, name)
		local changed: { string }? = nil
		if not handled then
			ok, message, changed = DevCommands.run({
				data = data,
				ownerId = player.UserId,
				now = os.time(),
				roll = function()
					return rng:NextNumber()
				end,
			}, name, args :: { string })
		end
		if changed then
			for _, key in changed do
				DataService:Changed(player, key)
			end
		end
		print(`[Dev] {player.Name}> {line}\n{message}`)
		return { ok = ok, message = message, error = if ok then nil else message }
	end)
	print("[Dev] Developer commands enabled (Studio only). Open the DEV window or run: help")
end

return DevService
