--!strict
-- Client access to the server's remotes (created by server/Lib/Net).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("Remotes")

local Remotes = {}

export type Result = { ok: boolean, error: string?, [string]: any }

-- Invokes a RemoteFunction. Never throws: network errors become { ok = false }.
function Remotes.invoke(name: string, ...: any): Result
	local remote = folder:WaitForChild(name, 10)
	if not remote or not remote:IsA("RemoteFunction") then
		return { ok = false, error = "Not available" }
	end
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok or type(result) ~= "table" then
		return { ok = false, error = "Connection problem, try again" }
	end
	return result
end

function Remotes.on(name: string, handler: (...any) -> ()): RBXScriptConnection
	local remote = folder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `{name} is not a RemoteEvent`)
	return remote.OnClientEvent:Connect(handler)
end

return Remotes
