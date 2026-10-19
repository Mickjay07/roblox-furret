--!strict
-- Server bootstrap: loads every ModuleScript in Services, calls Init on all of them,
-- then Start on all of them. Services must not yield inside Init.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigCheck = require(ReplicatedStorage:WaitForChild("Shared").Logic.ConfigCheck)
local Services = script:WaitForChild("Services")

for _, problem in ConfigCheck.run() do
	warn(`[Config] {problem}`)
end

type Service = {
	Init: ((self: any) -> ...any)?,
	Start: ((self: any) -> ...any)?,
}

local loaded: { [string]: Service } = {}

for _, child in Services:GetChildren() do
	if child:IsA("ModuleScript") then
		loaded[child.Name] = require(child) :: any
	end
end

for name, service in loaded do
	local init = service.Init
	if init then
		local ok, err = pcall(init, service)
		if not ok then
			warn(`[Server] {name}.Init failed: {err}`)
		end
	end
end

for name, service in loaded do
	local start = service.Start
	if start then
		task.spawn(function()
			local ok, err = pcall(start, service)
			if not ok then
				warn(`[Server] {name}.Start failed: {err}`)
			end
		end)
	end
end

print(`[Server] Ferret Card Tycoon started ({#Services:GetChildren()} services)`)
