--!strict
-- Multi Opening game passes, as mirrored from Roblox into Purchases.Entitlements by
-- MonetizationService (server only). Pure rules shared by the server (enforcement) and the
-- client (what to show):
--   * 1 pack per opening is always available.
--   * 3x needs the MultiOpen3 pass.
--   * 6x needs the MultiOpen6 pass AND its prerequisite MultiOpen3. The game only prompts
--     6x once 3x is owned; a player who bought 6x elsewhere (e.g. the website) keeps that
--     ownership recorded, but 6x stays unusable until 3x is owned too.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)

export type Product = {
	Key: string,
	GamePassId: number,
	DisplayName: string,
	Packs: number,
	Requires: string?,
	ExpectedPriceRobux: number?,
}

local Entitlements = {}

local PRODUCTS = Config.Monetization.MultiOpen :: { [string]: Product }

function Entitlements.product(key: string): Product?
	return PRODUCTS[key]
end

function Entitlements.productByPassId(gamePassId: number): Product?
	for _, product in PRODUCTS do
		if product.GamePassId == gamePassId then
			return product
		end
	end
	return nil
end

-- Passes sorted by pack count (3x, then 6x).
function Entitlements.products(): { Product }
	local list = {}
	for _, product in PRODUCTS do
		table.insert(list, product)
	end
	table.sort(list, function(a, b)
		return a.Packs < b.Packs
	end)
	return list
end

function Entitlements.owns(data: Types.PlayerData, key: string): boolean
	return data.Purchases.Entitlements[key] == true
end

-- True when the player owns the pass and, recursively, everything it requires.
local function usable(data: Types.PlayerData, product: Product): boolean
	if not Entitlements.owns(data, product.Key) then
		return false
	end
	if product.Requires then
		local required = PRODUCTS[product.Requires]
		return required ~= nil and usable(data, required)
	end
	return true
end

-- Can this player open `packs` packs in one opening?
function Entitlements.canUseMode(data: Types.PlayerData, packs: number): boolean
	if packs == 1 then
		return true
	end
	for _, product in PRODUCTS do
		if product.Packs == packs then
			return usable(data, product)
		end
	end
	return false
end

-- Opening sizes this player can use, e.g. { 1, 3 }.
function Entitlements.modes(data: Types.PlayerData): { number }
	local modes = { 1 }
	for _, product in Entitlements.products() do
		if usable(data, product) then
			table.insert(modes, product.Packs)
		end
	end
	return modes
end

-- May the game prompt this pass for the player? Returns (ok, reason).
function Entitlements.canPurchase(data: Types.PlayerData, key: string): (boolean, string?)
	local product = PRODUCTS[key]
	if not product or product.GamePassId <= 0 then
		return false, "That item isn't available"
	end
	if Entitlements.owns(data, key) then
		return false, `You already own {product.DisplayName}`
	end
	if product.Requires and not Entitlements.owns(data, product.Requires) then
		local required = PRODUCTS[product.Requires]
		return false, `Unlock {if required then required.DisplayName else product.Requires} first`
	end
	return true, nil
end

return Entitlements
