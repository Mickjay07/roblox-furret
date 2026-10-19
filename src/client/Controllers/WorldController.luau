--!strict
-- Station prompts in the world (spec §18): walk up to a station instead of opening menus.
-- Prompts are local; they open the existing windows or call the existing validated remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent.UI
local Create = require(UI.Create)
local Windows = require(UI.Windows)
local Request = require(script.Parent.Parent.Lib.Request)
local NotificationController = require(script.Parent.NotificationController)

local WorldController = {}

local ACTIONS: { [string]: { text: string, run: () -> () } } = {
	PackShop = {
		text = "Open Pack Shop",
		run = function()
			Windows.open("Packs")
		end,
	},
	Upgrades = {
		text = "Open Upgrades",
		run = function()
			Windows.open("Upgrades")
		end,
	},
	Collect = {
		text = "Collect all stands",
		run = function()
			local result = Request(Remotes.Functions.CollectEarnings, 0)
			if result.ok then
				local collected = result.collected or 0
				NotificationController:Push(
					if collected > 0 then `Collected ${Format.short(collected, 1e6)}` else "Nothing to collect yet",
					if collected > 0 then "success" else "info"
				)
			end
		end,
	},
	Grader = {
		text = "Grader (coming soon)",
		run = function()
			NotificationController:Push("The Grader Station opens in a future update.", "info")
		end,
	},
}

function WorldController:Start()
	local world = workspace:WaitForChild("World")
	local stations = world:WaitForChild("Stations")
	local function setup(model: Instance)
		local id = model:GetAttribute("Station")
		local action = if type(id) == "string" then ACTIONS[id] else nil
		local interact = model:WaitForChild("Interact", 5)
		if not action or not interact then
			return
		end
		local prompt: ProximityPrompt = Create("ProximityPrompt", {
			Name = "StationPrompt",
			ActionText = action.text,
			ObjectText = string.upper(tostring(id)),
			KeyboardKeyCode = Enum.KeyCode.E,
			HoldDuration = 0,
			MaxActivationDistance = 12,
			RequiresLineOfSight = false,
			Parent = interact,
		})
		prompt.Triggered:Connect(action.run)
	end
	for _, model in stations:GetChildren() do
		task.spawn(setup, model)
	end
	stations.ChildAdded:Connect(function(model)
		task.spawn(setup, model)
	end)
end

return WorldController
