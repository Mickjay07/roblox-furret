--!strict
-- Server side of networking. Creates every remote declared in Shared/Remotes and wraps
-- request handlers with:
--   1. per-player, per-remote rate limiting (Config.Game.RateLimits),
--   2. argument validation (Shared/Util/Validate checkers, one per argument),
--   3. error isolation: a handler error is logged and the client gets a generic failure.
-- Handlers receive (player, ...validated args) and return a Result table.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RateLimiter = require(Shared.Util.RateLimiter)
local Validate = require(Shared.Util.Validate)

export type Result = { [string]: any }

local Net = {}

local folder: Folder? = nil
local functions: { [string]: RemoteFunction } = {}
local events: { [string]: RemoteEvent } = {}
local limiters: { [string]: RateLimiter.RateLimiter } = {}

local function fail(message: string): Result
	return { ok = false, error = message }
end

function Net.init()
	if folder then
		return
	end
	local container = Instance.new("Folder")
	container.Name = "Remotes"
	for name: string in Remotes.Functions :: any do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.OnServerInvoke = function()
			return fail("not available")
		end
		remote.Parent = container
		functions[name] = remote
	end
	for name: string in Remotes.Events :: any do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = container
		events[name] = remote
	end
	container.Parent = ReplicatedStorage
	folder = container

	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:forget(player)
		end
	end)
end

local function limiterFor(name: string): RateLimiter.RateLimiter
	local limiter = limiters[name]
	if not limiter then
		local limits = (Config.Game.RateLimits :: any)[name] or Config.Game.RateLimits.Default
		limiter = RateLimiter.new(limits.Rate, limits.Burst)
		limiters[name] = limiter
	end
	return limiter
end

-- Registers the handler for a RemoteFunction declared in Remotes.Functions.
function Net.onInvoke(name: string, checkers: { Validate.Checker }, handler: (Player, ...any) -> Result)
	Net.init()
	local remote = functions[name]
	assert(remote, `Net.onInvoke: unknown remote {name} (call Net.init first)`)
	local limiter = limiterFor(name)
	remote.OnServerInvoke = function(player: Player, ...: any): Result
		if not limiter:allow(player) then
			return fail("Slow down!")
		end
		local args = table.pack(...)
		local valid, reason = Validate.args(checkers, args, args.n)
		if not valid then
			warn(`[Net] {player.Name} sent invalid {name}: {reason}`)
			return fail("Invalid request")
		end
		local ok, result = pcall(handler, player, table.unpack(args, 1, args.n))
		if not ok then
			warn(`[Net] {name} handler error for {player.Name}: {result}`)
			return fail("Something went wrong")
		end
		return result
	end
end

function Net.fire(player: Player, name: string, ...: any)
	Net.init()
	local remote = events[name]
	assert(remote, `Net.fire: unknown event {name}`)
	remote:FireClient(player, ...)
end

function Net.notify(player: Player, message: string, kind: string?)
	Net.fire(player, Remotes.Events.Notify, message, kind or "info")
end

return Net
