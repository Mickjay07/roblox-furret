--!strict
-- Main HUD, following the reference layout: currency and level on the left, primary
-- actions top-centre, feature rail on the right, notifications bottom-right.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Economy = require(Shared.Logic.Economy)
local IncomeLedger = require(Shared.Logic.IncomeLedger)
local Progression = require(Shared.Logic.Progression)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent.UI
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Windows = require(UI.Windows)
local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)
local Request = require(script.Parent.Parent.Lib.Request)

local HUDController = {}

-- Navigation entries: window name, label, button style. Windows that are not registered
-- (features not built yet) show a "coming soon" notice instead of opening.
local TOP_NAV = {
	{ window = "Packs", text = "PACKS", style = "Green" },
	{ window = "Display", text = "MY STANDS", style = "Blue" },
	{ window = "__home", text = "MY PLOT", style = "Orange" },
}
local RIGHT_NAV = {
	{ window = "Backpack", text = "BAG", style = "Orange" },
	{ window = "Binder", text = "BINDER", style = "Purple" },
	{ window = "Upgrades", text = "UPGRADES", style = "Green" },
	{ window = "Settings", text = "SETTINGS", style = "Gray" },
}

local function navigate(window: string)
	if window == "__home" then
		Request(Remotes.Functions.TeleportHome)
		return
	end
	if Windows.has(window) then
		Windows.toggle(window)
	else
		NotificationController:Push("Coming soon!", "info")
	end
end

local function cashText(amount: number): string
	return if amount < 1e9 then Format.commas(amount) else Format.short(amount)
end

local function buildStats(gui: ScreenGui)
	local panel = Create("Frame", {
		Name = "Stats",
		Size = UDim2.fromOffset(320, 262),
		Position = UDim2.new(0, 16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	Components.autoScale(panel)

	local function row(order: number, height: number): Frame
		return Create("Frame", {
			Name = "Row" .. order,
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = panel,
		})
	end

	local cashRow = row(1, 52)
	Components.badge("$", Theme.Colors.Cash, UDim2.fromOffset(52, 52)).Parent = cashRow
	local cash = Components.label({
		Name = "Cash",
		Text = "0",
		Size = UDim2.new(1, -64, 1, 0),
		Position = UDim2.fromOffset(64, 0),
		Color = Theme.Colors.Cash,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		Parent = cashRow,
	})

	local income = Components.label({
		Name = "Income",
		Text = "+0 CASH/S",
		Size = UDim2.new(1, -12, 0, 26),
		Color = Theme.Colors.Cash,
		XAlign = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = panel,
	})

	local treatsRow = row(3, 40)
	Components.badge("T", Theme.Colors.Treats, UDim2.fromOffset(40, 40)).Parent = treatsRow
	local treats = Components.label({
		Name = "Treats",
		Text = "0",
		Size = UDim2.new(1, -52, 1, 0),
		Position = UDim2.fromOffset(52, 0),
		Color = Theme.Colors.Treats,
		XAlign = Enum.TextXAlignment.Left,
		Parent = treatsRow,
	})

	local levelRow = row(4, 40)
	local levelPlate = Create("Frame", {
		Size = UDim2.fromOffset(200, 40),
		BackgroundColor3 = Theme.Colors.Panel,
		Parent = levelRow,
	}, { Components.corner(UDim.new(0, 10)), Components.stroke(Theme.Colors.Border, 3) })
	local levelText = Components.label({
		Text = "LV 1",
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 2),
		Parent = levelPlate,
	})
	local bar, setProgress = Components.progressBar(Theme.Colors.Level, UDim2.new(1, -16, 0, 10))
	bar.Position = UDim2.new(0, 8, 1, -14)
	bar.Parent = levelPlate

	-- Central collection of every stand's earnings (owner decision Q3).
	local collect = Components.button({
		Name = "CollectAll",
		Text = "NOTHING TO COLLECT",
		Style = "Gray",
		Size = UDim2.fromOffset(260, 52),
		LayoutOrder = 5,
		Parent = panel,
		OnClick = function()
			local result = Request(Remotes.Functions.CollectEarnings, 0)
			if result.ok and (result.collected or 0) > 0 then
				NotificationController:Push(`Collected ${Format.short(result.collected, 1e6)}`, "success")
			end
		end,
	})
	local function refreshPending(data: Types.PlayerData)
		local pending = math.floor(IncomeLedger.pendingTotal(data))
		Components.setButtonText(
			collect,
			if pending > 0 then `COLLECT ${Format.short(pending)}` else "NOTHING TO COLLECT"
		)
		Components.setButtonStyle(collect, if pending > 0 then "Green" else "Gray")
	end

	local function refreshCurrency(data: Types.PlayerData)
		cash.Text = cashText(data.Currency.Cash or 0)
		treats.Text = Format.commas(data.Currency.Treats or 0)
	end
	local function refreshIncome(data: Types.PlayerData)
		income.Text = `+{Format.short(Economy.totalIncome(data), 1e6)} CASH/S`
	end
	local function refreshLevel(data: Types.PlayerData)
		local level, xp = data.Progression.Level, data.Progression.Xp
		levelText.Text = `LV {level}`
		setProgress(xp / Progression.xpToNext(level))
	end

	DataController:Observe("Currency", refreshCurrency)
	for _, key in { "Display", "Cards", "Upgrades", "Discovered" } do
		DataController:Observe(key, refreshIncome)
	end
	DataController:Observe("Progression", refreshLevel)
	DataController:Observe("Income", refreshPending)
end

local function buildTopNav(gui: ScreenGui)
	local bar = Create("Frame", {
		Name = "TopNav",
		Size = UDim2.fromOffset(640, 64),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}),
	})
	Components.autoScale(bar)
	for i, entry in TOP_NAV do
		Components.button({
			Text = entry.text,
			Style = entry.style,
			Size = UDim2.fromOffset(196, 60),
			LayoutOrder = i,
			Parent = bar,
			OnClick = function()
				navigate(entry.window)
			end,
		})
	end
end

local function buildRightRail(gui: ScreenGui)
	local rail = Create("Frame", {
		Name = "RightRail",
		Size = UDim2.fromOffset(112, 4 * 88),
		Position = UDim2.new(1, -16, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 10),
		}),
	})
	Components.autoScale(rail)
	for i, entry in RIGHT_NAV do
		Components.button({
			Text = entry.text,
			Style = entry.style,
			Size = UDim2.fromOffset(112, 76),
			LayoutOrder = i,
			Parent = rail,
			OnClick = function()
				navigate(entry.window)
			end,
		})
	end
end

function HUDController:Start()
	local gui = Create("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	buildStats(gui)
	buildTopNav(gui)
	buildRightRail(gui)
end

return HUDController
