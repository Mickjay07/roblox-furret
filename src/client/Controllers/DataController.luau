--!strict
-- Client mirror of the player's server-side data. Read-only: every change comes from the
-- server (DataChanged / DataPatched). UI code observes keys to stay in sync.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Signal = require(Shared.Util.Signal)

local Net = require(script.Parent.Parent.Lib.Remotes)

local DataController = {}

-- Fires with the changed top-level key; "*" means the whole snapshot was replaced.
DataController.Changed = Signal.new() :: Signal.Signal<string>

local data: Types.PlayerData? = nil

function DataController:Get(): Types.PlayerData?
	return data
end

-- Calls `handler(data)` now (if loaded) and whenever `key` (or the snapshot) changes.
function DataController:Observe(key: string, handler: (Types.PlayerData) -> ())
	if data then
		handler(data)
	end
	DataController.Changed:Connect(function(changed)
		if data and (changed == key or changed == "*") then
			handler(data)
		end
	end)
end

local function setSnapshot(snapshot: any)
	if type(snapshot) == "table" then
		data = snapshot
		DataController.Changed:Fire("*")
	end
end

function DataController:Start()
	Net.on(Remotes.Events.DataChanged, function(key: string, value: any)
		if key == "__snapshot" then
			setSnapshot(value)
		elseif data then
			(data :: any)[key] = value
			DataController.Changed:Fire(key)
		end
	end)
	Net.on(Remotes.Events.DataPatched, function(key: string, set: { [string]: any }, remove: { string })
		if not data then
			return
		end
		local map = (data :: any)[key]
		if type(map) ~= "table" then
			return
		end
		for subKey, value in set do
			map[subKey] = value
		end
		for _, subKey in remove do
			map[subKey] = nil
		end
		DataController.Changed:Fire(key)
	end)

	-- The snapshot event may have fired before we connected; ask until we have data.
	task.spawn(function()
		for _ = 1, 60 do
			if data then
				return
			end
			local result = Net.invoke(Remotes.Functions.GetSnapshot)
			if result.ok and not data then
				setSnapshot(result.data)
				return
			end
			task.wait(2)
		end
	end)
end

return DataController
