--!strict
-- Multi Opening GAME PASSES (3x, then 6x): ownership, prompts and purchase completion.
--
-- These are game passes, so there is no ProcessReceipt (that callback is for Developer
-- Products only; none are sold yet). Roblox is the source of truth for ownership:
--   * On join (profile loaded): UserOwnsGamePassAsync for each pass, with retries
--     (Lib/GamePassOwnership). Confirmed answers are mirrored into Purchases.Entitlements;
--     a failed query changes nothing and is retried later in the background, so an outage
--     never removes a pass the player owns.
--   * Purchase: PromptMultiOpen checks the 6x -> 3x prerequisite on the server, then
--     PromptGamePassPurchase. When the server-side PromptGamePassPurchaseFinished reports a
--     purchase, ownership is re-checked with UserOwnsGamePassAsync and only a confirmed
--     answer is recorded - never the event alone, never a client event.
--   * At server start each pass is read with GetProductInfo(Enum.InfoType.GamePass): sale
--     state and Robux price are logged and published on ReplicatedStorage.ProductInfo.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Entitlements = require(Shared.Logic.Entitlements)
local Validate = require(Shared.Util.Validate)

local Net = require(script.Parent.Parent.Lib.Net)
local GamePassOwnership = require(script.Parent.Parent.Lib.GamePassOwnership)
local DataService = require(script.Parent.DataService)

local MonetizationService = {}

-- Background re-checks after a failed ownership query (seconds after join).
local RETRY_DELAYS = { 20, 60, 180, 600 }

local productInfoFolder: Folder
-- Pass key -> true once GetProductInfo confirmed it is a game pass that is for sale.
local forSale: { [string]: boolean } = {}

local function query(userId: number, gamePassId: number): (boolean, any)
	return pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
	end)
end

local function pause(attempt: number)
	task.wait(attempt * 1.5)
end

-- A 6x pass without 3x is kept (it is the player's real ownership) but explained.
local function explainPrerequisites(player: Player, data: Types.PlayerData)
	for _, product in Entitlements.products() do
		if
			product.Requires
			and Entitlements.owns(data, product.Key)
			and not Entitlements.owns(data, product.Requires)
		then
			local kind, message = GamePassOwnership.purchaseMessage(data, product, "owned")
			DataService:Notify(player, message, kind)
		end
	end
end

-- Asks Roblox about every pass for this player. Returns true when all queries answered.
local function refresh(player: Player): boolean
	local data = DataService:GetData(player)
	if not data then
		return false
	end
	local _, changed, verified = GamePassOwnership.refreshAll(data, player.UserId, query, 3, pause)
	if player.Parent == nil or DataService:GetData(player) ~= data then
		return verified
	end
	if changed then
		DataService:Changed(player, "Purchases")
	end
	player:SetAttribute("GamePassesVerified", verified)
	return verified
end

local function onProfileLoaded(player: Player)
	player:SetAttribute("GamePassesVerified", false)
	task.spawn(function()
		if refresh(player) then
			local data = DataService:GetData(player)
			if data then
				explainPrerequisites(player, data)
			end
			return
		end
		warn(`[Monetization] Game pass ownership check failed for {player.Name}; retrying in the background`)
		for _, delay in RETRY_DELAYS do
			task.wait(delay)
			if player.Parent == nil then
				return
			end
			if refresh(player) then
				return
			end
		end
	end)
end

local function onPurchaseFinished(player: Player, gamePassId: number, wasPurchased: boolean)
	local product = Entitlements.productByPassId(gamePassId)
	if not product or not wasPurchased then
		return
	end
	local data = DataService:GetData(player)
	if not data then
		return
	end
	-- Confirm with Roblox before recording anything.
	local result = GamePassOwnership.check(query, player.UserId, gamePassId, 4, pause)
	if DataService:GetData(player) ~= data then
		return
	end
	if GamePassOwnership.apply(data, product.Key, result) then
		DataService:Changed(player, "Purchases")
	end
	local kind, message = GamePassOwnership.purchaseMessage(data, product, result)
	DataService:Notify(player, message, kind)
	if result ~= "owned" then
		-- Ownership not confirmed yet (API lag or outage): re-check shortly.
		task.delay(15, function()
			if player.Parent ~= nil then
				refresh(player)
			end
		end)
	end
end

local function readPassInfo()
	for _, product in Entitlements.products() do
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(product.GamePassId, Enum.InfoType.GamePass)
			end)
			local available, price, message = GamePassOwnership.checkInfo(product, if ok then info else nil)
			forSale[product.Key] = available
			productInfoFolder:SetAttribute(`{product.Key}_Price`, price)
			productInfoFolder:SetAttribute(`{product.Key}_Available`, available)
			if available and not string.find(message, "design says", 1, true) then
				print(`[Monetization] {message}`)
			else
				warn(`[Monetization] {message}{if ok then "" else ` ({info})`}`)
			end
		end)
	end
end

function MonetizationService:Init()
	productInfoFolder = Instance.new("Folder")
	productInfoFolder.Name = "ProductInfo"
	productInfoFolder.Parent = ReplicatedStorage
end

function MonetizationService:Start()
	readPassInfo()

	DataService.ProfileLoaded:Connect(onProfileLoaded)
	-- Profiles that loaded before this Start ran (services start concurrently).
	for _, player in Players:GetPlayers() do
		if DataService:GetData(player) and player:GetAttribute("GamePassesVerified") == nil then
			onProfileLoaded(player)
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPurchaseFinished)

	local keys: { [string]: boolean } = {}
	for _, product in Entitlements.products() do
		keys[product.Key] = true
	end
	Net.onInvoke(Remotes.Functions.PromptMultiOpen, { Validate.oneOf(keys) }, function(player: Player, key: string)
		local data = DataService:GetData(player)
		if not data then
			return { ok = false, error = "Data not loaded" }
		end
		-- Server-side prerequisite: 6x can only be prompted once 3x is owned.
		local ok, reason = Entitlements.canPurchase(data, key)
		if not ok then
			return { ok = false, error = reason }
		end
		local product = Entitlements.product(key)
		if not product or not forSale[key] then
			return { ok = false, error = "This pass isn't available right now" }
		end
		MarketplaceService:PromptGamePassPurchase(player, product.GamePassId)
		return { ok = true }
	end)
end

return MonetizationService
