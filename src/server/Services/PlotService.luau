--!strict
-- Physical player plots (spec §8, owner decision Q4).
--
--   * A free plot is assigned automatically once the player's data has loaded safely (never
--     for a player whose load failed: they are kicked before ProfileLoaded fires).
--   * Ownership is unique (Logic/PlotAllocator) and released when the player leaves.
--   * Stand models mirror the owner's saved Display arrangement (Logic/PlotView) through
--     attributes (Unlocked, CardId, Variant); clients render illustrations from them.
--   * No remote accepts a plot or stand id: placement, removal and collection always act on
--     the caller's own data and therefore their own plot, so nobody can modify another
--     player's plot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PlotAllocator = require(Shared.Logic.PlotAllocator)
local PlotLayout = require(Shared.Logic.PlotLayout)
local PlotView = require(Shared.Logic.PlotView)

local Net = require(script.Parent.Parent.Lib.Net)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)
local DataService = require(script.Parent.DataService)

local PlotService = {}

local MAX_STANDS = PlotLayout.maxStands()
local REFRESH_KEYS = { Display = true, Cards = true, Upgrades = true }

local allocator = PlotAllocator.new(PlotLayout.count())
local plots: { [number]: WorldBuilder.PlotRefs } = {}

local function applyStands(index: number, states: { PlotView.StandState }, ownerUserId: number)
	local refs = plots[index]
	for _, state in states do
		local stand = refs.Stands[state.Slot]
		if stand then
			stand:SetAttribute("OwnerUserId", ownerUserId)
			stand:SetAttribute("Unlocked", state.Unlocked)
			stand:SetAttribute("CardId", state.CardId)
			stand:SetAttribute("Variant", state.Variant)
			local top = stand:FindFirstChild("Top")
			if top and top:IsA("BasePart") then
				top.Color = if state.Unlocked
					then Config.Visuals.World.Pedestal
					else Config.Visuals.World.PedestalLocked
				top.Transparency = if state.Unlocked then 0 else 0.35
			end
		end
	end
end

local function setOwner(index: number, player: Player?)
	local refs = plots[index]
	refs.Model:SetAttribute("OwnerUserId", if player then player.UserId else 0)
	refs.Model:SetAttribute("OwnerName", if player then player.DisplayName else nil)
	refs.OwnerLabel.Text = if player then `{string.upper(player.DisplayName)}'S PLOT` else "FREE PLOT"
	refs.Floor.Color = if player then Config.Visuals.World.PlotFloor else Config.Visuals.World.PlotFree
end

local function refresh(player: Player)
	local index = allocator:plotOf(player.UserId)
	local data = DataService:GetData(player)
	if index and data then
		applyStands(index, PlotView.standStates(data, MAX_STANDS), player.UserId)
	end
end

local function teleportToPlot(player: Player): boolean
	local index = allocator:plotOf(player.UserId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not index or not character or not root then
		return false
	end
	character:PivotTo(plots[index].Home.CFrame + Vector3.new(0, 4, 0))
	return true
end

local function onProfileLoaded(player: Player, _data: any)
	local index = allocator:assign(player.UserId)
	if not index then
		warn(`[PlotService] No free plot for {player.Name}; all {allocator:count()} plots are taken`)
		DataService:Notify(
			player,
			"All plots on this server are taken. You can still use My Stands from the menu; join another server for a plot.",
			"warning"
		)
		return
	end
	setOwner(index, player)
	refresh(player)
	-- Spawn at (and later respawn at) the player's own plot.
	player.CharacterAdded:Connect(function()
		task.defer(function()
			local character = player.Character
			if character then
				character:WaitForChild("HumanoidRootPart", 5)
			end
			teleportToPlot(player)
		end)
	end)
	if player.Character then
		teleportToPlot(player)
	end
end

local function onProfileReleasing(player: Player, _data: any)
	local index = allocator:release(player.UserId)
	if index then
		setOwner(index, nil)
		applyStands(index, PlotView.empty(MAX_STANDS), 0)
	end
end

-- Public API -------------------------------------------------------------------

function PlotService:PlotOf(player: Player): number?
	return allocator:plotOf(player.UserId)
end

function PlotService:TeleportHome(player: Player): boolean
	return teleportToPlot(player)
end

-- One line per plot, for developer diagnostics.
function PlotService:Describe(): string
	local lines = { `{allocator:count() - allocator:freeCount()}/{allocator:count()} plots owned:` }
	for index = 1, allocator:count() do
		local owner = allocator:ownerOf(index)
		local player = if owner then Players:GetPlayerByUserId(owner) else nil
		local shown = 0
		for _, stand in plots[index].Stands do
			if stand:GetAttribute("CardId") then
				shown += 1
			end
		end
		table.insert(
			lines,
			`  Plot {index}: {if player
				then player.Name .. " (" .. tostring(owner) .. ")"
				elseif owner then tostring(owner)
				else "free"}, {shown} cards displayed`
		)
	end
	return table.concat(lines, "\n")
end

-- Lifecycle -------------------------------------------------------------------

function PlotService:Init()
	local folder = WorldBuilder.folder("Plots", workspace)
	for index = 1, PlotLayout.count() do
		plots[index] = WorldBuilder.buildPlot(index, folder)
		setOwner(index, nil)
		applyStands(index, PlotView.empty(MAX_STANDS), 0)
	end
end

function PlotService:Start()
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	DataService.ProfileReleasing:Connect(onProfileReleasing)
	DataService.KeyChanged:Connect(function(player, key)
		if REFRESH_KEYS[key] then
			refresh(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- Safety net: ProfileReleasing normally handles this, but a player whose profile
		-- was lost (another server took it) must not keep a plot.
		local index = allocator:plotOf(player.UserId)
		if index then
			onProfileReleasing(player, nil)
		end
	end)
	-- Catch up on players whose profile finished loading before this service connected
	-- (Start methods run concurrently; the in-memory Studio store loads without yielding).
	for _, player in Players:GetPlayers() do
		local data = DataService:GetData(player)
		if data and not allocator:plotOf(player.UserId) then
			onProfileLoaded(player, data)
		end
	end
	Net.onInvoke(Remotes.Functions.TeleportHome, {}, function(player: Player)
		return if teleportToPlot(player) then { ok = true } else { ok = false, error = "You don't have a plot yet" }
	end)
end

return PlotService
