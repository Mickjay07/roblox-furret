--!strict
-- Multi Opening Developer Products (3x, then 6x): prompts, receipts and ownership.
--
-- This service is the ONLY place that sets MarketplaceService.ProcessReceipt (there was no
-- handler before it). Roblox allows one handler per server and the callback can't be read
-- back, so any future product must be added to handleReceipt below - never by assigning
-- ProcessReceipt again elsewhere, which would silently replace this one.
--
-- Ownership is granted ONLY from ProcessReceipt (never from a client purchase event):
-- the receipt is recorded in Purchases.Receipts together with the entitlement, the profile
-- is saved, and only then is PurchaseGranted returned. Duplicates replay PurchaseGranted
-- without granting twice; a failed save is reverted and retried later (NotProcessedYet).
--
-- At startup each product is checked with GetProductInfo(Enum.InfoType.Product): it must be
-- a Developer Product of this experience. The Robux price comes from the Roblox website and
-- is logged (and published as attributes on ReplicatedStorage.ProductInfo for the shop UI).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Entitlements = require(Shared.Logic.Entitlements)
local Validate = require(Shared.Util.Validate)

local Net = require(script.Parent.Parent.Lib.Net)
local ReceiptProcessor = require(script.Parent.Parent.Lib.ReceiptProcessor)
local DataService = require(script.Parent.DataService)

local MonetizationService = {}

-- Product key -> true once GetProductInfo confirmed it is a Developer Product.
local verified: { [string]: boolean } = {}
-- PurchaseIds being processed right now (ProcessReceipt can run concurrently).
local inFlight: { [string]: boolean } = {}
local productInfoFolder: Folder

local function handleReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local receipt: ReceiptProcessor.Receipt = {
		PurchaseId = tostring(receiptInfo.PurchaseId),
		ProductId = tonumber(receiptInfo.ProductId) or 0,
		PlayerId = tonumber(receiptInfo.PlayerId) or 0,
	}
	if not Entitlements.productById(receipt.ProductId) then
		-- Not a product this game knows (yet): keep it for a later server version.
		warn(`[Monetization] Unknown product {receipt.ProductId} in receipt {receipt.PurchaseId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = if player then DataService:GetData(player) else nil
	if not player or not data then
		-- Player left or profile not loaded: Roblox retries when they are back.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if inFlight[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	inFlight[receipt.PurchaseId] = true

	local outcome = ReceiptProcessor.process(data, receipt, os.time())
	local decision = Enum.ProductPurchaseDecision.NotProcessedYet
	if outcome.Decision == "Duplicate" then
		decision = Enum.ProductPurchaseDecision.PurchaseGranted
	elseif outcome.Decision == "Granted" then
		if DataService:SaveNow(player) then
			decision = Enum.ProductPurchaseDecision.PurchaseGranted
			DataService:Changed(player, "Purchases")
			local product = outcome.Product
			if product then
				DataService:Notify(
					player,
					if outcome.MissingPrerequisite
						then `{product.DisplayName} unlocked - it activates once you own the previous unlock`
						else `{product.DisplayName} unlocked! Open {product.Packs} packs at once.`,
					"success"
				)
			end
		else
			ReceiptProcessor.revert(data, receipt, outcome)
			warn(`[Monetization] Save failed for receipt {receipt.PurchaseId}; Roblox will retry it`)
		end
	end
	inFlight[receipt.PurchaseId] = nil
	return decision
end

local function verifyProducts()
	for _, product in Entitlements.products() do
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(product.ProductId, Enum.InfoType.Product)
			end)
			local valid, message = ReceiptProcessor.checkProductInfo(product, if ok then info else nil)
			if valid then
				verified[product.Key] = true
				productInfoFolder:SetAttribute(`{product.Key}_Price`, (info :: any).PriceInRobux)
				print(`[Monetization] {message}`)
			else
				-- Report what it actually is, so a game pass is never treated as a product.
				local passOk = pcall(function()
					return MarketplaceService:GetProductInfo(product.ProductId, Enum.InfoType.GamePass)
				end)
				warn(
					`[Monetization] {message}`
						.. if passOk
							then ". It looks like a GAME PASS id: game passes need a different purchase flow, so it is disabled."
							else ". It is disabled until this is fixed (in Studio, the place must be published)."
				)
			end
			productInfoFolder:SetAttribute(`{product.Key}_Available`, valid)
		end)
	end
end

function MonetizationService:Init()
	productInfoFolder = Instance.new("Folder")
	productInfoFolder.Name = "ProductInfo"
	productInfoFolder.Parent = ReplicatedStorage
end

function MonetizationService:Start()
	MarketplaceService.ProcessReceipt = handleReceipt
	verifyProducts()

	local keys: { [string]: boolean } = {}
	for _, product in Entitlements.products() do
		keys[product.Key] = true
	end
	Net.onInvoke(Remotes.Functions.PromptMultiOpen, { Validate.oneOf(keys) }, function(player: Player, key: string)
		local data = DataService:GetData(player)
		if not data then
			return { ok = false, error = "Data not loaded" }
		end
		local ok, reason = Entitlements.canPurchase(data, key)
		if not ok then
			return { ok = false, error = reason }
		end
		if not verified[key] then
			return { ok = false, error = "This purchase isn't available right now" }
		end
		local product = Entitlements.product(key)
		if not product then
			return { ok = false, error = "That item isn't available" }
		end
		MarketplaceService:PromptProductPurchase(player, product.ProductId)
		return { ok = true }
	end)
end

return MonetizationService
