--!strict
-- Developer Products (repeatable Robux purchases): lookup, sale windows and what one purchase
-- grants. Pure; used by the server receipt handler and by the shop UI.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)
local CardRegistry = require(script.Parent.CardRegistry)
local Economy = require(script.Parent.Economy)
local PackRoller = require(script.Parent.PackRoller)
local PackShop = require(script.Parent.PackShop)
local Progression = require(script.Parent.Progression)
local Wallet = require(script.Parent.Wallet)

export type Product = {
	Key: string,
	ProductId: number,
	DisplayName: string,
	Description: string?,
	Icon: string?,
	Section: string,
	Order: number?,
	Grants: { Packs: { [string]: number }?, Currency: { [string]: number }? },
	ExpectedPriceRobux: number?,
	StartsAt: number?,
	EndsAt: number?,
}

local Products = {}

local function packsOf(product: Product): { [string]: number }
	return product.Grants.Packs or {}
end

local function currencyOf(product: Product): { [string]: number }
	return product.Grants.Currency or {}
end

local ALL: { [string]: Product } = table.clone(Config.Monetization.DeveloperProducts :: { [string]: any })
for key, product in Config.Monetization.LimitedBundles :: { [string]: any } do
	ALL[key] = product
end

function Products.get(key: string): Product?
	return ALL[key]
end

-- Products with ProductId 0 are not created yet and never match a receipt.
function Products.byProductId(productId: number): Product?
	if productId <= 0 then
		return nil
	end
	for _, product in ALL do
		if product.ProductId == productId then
			return product
		end
	end
	return nil
end

-- Every product of one section ("Packs", "Currency", "Limited"), in shop order.
function Products.list(section: string?): { Product }
	local list = {}
	for _, product in ALL do
		if section == nil or product.Section == section then
			table.insert(list, product)
		end
	end
	table.sort(list, function(a, b)
		if (a.Order or 99) ~= (b.Order or 99) then
			return (a.Order or 99) < (b.Order or 99)
		end
		return a.Key < b.Key
	end)
	return list
end

-- Inside its sale window (always, for products without one) and created on the website.
function Products.isOnSale(product: Product, now: number): boolean
	if product.ProductId <= 0 then
		return false
	end
	if product.StartsAt and now < product.StartsAt then
		return false
	end
	if product.EndsAt and now >= product.EndsAt then
		return false
	end
	return true
end

-- Checks that every grant is valid before anything changes. Returns (ok, reason).
function Products.validate(product: Product): (boolean, string?)
	local grants = product.Grants
	if type(grants) ~= "table" then
		return false, "no grants"
	end
	local any = false
	for packId, count in packsOf(product) do
		if not Config.Packs.ById[packId] then
			return false, `unknown pack {packId}`
		end
		if type(count) ~= "number" or count % 1 ~= 0 or count <= 0 then
			return false, `invalid pack count for {packId}`
		end
		any = true
	end
	for currency, amount in currencyOf(product) do
		if type(currency) ~= "string" or type(amount) ~= "number" or amount <= 0 or amount ~= amount then
			return false, `invalid currency grant {currency}`
		end
		any = true
	end
	if not any then
		return false, "no grants"
	end
	return true, nil
end

-- Gives one purchase's contents. Packs go into the pack inventory (data.Packs), exactly
-- where cash-bought packs go. Returns the top-level data keys that changed.
function Products.grant(data: Types.PlayerData, product: Product): { string }
	local changed = {}
	local grants = product.Grants
	if grants.Packs and next(grants.Packs) then
		for packId, count in grants.Packs do
			PackShop.grant(data, packId, count)
		end
		table.insert(changed, "Packs")
	end
	if grants.Currency and next(grants.Currency) then
		for currency, amount in grants.Currency do
			Wallet.add(data, currency, amount)
		end
		table.insert(changed, "Currency")
	end
	return changed
end

-- Undoes Products.grant (used when the receipt could not be saved, so Roblox retries it).
function Products.revert(data: Types.PlayerData, product: Product)
	for packId, count in packsOf(product) do
		local remaining = (data.Packs[packId] or 0) - count
		if remaining > 0 then
			data.Packs[packId] = remaining
		else
			data.Packs[packId] = nil
		end
	end
	for currency, amount in currencyOf(product) do
		data.Currency[currency] = math.max(0, (data.Currency[currency] or 0) - amount)
		if currency == "Cash" then
			data.Stats.CashEarned = math.max(0, (data.Stats.CashEarned or 0) - amount)
		end
	end
end

-- Player-facing summary, e.g. "3 packs added to your bag".
function Products.describe(product: Product): string
	local parts = {}
	local packs = 0
	for _, count in packsOf(product) do
		packs += count
	end
	if packs > 0 then
		table.insert(parts, `{packs} pack{if packs == 1 then "" else "s"} added to your bag`)
	end
	for currency, amount in currencyOf(product) do
		table.insert(parts, `+{amount} {currency}`)
	end
	return table.concat(parts, ", ")
end

-- True when the product contains packs, i.e. random cards bought with Robux ("paid random
-- items"): they must show odds before purchase and must not be sold where
-- PolicyService.ArePaidRandomItemsRestricted is true.
function Products.isPaidRandom(product: Product): boolean
	return next(packsOf(product)) ~= nil
end

-- Per-rarity odds of the packs in a product for this player (luck and unlocks applied, the
-- same rules the server rolls with), e.g. "COMMON 62.5% · RARE 30% · EPIC 7.5%".
function Products.oddsText(data: Types.PlayerData, product: Product): string
	local parts = {}
	for packId in packsOf(product) do
		local pack = Config.Packs.ById[packId]
		if pack then
			local odds = PackRoller.odds(pack, {
				luck = Economy.luck(data),
				isUnlocked = function(def: Types.CardDef): boolean
					return Progression.meets(data, def.Unlock)
				end,
			})
			local byRarity: { [string]: number } = {}
			for cardId, probability in odds do
				local def = CardRegistry.get(cardId)
				if def then
					byRarity[def.Rarity] = (byRarity[def.Rarity] or 0) + probability
				end
			end
			for _, rarity in Config.Rarities.List do
				local p = byRarity[rarity.Id]
				if p and p > 0 then
					local percent = math.floor(p * 1000 + 0.5) / 10
					table.insert(parts, `{rarity.DisplayName} {percent}%`)
				end
			end
		end
	end
	return table.concat(parts, " · ")
end

-- Checks GetProductInfo(id, Enum.InfoType.Product) output against the config.
-- Returns (available for sale, price or nil, message for the log).
function Products.checkInfo(product: Product, info: any): (boolean, number?, string)
	local label = `{product.DisplayName} (developer product {product.ProductId})`
	if type(info) ~= "table" then
		return false, nil, `{label}: product info could not be read`
	end
	local name = tostring(info.Name)
	local price = if type(info.PriceInRobux) == "number" then info.PriceInRobux else nil
	if price == nil or info.IsForSale == false then
		return false, price, `{label} "{name}" is NOT for sale`
	end
	if product.ExpectedPriceRobux and price ~= product.ExpectedPriceRobux then
		return true, price, `{label} "{name}" costs {price} Robux, but the design says {product.ExpectedPriceRobux}`
	end
	return true, price, `{label} "{name}": for sale, {price} Robux`
end

return Products
