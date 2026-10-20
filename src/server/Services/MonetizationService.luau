--!strict
-- Robux purchases: GAME PASSES (permanent) and DEVELOPER PRODUCTS (repeatable).
--
-- Game passes (VIP, 2x AFK Time Cash, Multi Opening 3x/6x, ...): Roblox is the source of
-- truth for ownership.
--   * On join (profile loaded): UserOwnsGamePassAsync for each pass, with retries
--     (Lib/GamePassOwnership). Confirmed answers are mirrored into Purchases.Entitlements;
--     a failed query changes nothing and is retried later in the background, so an outage
--     never removes a pass the player owns.
--   * Purchase: PromptGamePass checks prerequisites (6x needs 3x) on the server, then
--     PromptGamePassPurchase. When the server-side PromptGamePassPurchaseFinished reports a
--     purchase, ownership is re-checked with UserOwnsGamePassAsync and only a confirmed
--     answer is recorded - never the event alone, never a client event.
--   * Game passes never go through ProcessReceipt.
--
-- Developer products (packs, treats, limited bundles): granted ONLY in ProcessReceipt
-- (Lib/ReceiptProcessor), idempotent per PurchaseId and saved before PurchaseGranted. A
-- cancelled prompt produces no receipt and grants nothing; PromptProductPurchaseFinished is
-- not used to grant.
--
-- At server start every pass (Enum.InfoType.GamePass) and product (Enum.InfoType.Product) is
-- read with GetProductInfo: sale state and Robux price are logged and published on
-- ReplicatedStorage.ProductInfo as `{Key}_Price` / `{Key}_Available` attributes.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Entitlements = require(Shared.Logic.Entitlements)
local Products = require(Shared.Logic.Products)
local Validate = require(Shared.Util.Validate)

local Net = require(script.Parent.Parent.Lib.Net)
local GamePassOwnership = require(script.Parent.Parent.Lib.GamePassOwnership)
local ReceiptProcessor = require(script.Parent.Parent.Lib.ReceiptProcessor)
local DataService = require(script.Parent.DataService)

local MonetizationService = {}

-- Background re-checks after a failed ownership query (seconds after join).
local RETRY_DELAYS = { 20, 60, 180, 600 }

local productInfoFolder: Folder
-- Key -> true once GetProductInfo confirmed the pass / product is for sale.
local forSale: { [string]: boolean } = {}

local function query(userId: number, gamePassId: number): (boolean, any)
	return pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
	end)
end

local function pause(attempt: number)
	task.wait(attempt * 1.5)
end

-- A pass owned without its prerequisite (6x without 3x) is kept but explained.
local function explainPrerequisites(player: Player, data: Types.PlayerData)
	for _, product in Entitlements.passes() do
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
	-- Set once the first round of queries finished, whatever the answer (see WaitForVerification).
	player:SetAttribute("GamePassesChecked", true)
	return verified
end

-- Paid random items (Robux packs) must not be sold where Roblox restricts them. Unknown
-- (the policy query failed) counts as restricted.
local function checkPolicy(player: Player)
	player:SetAttribute("PaidRandomItemsRestricted", true)
	task.spawn(function()
		local ok, policy = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if player.Parent == nil then
			return
		end
		local restricted = not ok or type(policy) ~= "table" or policy.ArePaidRandomItemsRestricted ~= false
		player:SetAttribute("PaidRandomItemsRestricted", restricted)
		if not ok then
			warn(`[Monetization] Policy check failed for {player.Name}: {policy}; Robux packs hidden`)
		end
	end)
end

local function onProfileLoaded(player: Player)
	checkPolicy(player)
	player:SetAttribute("GamePassesVerified", false)
	player:SetAttribute("GamePassesChecked", false)
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

local function publish(key: string, available: boolean, price: number?, message: string, ok: boolean, err: any)
	forSale[key] = available
	productInfoFolder:SetAttribute(`{key}_Price`, price)
	productInfoFolder:SetAttribute(`{key}_Available`, available)
	if available and not string.find(message, "design says", 1, true) then
		print(`[Monetization] {message}`)
	else
		warn(`[Monetization] {message}{if ok then "" else ` ({err})`}`)
	end
end

