--!strict
-- Main HUD, following the reference layout: currency and level on the left, primary
-- actions top-centre, feature rail on the right, notifications bottom-right.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local CardArt = require(Shared.Logic.CardArt)
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
local ArtDiagnostics = require(script.Parent.Parent.Lib.ArtDiagnostics)
local ImageBounds = require(script.Parent.Parent.Lib.ImageBounds)
local Request = require(script.Parent.Parent.Lib.Request)

local HUDController = {}

-- Navigation entries: window name, label, button style. Windows that are not registered
-- (features not built yet) show a "coming soon" notice instead of opening.
local TOP_NAV = {
	{ window = "Packs", text = "PACKS", style = "Gold" },
	{ window = "Display", text = "MY STANDS", style = "Green" },
	{ window = "__home", text = "MY PLOT", style = "Brown" },
}
-- `icon` is a Config.Assets key for the custom HUD art; without an uploaded image the entry
-- falls back to a text button.
local RIGHT_NAV = {
	{ window = "Backpack", text = "BAG", style = "Orange", icon = "ui.icon.backpack" },
	{ window = "Binder", text = "BINDER", style = "Purple", icon = "ui.icon.binder" },
	{ window = "Upgrades", text = "UPGRADES", style = "Green", icon = "ui.icon.upgrades" },
	{ window = "Settings", text = "SETTINGS", style = "Gray", icon = "ui.icon.settings" },
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

-- The money display: the custom currency bar art with the value as a separate TextLabel
-- over its green area (Config.Visuals.Hud.CurrencyBar), or the plain badge row when the
-- art isn't available. Returns the row and the label that shows the cash value.
local function buildCashRow(panel: Frame): (Frame, TextLabel)
	local layout = Config.Visuals.Hud.CurrencyBar
	local image = CardArt.image("ui.currency_bar")
	if not image then
		ArtDiagnostics.fallback("HUD", "ui.currency_bar")
		local row = Create("Frame", {
			Name = "Row1",
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = panel,
		})
		Components.badge("$", Theme.Colors.Cash, UDim2.fromOffset(52, 52)).Parent = row
		local label = Components.label({
			Name = "Cash",
			Text = "0",
			Size = UDim2.new(1, -64, 1, 0),
			Position = UDim2.fromOffset(64, 0),
			Color = Theme.Colors.Cash,
			XAlign = Enum.TextXAlignment.Left,
			StrokeThickness = 3,
			Parent = row,
		})
		return row, label
	end
	ArtDiagnostics.watch("HUD", "ui.currency_bar", image)
	local row = Create("Frame", {
		Name = "CurrencyBar",
		Size = UDim2.fromOffset(layout.Width, layout.Width / layout.Aspect),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = panel,
	})
	-- Decorative: keeps its aspect (Fit) and never takes input.
	Create("ImageLabel", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,
		Active = false,
		ZIndex = 1,
		Parent = row,
	})
	local art = row:FindFirstChild("Art") :: ImageLabel
	local label: TextLabel = Create("TextLabel", {
		Name = "Cash",
		Text = "0",
		Position = UDim2.fromScale(layout.TextInsetLeft, layout.TextInsetTop),
		Size = UDim2.fromScale(
			1 - layout.TextInsetLeft - layout.TextInsetRight,
			1 - layout.TextInsetTop - layout.TextInsetBottom
		),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Active = false,
		ZIndex = 2,
		Parent = row,
	}, {
		-- TextScaled shrinks long values (millions, billions) to fit; these keep short values
		-- from growing huge and long ones readable.
		Create("UITextSizeConstraint", { MaxTextSize = layout.MaxTextSize, MinTextSize = layout.MinTextSize }),
		Create("UIStroke", {
			Color = Theme.Colors.TextStroke,
			Thickness = 2.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}),
	})
	-- Once the art's real pixels are known: crop away transparent margins (so the bar starts
	-- right at the panel's left edge instead of being letterboxed), use its true aspect, and
	-- put the text exactly on the detected green field.
	ImageBounds.get("ui.currency_bar", image, true, function(measurement)
		if not measurement or not row.Parent then
			return
		end
		ImageBounds.crop(art, measurement)
		row.Size = UDim2.fromOffset(layout.Width, layout.Width / ImageBounds.aspect(measurement))
		local green = measurement.Green
		if green then
			local width = 1 - green.Left - green.Right
			local height = 1 - green.Top - green.Bottom
			-- Keep the text slightly inside the green field.
			label.Position = UDim2.fromScale(green.Left + width * 0.04, green.Top + height * 0.12)
			label.Size = UDim2.fromScale(width * 0.92, height * 0.76)
		end
	end)
	return row, label
