-- Open All game pass (server opening of the whole pack inventory), Premium Shop card states,
-- the Promo Ferret pack definition and responsive HUD placement.
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local ProfileSchema = Loader.require("src/shared/Data/ProfileSchema")
local CardArt = Loader.require("src/shared/Logic/CardArt")
local CardRegistry = Loader.require("src/shared/Logic/CardRegistry")
local Entitlements = Loader.require("src/shared/Logic/Entitlements")
local Inventory = Loader.require("src/shared/Logic/Inventory")
local PackShop = Loader.require("src/shared/Logic/PackShop")
local Products = Loader.require("src/shared/Logic/Products")
local ShopView = Loader.require("src/shared/Logic/ShopView")
local UiLayout = Loader.require("src/shared/Logic/UiLayout")
local GamePassOwnership = Loader.require("src/server/Lib/GamePassOwnership")
local PackOpenRequests = Loader.require("src/server/Lib/PackOpenRequests")

local USER = 42
local OPEN_ALL = 2041988567
local CAP = Config.Game.Limits.MaxOpenAll

local function ctx(seed: number?)
	local state = seed or 11
	return {
		ownerId = USER,
		now = 1700000000,
		roll = function()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end,
	}
end

local function player(packs: { [string]: number }, entitlements: { string }?)
	local data = ProfileSchema.defaults()
	for packId, count in packs do
		PackShop.grant(data, packId, count)
	end
	for _, key in entitlements or {} do
		data.Purchases.Entitlements[key] = true
	end
	return data
end

local function totalPacks(data): number
	local total = 0
	for _, count in data.Packs do
		total += count
	end
	return total
end

