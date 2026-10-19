--!strict
-- Settings window. Values live in server-side player data; changes go through the
-- validated UpdateSetting remote and the UI refreshes from the replicated result. Only the
-- settings the profile actually stores are shown (ProfileSchema.SETTINGS).

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

local function update(key: string, value: any, label: string)
	local result = Net.invoke(Remotes.Functions.UpdateSetting, key, value)
	if result.ok then
		NotificationController:Push(`{label} saved`, "success")
	else
		NotificationController:Push(result.error or "Could not change setting", "error")
	end
end

local function rowFrame(parent: Instance, order: number, title: string, hint: string): Frame
	local frame = Components.panel({
		Name = title,
		Size = UDim2.new(1, 0, 0, 70),
		LayoutOrder = order,
		Parent = parent,
	})
	Components.label({
		Text = string.upper(title),
		Size = UDim2.new(0.5, 0, 0, 28),
		Position = UDim2.fromOffset(18, 10),
		XAlign = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	Components.label({
		Text = hint,
		Size = UDim2.new(0.5, 0, 0, 18),
		Position = UDim2.fromOffset(18, 42),
		Color = Theme.Colors.Muted,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		Parent = frame,
	})
	return frame
end

local function toggleRow(parent: Instance, order: number, title: string, hint: string, key: string)
	local frame = rowFrame(parent, order, title, hint)
	local button, set = Components.toggle(UDim2.fromOffset(112, 46), frame, function()
		local data = DataController:Get()
		if data then
			update(key, not data.Settings[key], title)
		end
	end)
	button.Position = UDim2.new(1, -16, 0.5, 0)
	button.AnchorPoint = Vector2.new(1, 0.5)
	DataController:Observe("Settings", function(data: Types.PlayerData)
		set(data.Settings[key] == true)
	end)
end

local function volumeRow(parent: Instance, order: number, title: string, hint: string, key: string)
	local frame = rowFrame(parent, order, title, hint)
	-- Ten-segment level meter between the - and + buttons.
	local meter = Create("Frame", {
		Name = "Meter",
		Size = UDim2.fromOffset(150, 22),
		Position = UDim2.new(1, -76, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Parent = frame,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 3),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	local segments: { Frame } = {}
	for i = 1, 10 do
		segments[i] = Create("Frame", {
			Size = UDim2.new(0, 12, 0, 8 + i),
			BackgroundColor3 = Theme.Colors.PanelDeep,
			LayoutOrder = i,
			Parent = meter,
		}, { Components.corner(UDim.new(0, 3)) })
	end
	local function step(delta: number)
		local data = DataController:Get()
		if data then
			local current = tonumber(data.Settings[key]) or 0
			update(key, math.clamp(math.floor((current + delta) * 10 + 0.5) / 10, 0, 1), title)
		end
	end
	Components.button({
		Text = "-",
		Style = "Brown",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -234, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = frame,
		OnClick = function()
			step(-0.1)
		end,
	})
	Components.button({
		Text = "+",
		Style = "Gold",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -16, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = frame,
		OnClick = function()
			step(0.1)
		end,
	})
	DataController:Observe("Settings", function(data: Types.PlayerData)
		local level = math.floor((tonumber(data.Settings[key]) or 0) * 10 + 0.5)
		for i, segment in segments do
			segment.BackgroundColor3 = if i <= level then Theme.Colors.Gold else Theme.Colors.PanelDeep
		end
	end)
end

function SettingsController:Start()
	DataController:Observe("Settings", function(data: Types.PlayerData)
		Components.reducedMotion = data.Settings.ReducedMotion == true
	end)

	Windows.register("Settings", {
		Title = "Settings",
		Icon = "ui.icon.settings",
		Size = Vector2.new(660, 560),
		Build = function(content: Frame)
			local list = Create("ScrollingFrame", {
				Name = "List",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Colors.Gold,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = content,
			}, {
				Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
				Create("UIPadding", { PaddingRight = UDim.new(0, 8) }),
			})
			Components.sectionTitle("GAMEPLAY", nil, list, 1)
			toggleRow(list, 2, "Notifications", "Pop-up messages (errors always show)", "Notifications")
			toggleRow(list, 3, "Reduced Motion", "Fewer shakes, flashes and pop-ins", "ReducedMotion")
			Components.sectionTitle("AUDIO", nil, list, 4)
			volumeRow(list, 5, "Music", "Saved now; used once music is added", "MusicVolume")
			volumeRow(list, 6, "Sound Effects", "Saved now; used once sounds are added", "SfxVolume")
			local note = Components.label({
				Text = "Your progress and settings save automatically.",
				Size = UDim2.new(1, 0, 0, 22),
				Color = Theme.Colors.Muted,
				StrokeThickness = 1.5,
				LayoutOrder = 7,
				Parent = list,
			})
			note.TextScaled = true
			return nil
		end,
	})
end

return SettingsController
