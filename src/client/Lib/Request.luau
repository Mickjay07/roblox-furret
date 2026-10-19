--!strict
-- Invokes a server request and shows its error as a toast.

local Remotes = require(script.Parent.Remotes)
local NotificationController = require(script.Parent.Parent.Controllers.NotificationController)

local pending: { [string]: boolean } = {}

-- Returns the Result. Concurrent calls to the same remote are dropped (prevents
-- double-clicks from sending duplicate purchases).
local function Request(name: string, ...: any): Remotes.Result
	if pending[name] then
		return { ok = false, error = "busy" }
	end
	pending[name] = true
	local result = Remotes.invoke(name, ...)
	pending[name] = nil
	if not result.ok and result.error ~= "busy" then
		NotificationController:Push(result.error or "Something went wrong", "error")
	end
	return result
end

return Request
