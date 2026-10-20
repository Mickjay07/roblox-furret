--!strict
-- MarketplaceService.ProcessReceipt for Developer Products (pure; unit-tested under Lune).
--
-- Rules:
--   * Only a receipt from Roblox grants anything; client events never do. A cancelled prompt
--     produces no receipt, so nothing is granted.
--   * Idempotent: each PurchaseId is recorded in Purchases.Receipts; a repeated receipt
--     returns PurchaseGranted without granting again. A receipt already being processed (a
--     concurrent retry) returns NotProcessedYet.
--   * The grant and the receipt record are saved before PurchaseGranted is returned. When the
--     save fails, both are rolled back and NotProcessedYet tells Roblox to retry later.
--   * Unknown product, invalid grant or player not loaded -> NotProcessedYet (retried later,
--     e.g. when the player rejoins); never a silent grant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Products = require(Shared.Logic.Products)

export type Receipt = { PlayerId: number, ProductId: number, PurchaseId: string, [string]: any }
export type Deps = {
	getData: (userId: number) -> Types.PlayerData?,
	save: (userId: number) -> boolean,
	changed: (userId: number, keys: { string }, product: Products.Product) -> (),
	now: () -> number,
}
-- "granted" | "duplicate" | "inFlight" | "unknownProduct" | "invalidProduct" | "notLoaded" | "saveFailed"
export type Outcome = string

local ReceiptProcessor = {}

-- Receipts kept per player; older ones are dropped (Roblox stops retrying long before).
ReceiptProcessor.MaxReceipts = 200

local GRANTED = "PurchaseGranted"
local NOT_YET = "NotProcessedYet"

function ReceiptProcessor.prune(receipts: { [string]: number }, keep: number)
	local ids = {}
	for id in receipts do
		table.insert(ids, id)
	end
	if #ids <= keep then
		return
	end
	table.sort(ids, function(a, b)
		if receipts[a] ~= receipts[b] then
			return receipts[a] > receipts[b]
		end
		return a > b
	end)
	for i = keep + 1, #ids do
		receipts[ids[i]] = nil
	end
end

-- Returns a processor; `process(receipt)` returns (decision name, outcome).
function ReceiptProcessor.new(deps: Deps)
	local inFlight: { [string]: boolean } = {}

	local function process(receipt: Receipt): (string, Outcome)
		local purchaseId = tostring(receipt.PurchaseId)
		local product = Products.byProductId(receipt.ProductId)
		if not product then
			return NOT_YET, "unknownProduct"
		end
		if not Products.validate(product) then
			return NOT_YET, "invalidProduct"
		end
		local data = deps.getData(receipt.PlayerId)
		if not data then
			return NOT_YET, "notLoaded"
		end
		local receipts = data.Purchases.Receipts
		if receipts[purchaseId] then
			return GRANTED, "duplicate"
		end
		if inFlight[purchaseId] then
			return NOT_YET, "inFlight"
		end
		inFlight[purchaseId] = true
		local changed = Products.grant(data, product)
		receipts[purchaseId] = deps.now()
		ReceiptProcessor.prune(receipts, ReceiptProcessor.MaxReceipts)
		local saved = deps.save(receipt.PlayerId)
		if not saved then
			-- Only roll back if the same profile is still loaded (it may have been released).
			if deps.getData(receipt.PlayerId) == data then
				receipts[purchaseId] = nil
				Products.revert(data, product)
			end
			inFlight[purchaseId] = nil
			return NOT_YET, "saveFailed"
		end
		inFlight[purchaseId] = nil
		deps.changed(receipt.PlayerId, changed, product)
		return GRANTED, "granted"
	end

	return { process = process }
end

return ReceiptProcessor
