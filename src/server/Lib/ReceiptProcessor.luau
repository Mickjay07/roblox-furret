--!strict
-- Developer Product receipts for the Multi Opening unlocks (pure; unit-tested under Lune).
--
-- MonetizationService calls process() from MarketplaceService.ProcessReceipt:
--   * A PurchaseId already in Purchases.Receipts is a duplicate (Roblox retries receipts
--     until it sees PurchaseGranted): nothing is granted again; reply PurchaseGranted.
--   * An unknown ProductId is not ours: reply NotProcessedYet so Roblox keeps it.
--   * Otherwise the entitlement is recorded together with the receipt. The caller saves the
--     profile and only then replies PurchaseGranted; if the save fails it calls revert()
--     and replies NotProcessedYet, so the purchase is retried and never lost or doubled.
-- Entitlements are paid for, so they are recorded even when the prerequisite is missing
-- (see Logic/Entitlements: the mode stays locked until the prerequisite is owned).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Entitlements = require(Shared.Logic.Entitlements)

export type Receipt = {
	PurchaseId: string,
	ProductId: number,
	PlayerId: number,
}

export type Outcome = {
	Decision: string, -- "Granted" | "Duplicate" | "Unknown"
	Product: Entitlements.Product?,
	NewEntitlement: boolean, -- false when the entitlement was already owned
	MissingPrerequisite: boolean,
}

local ReceiptProcessor = {}

-- How many processed receipt ids a profile keeps (oldest dropped first).
ReceiptProcessor.MAX_RECEIPTS = 200

local function prune(receipts: { [string]: number })
	local ids = {}
	for id in receipts do
		table.insert(ids, id)
	end
	if #ids <= ReceiptProcessor.MAX_RECEIPTS then
		return
	end
	table.sort(ids, function(a, b)
		if receipts[a] ~= receipts[b] then
			return receipts[a] < receipts[b]
		end
		return a < b
	end)
	for i = 1, #ids - ReceiptProcessor.MAX_RECEIPTS do
		receipts[ids[i]] = nil
	end
end

function ReceiptProcessor.process(data: Types.PlayerData, receipt: Receipt, now: number): Outcome
	local purchases = data.Purchases
	if purchases.Receipts[receipt.PurchaseId] ~= nil then
		return { Decision = "Duplicate", Product = nil, NewEntitlement = false, MissingPrerequisite = false }
	end
	local product = Entitlements.productById(receipt.ProductId)
	if not product then
		return { Decision = "Unknown", Product = nil, NewEntitlement = false, MissingPrerequisite = false }
	end
	local newEntitlement = purchases.Entitlements[product.Key] ~= true
	purchases.Entitlements[product.Key] = true
	purchases.Receipts[receipt.PurchaseId] = now
	prune(purchases.Receipts)
	local missing = product.Requires ~= nil and purchases.Entitlements[product.Requires] ~= true
	return { Decision = "Granted", Product = product, NewEntitlement = newEntitlement, MissingPrerequisite = missing }
end

-- Undoes a Granted outcome whose save failed, so the retried receipt grants it again.
function ReceiptProcessor.revert(data: Types.PlayerData, receipt: Receipt, outcome: Outcome)
	if outcome.Decision ~= "Granted" then
		return
	end
	data.Purchases.Receipts[receipt.PurchaseId] = nil
	if outcome.NewEntitlement and outcome.Product then
		data.Purchases.Entitlements[outcome.Product.Key] = nil
	end
end

-- Checks MarketplaceService:GetProductInfo(id, Enum.InfoType.Product) output against the
-- config. Returns (ok, message). `info` is nil when the lookup failed.
function ReceiptProcessor.checkProductInfo(product: Entitlements.Product, info: any): (boolean, string)
	if type(info) ~= "table" then
		return false, `{product.DisplayName} ({product.ProductId}) is not a Developer Product of this experience`
	end
	local price = info.PriceInRobux
	local name = tostring(info.Name)
	if type(price) ~= "number" then
		return false, `{product.DisplayName} ({product.ProductId}) "{name}" has no Robux price (not for sale?)`
	end
	if product.ExpectedPriceRobux and price ~= product.ExpectedPriceRobux then
		return true,
			`{product.DisplayName} ({product.ProductId}) "{name}" costs {price} Robux, design says {product.ExpectedPriceRobux}`
	end
	return true, `{product.DisplayName} ({product.ProductId}) "{name}": Developer Product, {price} Robux`
end

return ReceiptProcessor
