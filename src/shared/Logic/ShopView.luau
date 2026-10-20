--!strict
-- What the Premium Shop shows (pure; unit-tested under Lune). The client passes in the
-- facts it has - replicated data, the server's game pass check attributes and the
-- published product info - and gets back each card's button text, style and status line.
-- OWNED appears only for a pass the server confirmed with Roblox; while that check is
-- running or failing the card shows a safe CHECKING / retry state instead.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)
local CardRegistry = require(script.Parent.CardRegistry)
local Entitlements = require(script.Parent.Entitlements)
local PackRoller = require(script.Parent.PackRoller)
local Products = require(script.Parent.Products)

export type CardState = {
	Button: string,
	-- Button palette: "Purple" buy, "Green" owned, "Gray" not actionable.
	Style: string,
	-- One short line under the description ("Active", "Requires ...").
	Status: string,
	CanBuy: boolean,
}

-- Server facts about this player's game pass check (player attributes).
export type PassCheck = { Checked: boolean, Verified: boolean }
-- Published GetProductInfo result for one item.
export type Info = { Available: boolean, Price: number? }

local ShopView = {}

local function priceText(info: Info): string
	return if info.Price then `BUY  R$ {info.Price}` else "BUY"
end

function ShopView.passState(data: Types.PlayerData, pass: Entitlements.Product, check: PassCheck, info: Info): CardState
	if pass.GamePassId <= 0 then
		return { Button = "UNAVAILABLE", Style = "Gray", Status = "Not on sale yet", CanBuy = false }
	end
	if not check.Checked then
		return { Button = "CHECKING...", Style = "Gray", Status = "Checking with Roblox", CanBuy = false }
	end
	if not check.Verified then
		-- Roblox didn't answer: never claim OWNED or offer a pass the player may own.
		return {
			Button = "RETRYING...",
			Style = "Gray",
			Status = "Couldn't check ownership - retrying",
			CanBuy = false,
		}
	end
	local required = if pass.Requires then Entitlements.product(pass.Requires) else nil
	local requiredName = if required then required.DisplayName else (pass.Requires or "")
	local hasRequired = pass.Requires == nil or Entitlements.owns(data, pass.Requires)
	if Entitlements.owns(data, pass.Key) then
		if not hasRequired then
			return {
				Button = "LOCKED",
				Style = "Gray",
				Status = `Owned - activates with {requiredName}`,
				CanBuy = false,
			}
		end
		return { Button = "OWNED", Style = "Green", Status = "Active", CanBuy = false }
	end
	if not hasRequired then
		return { Button = "LOCKED", Style = "Gray", Status = `Requires {requiredName} first`, CanBuy = false }
	end
	if not info.Available then
		return { Button = "UNAVAILABLE", Style = "Gray", Status = "Not for sale right now", CanBuy = false }
	end
	return { Button = priceText(info), Style = "Purple", Status = "Permanent - yours forever", CanBuy = true }
end

function ShopView.productState(product: Products.Product, restricted: boolean, info: Info, now: number): CardState
	if Products.isPaidRandom(product) and restricted then
		return {
			Button = "NOT AVAILABLE HERE",
			Style = "Gray",
			Status = "Robux packs aren't sold in your region",
			CanBuy = false,
		}
	end
	if not info.Available or not Products.isOnSale(product, now) then
		return { Button = "UNAVAILABLE", Style = "Gray", Status = "Not for sale right now", CanBuy = false }
	end
	return {
		Button = if info.Price then `R$ {info.Price}` else "BUY",
		Style = "Purple",
		Status = "Goes straight to your bag",
		CanBuy = true,
	}
end

-- Packs one product gives (e.g. 10), for the "10 PACKS" title.
function ShopView.packCount(product: Products.Product): number
	local total = 0
	local packs: { [string]: number } = product.Grants.Packs or {}
	for _, count in packs do
		total += count
	end
	return total
end

-- The pack the Robux pack products currently grant (Config.Monetization.PremiumPackId).
function ShopView.premiumPack(): Types.PackDef?
	return Config.Packs.ById[Config.Monetization.PremiumPackId]
end

-- Cards of a pack for the preview row, commonest first, and the chase card (lowest base
-- odds), shown highlighted on the right. Base odds (no luck) so it's the same for everyone.
function ShopView.preview(pack: Types.PackDef): ({ Types.CardDef }, Types.CardDef?, number?)
	local odds = PackRoller.odds(pack)
	local cards: { Types.CardDef } = {}
	local chase: Types.CardDef? = nil
	local chaseP = math.huge
	for cardId, probability in odds do
		local def = CardRegistry.get(cardId)
		if def then
			table.insert(cards, def)
			if probability < chaseP then
				chase, chaseP = def, probability
			end
		end
	end
	table.sort(cards, function(a, b)
		local ra = Config.Rarities.ById[a.Rarity]
		local rb = Config.Rarities.ById[b.Rarity]
		if ra.Order ~= rb.Order then
			return ra.Order < rb.Order
		end
		return a.CollectionNumber < b.CollectionNumber
	end)
	if chase then
		local index = table.find(cards, chase)
		if index then
			table.remove(cards, index)
		end
	end
	return cards, chase, if chase then PackRoller.oneIn(chaseP) else nil
end

-- Limited-time bundles on sale now, soonest-ending first.
function ShopView.activeLimited(now: number): { Products.Product }
	local list = {}
	for _, product in Products.list("Limited") do
		if Products.isOnSale(product, now) then
			table.insert(list, product)
		end
	end
	table.sort(list, function(a, b)
		return (a.EndsAt or math.huge) < (b.EndsAt or math.huge)
	end)
	return list
end

return ShopView
