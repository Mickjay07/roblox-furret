--!strict
-- Client bootstrap: same Init/Start lifecycle as the server, over Controllers.

local Controllers = script:WaitForChild("Controllers")

type Controller = {
	Init: ((self: any) -> ...any)?,
	Start: ((self: any) -> ...any)?,
}

local loaded: { [string]: Controller } = {}

for _, child in Controllers:GetChildren() do
	if child:IsA("ModuleScript") then
		loaded[child.Name] = require(child) :: any
	end
end

for name, controller in loaded do
	local init = controller.Init
	if init then
		local ok, err = pcall(init, controller)
		if not ok then
			warn(`[Client] {name}.Init failed: {err}`)
		end
	end
end

for name, controller in loaded do
	local start = controller.Start
	if start then
		task.spawn(function()
			local ok, err = pcall(start, controller)
			if not ok then
				warn(`[Client] {name}.Start failed: {err}`)
			end
		end)
	end
end
