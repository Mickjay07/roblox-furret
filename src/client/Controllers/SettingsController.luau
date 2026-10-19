--!strict
-- Settings window. Values live in server-side player data; changes go through the
-- validated UpdateSetting remote and the UI refreshes from the replicated result.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local UI = script.Parent.Parent.UI
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Windows = require(UI.Windows)
local Net = require(script.Parent.Parent.Lib.Remotes)
local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local SettingsController = {}

local function update(key: string, value: any)
	local result = Net.invoke(Remotes.Functions.UpdateSetting, key, value)
	if not result.ok then
		NotificationController:Push(result.error or "Could not change setting", "error")
	end
end

local function rowFrame(parent: Instance, order: number, title: string): Frame
	local frame = Create("Frame", {
		Name = title,
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.Colors.PanelInset,
		LayoutOrder = order,
		Parent = parent,
	}, { Components.corner(UDim.new(0, 12)) })
	Components.label({
		Text = string.upper(title),
		Size = UDim2.new(0.5, 0, 0, 30),
		Position = UDim2.new(0, 16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		XAlign = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	return frame
end

local function toggleRow(parent: Instance, order: number, title: string, key: string)
	local frame = rowFrame(parent, order, title)
	local button = Components.button({
		Text = "ON",
		Style = "Green",
		Size = UDim2.fromOffset(120, 48),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = frame,
		OnClick = function()
			local data = DataController:Get()
			if data then
				update(key, not data.Settings[key])
			end
		end,
	})
	DataController:Observe("Settings", function(data: Types.PlayerData)
		local on = data.Settings[key] == true
		Components.setButtonText(button, if on then "ON" else "OFF")
		Components.setButtonStyle(button, if on then "Green" else "Gray")
	end)
end

local function volumeRow(parent: Instance, order: number, title: string, key: string)
	local frame = rowFrame(parent, order, title)
	local value = Components.label({
		Text = "50%",
		Size = UDim2.fromOffset(90, 30),
		Position = UDim2.new(1, -84, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = frame,
	})
	local function step(delta: number)
		local data = DataController:Get()
		if data then
			local current = tonumber(data.Settings[key]) or 0
			update(key, math.clamp(math.floor((current + delta) * 10 + 0.5) / 10, 0, 1))
		end
	end
	Components.button({
		Text = "-",
		Style = "Blue",
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, -184, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = frame,
		OnClick = function()
			step(-0.1)
		end,
	})
	Components.button({
		Text = "+",
		Style = "Blue",
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = frame,
		OnClick = function()
			step(0.1)
		end,
	})
	DataController:Observe("Settings", function(data: Types.PlayerData)
		value.Text = `{math.floor((tonumber(data.Settings[key]) or 0) * 100 + 0.5)}%`
	end)
end

function SettingsController:Start()
	DataController:Observe("Settings", function(data: Types.PlayerData)
		Components.reducedMotion = data.Settings.ReducedMotion == true
	end)

	Windows.register("Settings", {
		Title = "Settings",
		Accent = "Gray",
		Size = Vector2.new(620, 420),
		Build = function(content: Frame)
			Create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
				Parent = content,
			})
			volumeRow(content, 1, "Music", "MusicVolume")
			volumeRow(content, 2, "Sound Effects", "SfxVolume")
			toggleRow(content, 3, "Notifications", "Notifications")
			toggleRow(content, 4, "Reduced Motion", "ReducedMotion")
			local note = Components.label({
				Text = "Progress saves automatically.",
				Size = UDim2.new(1, 0, 0, 24),
				Color = Theme.Colors.Muted,
				LayoutOrder = 5,
				Parent = content,
			})
			note.TextScaled = true
			return nil
		end,
	})
end

return SettingsController