local function readProductInfo()
	for _, product in Entitlements.passes() do
		if product.GamePassId > 0 then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(product.GamePassId, Enum.InfoType.GamePass)
				end)
				local available, price, message = GamePassOwnership.checkInfo(product, if ok then info else nil)
				publish(product.Key, available, price, message, ok, info)
			end)
		else
			productInfoFolder:SetAttribute(`{product.Key}_Available`, false)
		end
	end
	for _, product in Products.list() do
		if product.ProductId > 0 then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(product.ProductId, Enum.InfoType.Product)
				end)
				local available, price, message = Products.checkInfo(product, if ok then info else nil)
				publish(product.Key, available, price, message, ok, info)
			end)
		else
			productInfoFolder:SetAttribute(`{product.Key}_Available`, false)
		end
	end
end

-- Waits (up to `timeout` seconds) until the join-time game pass check has finished, so
-- pass effects that apply once at join (2x AFK Time Cash) see the real ownership. Returns
-- true when the check finished in time; otherwise callers fall back to the cached
-- Purchases.Entitlements.
function MonetizationService:WaitForVerification(player: Player, timeout: number): boolean
	local deadline = os.clock() + timeout
	while player.Parent ~= nil and player:GetAttribute("GamePassesChecked") ~= true do
		if os.clock() >= deadline then
			return false
		end
		task.wait(0.25)
	end
	return player:GetAttribute("GamePassesChecked") == true
end

function MonetizationService:Init()
	productInfoFolder = Instance.new("Folder")
	productInfoFolder.Name = "ProductInfo"
	productInfoFolder.Parent = ReplicatedStorage
end

function MonetizationService:Start()
	readProductInfo()

	DataService.ProfileLoaded:Connect(onProfileLoaded)
	-- Profiles that loaded before this Start ran (services start concurrently).
	for _, player in Players:GetPlayers() do
		if DataService:GetData(player) and player:GetAttribute("GamePassesVerified") == nil then
			onProfileLoaded(player)
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPurchaseFinished)

	local processor = ReceiptProcessor.new({
		getData = function(userId: number)
			local player = Players:GetPlayerByUserId(userId)
			return if player then DataService:GetData(player) else nil
		end,
		save = function(userId: number)
			local player = Players:GetPlayerByUserId(userId)
			return player ~= nil and DataService:SaveNow(player)
		end,
		changed = function(userId: number, keys: { string }, product: Products.Product)
			local player = Players:GetPlayerByUserId(userId)
			if not player then
				return
			end
			for _, key in keys do
				DataService:Changed(player, key)
			end
			DataService:Notify(
				player,
				`Thanks for buying {product.DisplayName}! {Products.describe(product)}.`,
				"success"
			)
		end,
		now = os.time,
	})
	MarketplaceService.ProcessReceipt = function(receipt)
		local ok, decision, outcome = pcall(processor.process, receipt)
		if not ok then
			warn(`[Monetization] ProcessReceipt error for purchase {receipt.PurchaseId}: {decision}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if outcome ~= "granted" and outcome ~= "duplicate" then
			warn(
				`[Monetization] Receipt {receipt.PurchaseId} (product {receipt.ProductId}) not processed yet: {outcome}`
			)
		end
		return if decision == "PurchaseGranted"
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local passKeys: { [string]: boolean } = {}
	for _, product in Entitlements.passes() do
		passKeys[product.Key] = true
	end
	Net.onInvoke(Remotes.Functions.PromptGamePass, { Validate.oneOf(passKeys) }, function(player: Player, key: string)
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

	local productKeys: { [string]: boolean } = {}
	for _, product in Products.list() do
		productKeys[product.Key] = true
	end
	Net.onInvoke(Remotes.Functions.PromptProduct, { Validate.oneOf(productKeys) }, function(player: Player, key: string)
		if not DataService:GetData(player) then
			return { ok = false, error = "Data not loaded" }
		end
		local product = Products.get(key)
		if not product or not Products.isOnSale(product, os.time()) or not forSale[key] then
			return { ok = false, error = "This item isn't available right now" }
		end
		if Products.isPaidRandom(product) and player:GetAttribute("PaidRandomItemsRestricted") ~= false then
			return { ok = false, error = "Robux packs aren't available in your region" }
		end
		-- Nothing is granted here: only ProcessReceipt grants, after Roblox charged.
		MarketplaceService:PromptProductPurchase(player, product.ProductId)
		return { ok = true }
	end)
end

return MonetizationService
