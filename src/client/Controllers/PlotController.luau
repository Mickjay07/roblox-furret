--!strict
-- Interaction with physical stands (spec §8, §10).
--
-- Prompts are created locally, so each player only sees the prompts that apply to them:
--   * own stands:   Place / Change card (opens the backpack for that stand), Collect $X
--   * other stands: Inspect (read-only)
-- Every action goes through the existing validated remotes (PlaceCard, CollectEarnings),
-- which only ever touch the caller's own data, i.e. their own plot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local CardRegistry = require(Shared.Logic.CardRegistry)
local IncomeLedger = require(Shared.Logic.IncomeLedger)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent.UI
local Components = require(UI.Components)
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Windows = require(UI.Windows)
local Request = require(script.Parent.Parent.Lib.Request)
local BackpackController = require(script.Parent.BackpackController)
local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local PlotController = {}

-- Height of the earnings counter above the stand anchor: above the floating illustration's
-- top edge (its centre offset + half its height) and its variant tag.
local ILLUSTRATION = Config.Visuals.Illustration
local ABOVE_CARD = ILLUSTRATION.HeightOffset + (ILLUSTRATION.WidthStuds * 1.5) / 2 + 1.3

local localPlayer = Players.LocalPlayer

type StandUI = {
	stand: Model,
	slot: number,
	place: ProximityPrompt,
	collect: ProximityPrompt,
	inspect: ProximityPrompt,
	earnings: BillboardGui,
	earningsLabel: TextLabel,
}

local stands: { [Model]: StandUI } = {}

local function prompt(parent: Instance, name: string, key: Enum.KeyCode, order: number): ProximityPrompt
	return Create("ProximityPrompt", {
		Name = name,
		KeyboardKeyCode = key,
		HoldDuration = 0,
		MaxActivationDistance = 9,
		RequiresLineOfSight = false,
		UIOffset = Vector2.new(0, order * 72),
		Enabled = false,
		Parent = parent,
	})
end

local function isMine(stand: Model): boolean
	return stand:GetAttribute("OwnerUserId") == localPlayer.UserId
end

local function update(ui: StandUI)
	local stand = ui.stand
	local mine = isMine(stand)
	local unlocked = stand:GetAttribute("Unlocked") == true
	local cardId = stand:GetAttribute("CardId")
	local def = if type(cardId) == "string" then CardRegistry.get(cardId) else nil

	ui.place.Enabled = mine
	ui.place.ObjectText = `Stand #{ui.slot}`
	ui.place.ActionText = if not unlocked then "Locked: buy stands" elseif def then "Change card" else "Place card"

	local data = DataController:Get()
	local pending = if mine and data then math.floor(IncomeLedger.pending(data, tostring(ui.slot))) else 0
	ui.collect.Enabled = mine and pending > 0
	ui.collect.ActionText = `Collect ${Format.short(pending)}`
	ui.collect.ObjectText = `Stand #{ui.slot}`
	ui.earnings.Enabled = mine and pending > 0
	ui.earningsLabel.Text = Format.short(pending, 1e4)
	-- Above the floating card when there is one, otherwise just above the pedestal.
	ui.earnings.StudsOffset = Vector3.new(0, if def then ABOVE_CARD else 1.2, 0)

	ui.inspect.Enabled = not mine and def ~= nil
	ui.inspect.ObjectText = if def then def.Name else ""
	ui.inspect.ActionText = "Inspect"
end

