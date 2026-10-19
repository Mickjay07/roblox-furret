--!strict
-- Toast notifications, stacked bottom-right (as in the reference screenshots).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UI = script.Parent.Parent.UI
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Net = require(script.Parent.Parent.Lib.Remotes)
local DataController = require(script.Parent.DataController)

local MAX_VISIBLE = 5
local LIFETIME = 4

local NotificationController = {}

local container: Frame

function NotificationController:Push(message: string, kind: string?)
	local k = kind or "info"
	local data = DataController:Get()
	if data and data.Settings.Notifications == false and k ~= "error" then
		return
	end
	local accent = Theme.NotificationColors[k] or Theme.NotificationColors.info

	local toast = Create("Frame", {
		Name = "Toast",
		Size = UDim2.fromOffset(340, 64),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.05,
		LayoutOrder = math.floor(os.clock() * 1000),
	}, {
		Components.corner(UDim.new(0, 12)),
		Components.stroke(Theme.Colors.Border, 3),
		Create("Frame", {
			Name = "Accent",
			Size = UDim2.new(0, 8, 1, -16),
			Position = UDim2.fromOffset(10, 8),
			BackgroundColor3 = accent,
		}, { Components.corner(UDim.new(1, 0)) }),
	})
	local label = Components.label({
		Text = message,
		Size = UDim2.new(1, -40, 1, -16),
		Position = UDim2.fromOffset(28, 8),
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 2,
		Parent = toast,
	})
	label.TextWrapped = true
	toast.Parent = container

	local toasts = {}
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - MAX_VISIBLE do
		toasts[i]:Destroy()
	end

	task.delay(LIFETIME, function()
		if toast.Parent then
			toast:Destroy()
		end
	end)
end

function NotificationController:Start()
	local gui = Create("ScreenGui", {
		Name = "Notifications",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	container = Create("Frame", {
		Name = "Stack",
		Size = UDim2.fromOffset(340, 400),
		Position = UDim2.new(1, -16, 1, -16),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
		}),
	})
	Components.autoScale(container)

	Net.on(Remotes.Events.Notify, function(message: string, kind: string?)
		if type(message) == "string" then
			NotificationController:Push(message, kind)
		end
	end)
end

return NotificationController
