-- Structural check of the Rojo-built place file (build/FerretCardTycoon.rbxl).
-- Confirms the instance tree Studio will load, without needing Studio.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local TestKit = require("../TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local PLACE = "build/FerretCardTycoon.rbxl"

describe("built place", function()
	if not fs.isFile(PLACE) then
		it("exists (run `rojo build -o build/FerretCardTycoon.rbxl` first)", function()
			error(`{PLACE} not found`)
		end)
		return
	end

	local game = roblox.deserializePlace(fs.readFile(PLACE))

	local function find(path: { string })
		local node = game
		for _, name in path do
			node = if node.ClassName == "DataModel" then game:GetService(name) else node:FindFirstChild(name)
			if not node then
				return nil
			end
		end
		return node
	end

	local expected = {
		{ path = { "ServerScriptService", "Server" }, class = "Script" },
		{ path = { "ServerScriptService", "Server", "Services" }, class = "Folder" },
		{ path = { "StarterPlayer", "StarterPlayerScripts", "Client" }, class = "LocalScript" },
		{ path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Controllers" }, class = "Folder" },
		{ path = { "ReplicatedStorage", "Shared" }, class = "Folder" },
		{ path = { "ReplicatedStorage", "Shared", "Config" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Remotes" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Util", "WeightedRandom" }, class = "ModuleScript" },
	}

	for _, case in expected do
		local label = table.concat(case.path, ".")
		it(`{label} is a {case.class}`, function()
			local node = find(case.path)
			expect(node ~= nil).toBe(true)
			expect(node.ClassName).toBe(case.class)
		end)
	end
end)