local function track(stand: Model)
	if stands[stand] then
		return
	end
	local base = stand:WaitForChild("Base", 5)
	local anchor = stand:WaitForChild("Anchor", 5)
	local slot = stand:GetAttribute("Slot")
	if not base or not anchor or not anchor:IsA("BasePart") or type(slot) ~= "number" then
		return
	end
	-- Uncollected-cash counter: a gold-trimmed pill sized in studs (it shrinks with distance
	-- like the card). It floats above the card's top edge so the illustration never covers
	-- it (update() moves it down to the pedestal when the stand has no card).
	local earnings: BillboardGui = Create("BillboardGui", {
		Name = "Earnings",
		Adornee = anchor,
		Size = UDim2.new(3.8, 0, 0.95, 0),
		StudsOffset = Vector3.new(0, ABOVE_CARD, 0),
		LightInfluence = 0,
		MaxDistance = 70,
		Enabled = false,
		Parent = anchor,
	})
	local pill = Create("Frame", {
		Name = "Pill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.PanelDeep,
		Parent = earnings,
	}, {
		Components.corner(UDim.new(1, 0)),
		Create("UIStroke", { Color = Theme.Colors.Gold, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 185, 170)),
		}),
	})
	local coin = Create("Frame", {
		Name = "Coin",
		Size = UDim2.fromScale(0.24, 0.86),
		Position = UDim2.fromScale(0.04, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Colors.Gold,
		Parent = pill,
	}, {
		Components.corner(UDim.new(1, 0)),
		Components.stroke(Theme.Colors.GoldDark, 2),
		Create("UIAspectRatioConstraint", { AspectRatio = 1 }),
	})
	Components.label({
		Text = "$",
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Colors.BrownDark,
		StrokeThickness = 0,
		Parent = coin,
	})
	local label = Components.label({
		Text = "$0",
		Size = UDim2.fromScale(0.66, 0.78),
		Position = UDim2.fromScale(0.3, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = Theme.Colors.Cash,
		StrokeThickness = 2.5,
		Parent = pill,
	})
	local ui: StandUI = {
		stand = stand,
		slot = slot,
		place = prompt(base, "PlacePrompt", Enum.KeyCode.E, 0),
		collect = prompt(base, "CollectPrompt", Enum.KeyCode.F, 1),
		inspect = prompt(base, "InspectPrompt", Enum.KeyCode.E, 0),
		earnings = earnings,
		earningsLabel = label,
	}
	stands[stand] = ui

	ui.place.Triggered:Connect(function()
		if not isMine(stand) then
			return
		end
		if stand:GetAttribute("Unlocked") ~= true then
			Windows.open("Upgrades")
			NotificationController:Push("Buy more Display Stands in Upgrades to unlock this stand.", "info")
			return
		end
		BackpackController:OpenForStand(ui.slot)
	end)
	ui.collect.Triggered:Connect(function()
		local result = Request(Remotes.Functions.CollectEarnings, ui.slot)
		if result.ok and (result.collected or 0) > 0 then
			NotificationController:Push(`Collected ${Format.short(result.collected, 1e6)}`, "success")
		end
	end)
	ui.inspect.Triggered:Connect(function()
		local cardId = stand:GetAttribute("CardId")
		local def = if type(cardId) == "string" then CardRegistry.get(cardId) else nil
		if def then
			local rarity = Config.Rarities.ById[def.Rarity]
			local variant = stand:GetAttribute("Variant")
			NotificationController:Push(
				`{def.Name} ({if rarity then rarity.DisplayName else def.Rarity}{if variant
						and variant ~= "Normal"
					then ", " .. tostring(variant)
					else ""}): {def.Description}. Base +{Format.short(def.BaseIncome)}/s`,
				"info"
			)
		end
	end)
	for _, attribute in { "OwnerUserId", "Unlocked", "CardId" } do
		stand:GetAttributeChangedSignal(attribute):Connect(function()
			update(ui)
		end)
	end
	stand.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			earnings:Destroy()
			stands[stand] = nil
		end
	end)
	update(ui)
end

function PlotController:Start()
	local plots = workspace:WaitForChild("Plots")
	local function consider(instance: Instance)
		if instance:IsA("Model") and instance:GetAttribute("Slot") ~= nil then
			task.spawn(track, instance)
		end
	end
	for _, descendant in plots:GetDescendants() do
		consider(descendant)
	end
	plots.DescendantAdded:Connect(consider)

	DataController.Changed:Connect(function(key)
		if key == "Income" or key == "*" then
			for _, ui in stands do
				if isMine(ui.stand) then
					update(ui)
				end
			end
		end
	end)
end

return PlotController