end

local function buildStats(gui: ScreenGui)
	local barLayout = Config.Visuals.Hud.CurrencyBar
	local hasBar = CardArt.image("ui.currency_bar") ~= nil
	local width = if hasBar then math.max(320, barLayout.Width) else 320
	local panel = Create("Frame", {
		Name = "Stats",
		-- Height follows the rows (the currency bar's height depends on the measured art).
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, Config.Visuals.Hud.LeftMargin, 0.5, 0),
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

	local _, cash = buildCashRow(panel)

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
	}, { Components.corner(UDim.new(0, 12)), Components.stroke(Theme.Colors.Gold, 2.5) })
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
		Components.setButtonStyle(collect, if pending > 0 then "Gold" else "Gray")
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
	local iconSize = Config.Visuals.Hud.IconSize
	local captions = Config.Visuals.Hud.ShowCaptions
	-- Icons may grow up to 25% to balance their visible area (see below).
	local maxIcon = math.floor(iconSize * 1.25)
	-- Each slot: the icon (or a 76 px text button) plus room for its caption.
	local slot = math.max(76, iconSize + (if captions then math.floor(iconSize * 0.24) else 0))
	local railWidth = math.max(112, maxIcon)
	local rail = Create("Frame", {
		Name = "RightRail",
		Size = UDim2.fromOffset(railWidth, #RIGHT_NAV * (slot + 10)),
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
		local image = CardArt.image(entry.icon)
		if image then
			ArtDiagnostics.watch("HUD", entry.icon, image)
			-- Wrapper reserves the caption's height so the list layout spaces icons evenly.
			local holder = Create("Frame", {
				Name = entry.window,
				Size = UDim2.fromOffset(railWidth, slot),
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Parent = rail,
			})
			local button = Components.iconButton({
				Image = image,
				Caption = if captions then entry.text else nil,
				Size = iconSize,
				Name = "Button",
				Parent = holder,
				OnClick = function()
					navigate(entry.window)
				end,
			})
			-- Centre each icon on the same vertical axis so the column lines up.
			button.AnchorPoint = Vector2.new(0.5, 0.5)
			button.Position = UDim2.new(0.5, 0, 0, iconSize / 2)
			local manual = Config.Visuals.Hud.IconScale[entry.icon] or 1
			local function applySize(balance: number)
				local size = math.min(maxIcon, math.floor(iconSize * balance * manual))
				button.Size = UDim2.fromOffset(size, size)
			end
			applySize(1)
			-- Crop to the visible art, then give wide or tall art a little more room so its
			-- visible area matches the square icons (Fit shrinks a non-square image).
			ImageBounds.get(entry.icon, image, false, function(measurement)
				if not measurement or not button.Parent then
					return
				end
				ImageBounds.crop(button, measurement)
				local aspect = ImageBounds.aspect(measurement)
				applySize(math.clamp(math.sqrt(math.max(aspect, 1 / aspect)), 1, 1.25))
			end)
		else
			ArtDiagnostics.fallback("HUD", entry.icon)
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
end

function HUDController:Start()
	local gui = Create("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		-- Keep the HUD clear of notches, rounded corners and the home indicator on phones.
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	buildStats(gui)
	buildTopNav(gui)
	buildRightRail(gui)
end

return HUDController
