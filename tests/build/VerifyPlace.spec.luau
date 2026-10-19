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
		{ path = { "ServerScriptService", "Server", "Services", "DataService" }, class = "ModuleScript" },
		{ path = { "ServerScriptService", "Server", "Services", "SettingsService" }, class = "ModuleScript" },
		{ path = { "ServerScriptService", "Server", "Services", "PackService" }, class = "ModuleScript" },
		{ path = { "ServerScriptService", "Server", "Services", "CardService" }, class = "ModuleScript" },
		{ path = { "ServerScriptService", "Server", "Services", "UpgradeService" }, class = "ModuleScript" },
		{ path = { "ServerScriptService", "Server", "Services", "EconomyService" }, class = "ModuleScript" },
		{ path = { "ServerScriptService", "Server", "Lib", "SessionStore" }, class = "ModuleScript" },
		{ path = { "ServerScriptService", "Server", "Lib", "DevCommands" }, class = "ModuleScript" },
		{ path = { "ServerScriptService", "Server", "World", "WorldBuilder" }, class = "ModuleScript" },
		{ path = { "ServerScriptService", "Server", "Services", "WorldService" }, class = "ModuleScript" },
		{ path = { "ServerScriptService", "Server", "Services", "PlotService" }, class = "ModuleScript" },
		{ path = { "ServerScriptService", "Server", "Services", "DevService" }, class = "ModuleScript" },
		{
			path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "StandVisualsController" },
			class = "ModuleScript",
		},
		{
			path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "PlotController" },
			class = "ModuleScript",
		},
		{
			path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "WorldController" },
			class = "ModuleScript",
		},
		{
			path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "DevController" },
			class = "ModuleScript",
		},
		{ path = { "ReplicatedStorage", "Shared", "Config", "Assets" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Config", "World" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Config", "Visuals" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Logic", "CardArt" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Logic", "RevealStyle" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Logic", "RevealPlan" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Logic", "Entitlements" }, class = "ModuleScript" },
		{ path = { "ServerScriptService", "Server", "Lib", "ReceiptProcessor" }, class = "ModuleScript" },
		{
			path = { "ServerScriptService", "Server", "Services", "MonetizationService" },
			class = "ModuleScript",
		},
		{
			path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Lib", "ImagePreloader" },
			class = "ModuleScript",
		},
		{ path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Lib", "Coalesce" }, class = "ModuleScript" },
		{ path = { "ServerScriptService", "Server", "Lib", "PackOpenRequests" }, class = "ModuleScript" },
		{ path = { "StarterPlayer", "StarterPlayerScripts", "Client", "UI", "PackReveal" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Logic", "PlotAllocator" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Logic", "PlotLayout" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Logic", "PlotView" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Logic", "IncomeLedger" }, class = "ModuleScript" },
		{ path = { "ServerScriptService", "Server", "Lib", "Net" }, class = "ModuleScript" },
		{
			path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "DataController" },
			class = "ModuleScript",
		},
		{
			path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "HUDController" },
			class = "ModuleScript",
		},
		{
			path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "PacksController" },
			class = "ModuleScript",
		},
		{
			path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "BackpackController" },
			class = "ModuleScript",
		},
		{
			path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "DisplayController" },
			class = "ModuleScript",
		},
		{
			path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "UpgradesController" },
			class = "ModuleScript",
		},
		{
			path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "BinderController" },
			class = "ModuleScript",
		},
		{ path = { "StarterPlayer", "StarterPlayerScripts", "Client", "UI", "Windows" }, class = "ModuleScript" },
		{ path = { "StarterPlayer", "StarterPlayerScripts", "Client", "UI", "CardTile" }, class = "ModuleScript" },
		{
			path = { "StarterPlayer", "StarterPlayerScripts", "Client", "Lib", "ArtDiagnostics" },
			class = "ModuleScript",
		},
		{ path = { "ReplicatedStorage", "Shared", "Config" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Config", "Cards" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Remotes" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Data", "ProfileSchema" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Logic", "CardRegistry" }, class = "ModuleScript" },
		{ path = { "ReplicatedStorage", "Shared", "Util", "WeightedRandom" }, class = "ModuleScript" },
	}

	-- The place Studio runs must carry the real image ids (not the AssetId = 0 placeholder).
	it("Config.Assets in the built place carries every uploaded image id", function()
		local assets = find({ "ReplicatedStorage", "Shared", "Config", "Assets" })
		expect(assets ~= nil).toBe(true)
		local source = assets.Source
		for _, id in
			{
				140074029273080,
				84086042476135,
				123215287639771,
				84803898229705,
				79241250970768,
				128361345866040,
				104453844983670,
			}
		do
			expect(string.find(source, string.format("%d", id), 1, true) ~= nil).toBe(true)
		end
	end)

	for _, case in expected do
		local label = table.concat(case.path, ".")
		it(`{label} is a {case.class}`, function()
			local node = find(case.path)
			expect(node ~= nil).toBe(true)
			expect(node.ClassName).toBe(case.class)
		end)
	end
end)
