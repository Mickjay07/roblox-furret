--!strict
-- Owns every player's saved profile: load on join, autosave, save on leave and on shutdown,
-- and replication of changes to the owning client.
--
-- Other services read and mutate profile data through GetData(player) and must then call
-- Changed/Patched so the client stays in sync. Data for a player who failed to load is
-- never available, and such players are kicked: nothing can be saved over their real data.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local ProfileSchema = require(Shared.Data.ProfileSchema)
local Account = require(Shared.Logic.Account)
local Signal = require(Shared.Util.Signal)

local Lib = script.Parent.Parent.Lib
local MockDataStore = require(Lib.MockDataStore)
local Net = require(Lib.Net)
local SessionStore = require(Lib.SessionStore)

local DataSettings = Config.Game.Data

local DataService = {}

-- Fires after a profile is loaded and ready, before the client receives its snapshot.
DataService.ProfileLoaded = Signal.new() :: Signal.Signal<Player, Types.PlayerData>
-- Fires just before a profile is saved for the last time (player leaving or shutdown).
DataService.ProfileReleasing = Signal.new() :: Signal.Signal<Player, Types.PlayerData>

local sessions: SessionStore.SessionStore
local profiles: { [Player]: SessionStore.Profile } = {}
local usingMockStore = false
local shuttingDown = false

local function keyFor(player: Player): string
	return DataSettings.KeyPrefix .. tostring(player.UserId)
end

local function createStore(): any
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(DataSettings.StoreName)
	end)
	if ok then
		-- Probe once: in Studio without API access every request errors.
		local probeOk, probeErr = pcall(function()
			return (store :: DataStore):GetAsync("__probe")
		end)
		if probeOk then
			return store
		end
		store = probeErr
	end
	if RunService:IsStudio() and DataSettings.UseMockStoreInStudio then
		usingMockStore = true
		warn(
			"[DataService] DataStores unavailable in Studio ("
				.. tostring(store)
				.. "). Using an in-memory store: progress will NOT be saved. "
				.. "Enable Game Settings > Security > Enable Studio Access to API Services to test real saving."
		)
		return MockDataStore.new()
	end
	-- Live servers keep the real store: loads will retry and kick on failure, never reset data.
	warn(`[DataService] DataStore setup problem: {store}`)
	return DataStoreService:GetDataStore(DataSettings.StoreName)
end

local function setupLeaderstats(player: Player, data: Types.PlayerData)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Value = data.Currency.Cash or 0
	cash.Parent = leaderstats
	leaderstats.Parent = player
end

local function updateLeaderstats(player: Player, data: Types.PlayerData)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("NumberValue") then
		cash.Value = data.Currency.Cash or 0
	end
end

local function onPlayerAdded(player: Player)
	if shuttingDown then
		return
	end
	local profile, reason = sessions:load(keyFor(player))
	if not profile then
		warn(`[DataService] Could not load data for {player.Name} ({player.UserId}): {reason}`)
		if player.Parent then
			player:Kick("We couldn't load your data safely. Please rejoin in a minute. (" .. tostring(reason) .. ")")
		end
		return
	end
	if not player.Parent or shuttingDown then
		-- Left (or the server began closing) while loading: release straight away.
		sessions:release(profile)
		return
	end

	profile.OnLost = function()
		profiles[player] = nil
		if player.Parent then
			player:Kick("Your data was opened on another server. Please rejoin.")
		end
	end

	local data = profile.Data :: Types.PlayerData
	local now = os.time()
	Account.recordJoin(data, now)
	local grantedStarter = Account.grantStarter(data)
	profiles[player] = profile

	setupLeaderstats(player, data)
	DataService.ProfileLoaded:Fire(player, data)
	Net.fire(player, Remotes.Events.DataChanged, "__snapshot", data)
	if grantedStarter then
		Net.notify(
			player,
			"Welcome to Ferret Card Tycoon! Open your starter packs in PACKS, then put your ferrets on stands.",
			"success"
		)
	end
	if usingMockStore then
		Net.notify(player, "Studio test mode: progress is not saved.", "warning")
	end
end

local function releasePlayer(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	local data = profile.Data :: Types.PlayerData
	DataService.ProfileReleasing:Fire(player, data)
	Account.addPlayTime(data, os.time() - profile.LoadedAt)
	if not sessions:release(profile) then
		warn(`[DataService] Final save failed for {player.Name}; lock expires in {DataSettings.LockExpirySeconds}s`)
	end
end

local function autosaveLoop()
	while true do
		task.wait(DataSettings.AutosaveInterval)
		local list = {}
		for player, profile in profiles do
			table.insert(list, { player = player, profile = profile })
		end
		-- Spread saves across the interval to stay well inside DataStore budgets.
		local gap = if #list > 0 then math.min(1, DataSettings.AutosaveInterval / (#list + 1)) else 0
		for _, entry in list do
			if profiles[entry.player] == entry.profile and entry.profile.Active then
				task.spawn(function()
					sessions:save(entry.profile)
				end)
				task.wait(gap)
			end
		end
	end
end

local function onShutdown()
	shuttingDown = true
	local started = os.clock()
	for player in profiles do
		task.spawn(releasePlayer, player)
	end
	-- Wait for every in-flight save/release (including PlayerRemoving ones) to finish.
	task.wait()
	while sessions:pendingCount() > 0 and os.clock() - started < DataSettings.ShutdownTimeout do
		task.wait(0.25)
	end
	if sessions:pendingCount() > 0 then
		warn("[DataService] Shutdown timed out with saves still pending")
	end
end

-- Public API -----------------------------------------------------------------

-- The live (mutable) data for a loaded player, or nil if not loaded.
function DataService:GetData(player: Player): Types.PlayerData?
	local profile = profiles[player]
	return if profile and profile.Active then profile.Data :: Types.PlayerData else nil
end

-- Replicates a whole top-level field after it changed.
function DataService:Changed(player: Player, key: string)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	Net.fire(player, Remotes.Events.DataChanged, key, (data :: any)[key])
	if key == "Currency" then
		updateLeaderstats(player, data)
	end
end

-- Replicates changed entries of a map field (Cards, Discovered, ...) without resending it all.
function DataService:Patched(player: Player, key: string, changedKeys: { string })
	local data = DataService:GetData(player)
	if not data or #changedKeys == 0 then
		return
	end
	local map = (data :: any)[key]
	local set, remove = {}, {}
	for _, subKey in changedKeys do
		local value = map[subKey]
		if value == nil then
			table.insert(remove, subKey)
		else
			set[subKey] = value
		end
	end
	Net.fire(player, Remotes.Events.DataPatched, key, set, remove)
end

function DataService:Notify(player: Player, message: string, kind: string?)
	Net.notify(player, message, kind)
end

-- Lifecycle ------------------------------------------------------------------

function DataService:Init()
	Net.init()
end

function DataService:Start()
	sessions = SessionStore.new({
		store = createStore(),
		jobId = if game.JobId ~= "" then game.JobId else "studio-" .. tostring(os.time()),
		settings = DataSettings,
		defaults = ProfileSchema.defaults,
		migrate = function(raw)
			return ProfileSchema.migrate(raw)
		end,
		clock = os.time,
		wait = function(seconds)
			task.wait(seconds)
		end,
		log = warn,
	})

	Net.onInvoke(Remotes.Functions.GetSnapshot, {}, function(player)
		local data = DataService:GetData(player)
		return if data then { ok = true, data = data } else { ok = false, error = "loading" }
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(releasePlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	game:BindToClose(onShutdown)
	task.spawn(autosaveLoop)
end

return DataService