describe("Open All game pass", function()
	it("uses game pass 2041988567 and is detected from the verified ownership query", function()
		expect(Entitlements.product("OpenAll").GamePassId).toBe(OPEN_ALL)
		local data = player({})
		local results = GamePassOwnership.refreshAll(data, USER, function(_, id)
			return true, id == OPEN_ALL
		end, 1)
		expect(results.OpenAll).toBe("owned")
		expect(Entitlements.canOpenAll(data)).toBe(true)
	end)

	it("a cancelled or unconfirmed purchase does not unlock it", function()
		local data = player({})
		-- Cancel: PromptGamePassPurchaseFinished(wasPurchased = false) never queries or writes.
		-- Not confirmed by Roblox: the query says not owned, nothing is recorded.
		GamePassOwnership.apply(data, "OpenAll", "notOwned")
		GamePassOwnership.apply(data, "OpenAll", "failed")
		expect(data.Purchases.Entitlements.OpenAll).toBeNil()
		expect(Entitlements.canOpenAll(data)).toBe(false)
	end)

	it("is refused without the pass and changes nothing", function()
		local data = player({ pack1 = 4 })
		local response, opening = PackOpenRequests.new():openAll(data, USER, "r1", ctx(), CAP)
		expect(response.ok).toBe(false)
		expect(response.error).toBe("Unlock Open All first")
		expect(opening).toBeNil()
		expect(PackShop.owned(data, "pack1")).toBe(4)
	end)

	it("opens every pack in the inventory, across pack types", function()
		local data = player({ pack1 = 12, burrow_pack = 3 }, { "OpenAll" })
		local response, opening = PackOpenRequests.new():openAll(data, USER, "r1", ctx(), CAP)
		expect(response.ok).toBe(true)
		expect(response.packs).toBe(15)
		expect(#response.cards).toBe(75)
		expect(response.opened.pack1).toBe(12)
		expect(response.opened.burrow_pack).toBe(3)
		expect(response.leftOver).toBe(0)
		expect(totalPacks(data)).toBe(0)
		expect(Inventory.count(data)).toBe(75)
		expect(#opening.NewInstanceIds).toBe(75)
		-- Pack numbers run 1..15 across both pack types; every card was rolled for real.
		expect(response.cards[75].Pack).toBe(15)
		for _, card in response.cards do
			expect(data.Cards[card.InstanceId].CardId).toBe(card.CardId)
		end
	end)

	it("respects the cap and the free backpack space, leaving the rest in the bag", function()
		local data = player({ pack1 = CAP + 5 }, { "OpenAll" })
		local response = PackOpenRequests.new():openAll(data, USER, "r1", ctx(), CAP)
		expect(response.packs).toBe(CAP)
		expect(response.leftOver).toBe(5)
		expect(PackShop.owned(data, "pack1")).toBe(5)

		local tight = player({ pack1 = 6 }, { "OpenAll" })
		local capacity = Inventory.freeSpace(tight)
		for i = 1, capacity - 12 do
			Inventory.add(tight, USER, "pack1_sandy", "Normal", i)
		end
		local limited = PackOpenRequests.new():openAll(tight, USER, "r2", ctx(), CAP)
		expect(limited.ok).toBe(true)
		expect(limited.packs).toBe(2)
		expect(PackShop.owned(tight, "pack1")).toBe(4)
	end)

	it("says clearly when there are no packs or no space", function()
		local empty = player({}, { "OpenAll" })
		local none = PackOpenRequests.new():openAll(empty, USER, "r1", ctx(), CAP)
		expect(none.ok).toBe(false)
		expect(string.find(none.error, "no packs", 1, true) ~= nil).toBe(true)

		local full = player({ pack1 = 2 }, { "OpenAll" })
		for i = 1, Inventory.freeSpace(full) do
			Inventory.add(full, USER, "pack1_sandy", "Normal", i)
		end
		local noSpace = PackOpenRequests.new():openAll(full, USER, "r2", ctx(), CAP)
		expect(noSpace.ok).toBe(false)
		expect(string.find(noSpace.error, "space", 1, true) ~= nil).toBe(true)
		expect(PackShop.owned(full, "pack1")).toBe(2)
	end)

	it("a repeated request id replays the result instead of opening again", function()
		local ledger = PackOpenRequests.new()
		local data = player({ pack1 = 3 }, { "OpenAll" })
		local first = ledger:openAll(data, USER, "same", ctx(), CAP)
		PackShop.grant(data, "pack1", 2)
		local again, opening = ledger:openAll(data, USER, "same", ctx(), CAP)
		expect(again).toBe(first)
		expect(opening).toBeNil()
		expect(PackShop.owned(data, "pack1")).toBe(2)
		expect(Inventory.count(data)).toBe(15)
	end)
end)

describe("Premium Shop card states", function()
	local checked = { Checked = true, Verified = true }
	local function onSale(_key: string)
		return { Available = true, Price = 299 }
	end
	local function offSale(_key: string)
		return { Available = false }
	end

	it("never shows OWNED before the server has checked with Roblox", function()
		local data = player({}, { "VIP" })
		local vip = Entitlements.product("VIP")
		local checking = ShopView.passState(data, vip, { Checked = false, Verified = false }, onSale)
		expect(checking.Kind).toBe("checking")
		expect(checking.CanBuy).toBe(false)
		local failing = ShopView.passState(data, vip, { Checked = true, Verified = false }, onSale)
		expect(failing.Kind).toBe("retry")
		expect(failing.Button).toBe("RETRY")
		expect(failing.CanBuy).toBe(false)
		local owned = ShopView.passState(data, vip, checked, onSale)
		expect(owned.Kind).toBe("owned")
		expect(owned.Status).toBe("Active")
		-- Not owned in the server-confirmed data: never OWNED, whatever the client did.
		expect(ShopView.passState(player({}), vip, checked, onSale).Kind).toBe("buy")
	end)

	it("offers a pass with its Robux price, or explains why not", function()
		local data = player({})
		local openAll = ShopView.passState(data, Entitlements.product("OpenAll"), checked, onSale)
		expect(openAll.Kind).toBe("buy")
		expect(openAll.Button).toBe("R$ 299")
		expect(openAll.Target).toBe("OpenAll")
		expect(openAll.CanBuy).toBe(true)
		local off = ShopView.passState(data, Entitlements.product("VIP"), checked, offSale)
		expect(off.Kind).toBe("unavailable")
		expect(off.CanBuy).toBe(false)
	end)

	it("explains the Open 6 prerequisite, offers Open 3, and keeps real ownership visible", function()
		local six = Entitlements.product("MultiOpen6")
		local none = ShopView.passState(player({}), six, checked, onSale)
		expect(none.Kind).toBe("unlock")
		expect(none.Status).toBe("Needs Open 3 at Once")
		expect(none.Target).toBe("MultiOpen3")
		expect(none.CanBuy).toBe(false)
		local sixOnly = ShopView.passState(player({}, { "MultiOpen6" }), six, checked, onSale)
		expect(sixOnly.Kind).toBe("unlock")
		expect(sixOnly.Status).toBe("Owned - activates with Open 3 at Once")
		-- Open 3 not on sale: the prerequisite is explained but nothing can be prompted.
		local blocked = ShopView.passState(player({}), six, checked, offSale)
		expect(blocked.Kind).toBe("unavailable")
		expect(blocked.Target).toBeNil()
		local both = ShopView.passState(player({}, { "MultiOpen3", "MultiOpen6" }), six, checked, onSale)
		expect(both.Kind).toBe("owned")
	end)

	it("uses fewer grid columns on narrow screens instead of smaller text", function()
		expect(UiLayout.gridColumns(1040, 300, 12, 3)).toBe(3)
		expect(UiLayout.gridColumns(700, 300, 12, 3)).toBe(2)
		expect(UiLayout.gridColumns(400, 300, 12, 3)).toBe(1)
		expect(UiLayout.gridColumns(100, 300, 12, 3)).toBe(1)
		expect(UiLayout.gridColumns(5000, 300, 12, 3)).toBe(3)
	end)

	it("maps the three Robux pack cards to the right products, quantities and prices", function()
		local expected = { { "Packs1", 3720277269, 1 }, { "Packs3", 3720277334, 3 }, { "Packs10", 3720277406, 10 } }
		local list = Products.list("Packs")
		expect(#list).toBe(3)
		for i, row in expected do
			expect(list[i].Key).toBe(row[1])
			expect(list[i].ProductId).toBe(row[2])
			expect(ShopView.packCount(list[i])).toBe(row[3])
			local state = ShopView.productState(list[i], false, { Available = true, Price = 499 }, 0)
			expect(state.Button).toBe("R$ 499")
			expect(state.CanBuy).toBe(true)
		end
		local blocked = ShopView.productState(list[1], true, { Available = true, Price = 75 }, 0)
		expect(blocked.CanBuy).toBe(false)
		expect(ShopView.productState(list[1], false, { Available = false }, 0).CanBuy).toBe(false)
	end)

	it("features the pack the products grant, with the chase card outside the row", function()
		local pack = ShopView.premiumPack()
		expect(pack.Id).toBe(Config.Monetization.PremiumPackId)
		local cards, chase, oneIn = ShopView.preview(pack)
		expect(chase ~= nil).toBe(true)
		expect(table.find(cards, chase)).toBeNil()
		expect(oneIn > 1).toBe(true)
		expect(#cards + 1).toBe(#CardRegistry.inCollection(pack.Collections[1]))
	end)

	it("shows no limited-time offers unless one is configured and running", function()
		expect(#ShopView.activeLimited(1700000000)).toBe(0)
	end)
end)

describe("Promo Ferret pack (#100-#110)", function()
	local promoIds = {
		70878561185473,
		71690452255214,
		123457627384202,
		124984047881099,
		113879366953871,
		132722881927097,
		83078173945779,
		97300435213696,
		118788058418159,
		73450075794193,
		74079006860743,
	}

	it("defines cards #100-#110 with their uploaded artwork, flagged as placeholders", function()
		local cards = CardRegistry.inCollection("Promo")
		expect(#cards).toBe(11)
		for i, id in promoIds do
			local def = CardRegistry.get(`promo_{99 + i}`)
			expect(def.CollectionNumber).toBe(99 + i)
			expect(CardArt.forCard(def)).toBe(`rbxassetid://{id}`)
			expect(def.Placeholder).toBe(true)
		end
		-- Every tier from Common to Secret is represented.
		local tiers = {}
		for _, def in cards do
			tiers[def.Rarity] = true
		end
		for _, rarity in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" } do
			expect(tiers[rarity]).toBe(true)
		end
	end)

	it("uses the promo wrapper and promo card back, and only rolls promo cards", function()
		local pack = Config.Packs.ById.promo_ferrets
		expect(CardArt.forPack(pack)).toBe("rbxassetid://118924487824692")
		expect(CardArt.backFor(pack)).toBe("rbxassetid://121661874661575")
		expect(CardArt.backFor(Config.Packs.ById.pack1)).toBe(CardArt.back())
		local data = player({ promo_ferrets = 10 })
		local response = PackOpenRequests.new():open(data, USER, "promo_ferrets", "p", ctx(), 1)
		expect(response.ok).toBe(true)
		for _, card in response.cards do
			expect(CardRegistry.get(card.CardId).Collection).toBe("Promo")
		end
	end)

	it("is not sold for Cash and does not change Pack 1's contents", function()
		local data = player({})
		data.Currency.Cash = 1e12
		local ok, message = PackShop.buy(data, "promo_ferrets", 1)
		expect(ok).toBe(false)
		expect(message).toBe("That pack isn't sold for Cash")
		expect(table.concat(Config.Packs.ById.pack1.Collections, ",")).toBe("Pack1")
		expect(Config.Collections.ById.Promo.Hidden).toBe(true)
	end)

	it("Robux products grant the configured premium pack (Pack 1 until the promo data is confirmed)", function()
		expect(Config.Monetization.PremiumPackId).toBe("pack1")
		for _, product in Products.list("Packs") do
			for packId in product.Grants.Packs do
				expect(packId).toBe(Config.Monetization.PremiumPackId)
			end
		end
	end)

	it("granted promo packs persist across a rejoin and open into promo cards", function()
		local data = player({})
		Products.grant(data, {
			Key = "Test",
			ProductId = 1,
			DisplayName = "Test",
			Section = "Packs",
			Grants = { Packs = { promo_ferrets = 3 } },
		})
		local ok, loaded = ProfileSchema.migrate(serde.decode("json", serde.encode("json", data)))
		expect(ok).toBe(true)
		expect(PackShop.owned(loaded, "promo_ferrets")).toBe(3)
		loaded.Purchases.Entitlements.MultiOpen3 = true
		local response = PackOpenRequests.new():open(loaded, USER, "promo_ferrets", "x", ctx(), 3)
		expect(#response.cards).toBe(15)
		expect(PackShop.owned(loaded, "promo_ferrets")).toBe(0)
	end)
end)

describe("HUD placement adapts to the screen", function()
	local V = roblox.Vector2

	it("centres the stats and rail on desktop", function()
		local p = UiLayout.hudPlacement(V.new(1920, 1080), false, 1.25, 320, 570, 64)
		expect(p.StatsAnchorY).toBe(0.5)
		expect(p.RailAnchorY).toBe(0.5)
		expect(p.RailScale).toBe(1.25)
	end)

	it("shrinks a rail that would be taller than the screen", function()
		local p = UiLayout.hudPlacement(V.new(1280, 600), false, 0.79, 320, 1000, 64)
		expect(570 * p.RailScale <= 600 * 0.86 + 1e-6).toBe(true)
		expect(1000 * p.RailScale <= 600 * 0.86 + 1e-6).toBe(true)
	end)

	it("keeps touch layouts above the thumbstick and jump button", function()
		for _, size in { V.new(844, 390), V.new(390, 844), V.new(1024, 768) } do
			local p = UiLayout.hudPlacement(size, true, 0.5, 320, 570, 64)
			expect(p.RailAnchorY).toBe(0)
			expect(p.RailY + 570 * p.RailScale <= size.Y * 0.62 + 1e-6).toBe(true)
			expect(p.StatsY + 320 * p.StatsScale <= size.Y * 0.62 + 1e-6).toBe(true)
		end
		-- Portrait: below the top buttons.
		local portrait = UiLayout.hudPlacement(V.new(390, 844), true, 0.5, 320, 570, 64)
		expect(portrait.StatsY >= 8 + 64 * 0.5).toBe(true)
	end)
end)
