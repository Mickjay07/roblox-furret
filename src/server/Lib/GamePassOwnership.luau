--!strict
-- Multi Opening game pass ownership (pure; unit-tested under Lune with fake queries).
--
-- Roblox is the source of truth. `Query` wraps MarketplaceService:UserOwnsGamePassAsync in
-- pcall and returns (ok, ownedOrError). Results:
--   "owned"    - Roblox confirmed ownership  -> Purchases.Entitlements[key] = true
--   "notOwned" - Roblox confirmed no pass     -> entry removed
--   "failed"   - every attempt errored        -> entry left exactly as it was, so an API
--                                                outage never takes away a pass and never
--                                                grants one
-- Ownership is only ever written from a query result, never from a client event.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Entitlements = require(Shared.Logic.Entitlements)

export type Query = (userId: number, gamePassId: number) -> (boolean, any)
export type Result = string -- "owned" | "notOwned" | "failed"

local GamePassOwnership = {}

-- Asks Roblox up to `attempts` times, calling `pause(attempt)` between failed attempts.
function GamePassOwnership.check(
	query: Query,
	userId: number,
	gamePassId: number,
	attempts: number?,
	pause: ((number) -> ())?
): Result
	local tries = math.max(1, attempts or 3)
	for attempt = 1, tries do
		local ok, owned = query(userId, gamePassId)
		if ok and type(owned) == "boolean" then
			return if owned then "owned" else "notOwned"
		end
		if attempt < tries and pause then
			pause(attempt)
		end
	end
	return "failed"
end

-- Mirrors one result into the profile. Returns true when the data changed.
function GamePassOwnership.apply(data: Types.PlayerData, key: string, result: Result): boolean
	local entitlements = data.Purchases.Entitlements
	if result == "owned" and entitlements[key] ~= true then
		entitlements[key] = true
		return true
	elseif result == "notOwned" and entitlements[key] ~= nil then
		entitlements[key] = nil
		return true
	end
	return false
end

-- Checks every Multi Opening pass. Returns (results by key, data changed, all verified).
function GamePassOwnership.refreshAll(
	data: Types.PlayerData,
	userId: number,
	query: Query,
	attempts: number?,
	pause: ((number) -> ())?
): ({ [string]: Result }, boolean, boolean)
	local results: { [string]: Result } = {}
	local changed, verified = false, true
	for _, product in Entitlements.products() do
		if product.GamePassId > 0 then
			local result = GamePassOwnership.check(query, userId, product.GamePassId, attempts, pause)
			results[product.Key] = result
			if GamePassOwnership.apply(data, product.Key, result) then
				changed = true
			end
			if result == "failed" then
				verified = false
			end
		end
	end
	return results, changed, verified
end

-- What to tell the player after PromptGamePassPurchaseFinished reported a purchase and
-- ownership was re-checked with Roblox. Returns (notification kind, message).
function GamePassOwnership.purchaseMessage(
	data: Types.PlayerData,
	product: Entitlements.Product,
	result: Result
): (string, string)
	if result ~= "owned" then
		return "info",
			`Thanks! Roblox hasn't confirmed your {product.DisplayName} pass yet - it activates as soon as it does (or when you rejoin).`
	end
	if product.Requires and not Entitlements.owns(data, product.Requires) then
		local required = Entitlements.product(product.Requires)
		local name = if required then required.DisplayName else product.Requires
		return "warning",
			`{product.DisplayName} pass owned! It activates once you also own {name} - you keep the pass, no need to buy it again.`
	end
	return "success", `{product.DisplayName} activated! You can now open {product.Packs} packs at once.`
end

-- Checks GetProductInfo(id, Enum.InfoType.GamePass) output against the config.
-- Returns (available for sale, price or nil, message for the log).
function GamePassOwnership.checkInfo(product: Entitlements.Product, info: any): (boolean, number?, string)
	local label = `{product.DisplayName} (game pass {product.GamePassId})`
	if type(info) ~= "table" then
		return false, nil, `{label}: game pass info could not be read`
	end
	local name = tostring(info.Name)
	local price = if type(info.PriceInRobux) == "number" then info.PriceInRobux else nil
	if info.IsForSale ~= true or price == nil then
		return false, price, `{label} "{name}" is NOT for sale`
	end
	if product.ExpectedPriceRobux and price ~= product.ExpectedPriceRobux then
		return true, price, `{label} "{name}" costs {price} Robux, but the design says {product.ExpectedPriceRobux}`
	end
	return true, price, `{label} "{name}": for sale, {price} Robux`
end

return GamePassOwnership
