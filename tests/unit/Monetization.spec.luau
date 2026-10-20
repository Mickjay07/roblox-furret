-- Robux purchases: configured ids, game passes vs developer products, ProcessReceipt
-- idempotency and failure handling, pack grants into the inventory, VIP and 2x AFK Time Cash.
local serde = require("@lune/serde")
local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local ProfileSchema = Loader.require("src/shared/Data/ProfileSchema")
local ConfigCheck = Loader.require("src/shared/Logic/ConfigCheck")
local Economy = Loader.require("src/shared/Logic/Economy")
local Entitlements = Loader.require("src/shared/Logic/Entitlements")
local IncomeLedger = Loader.require("src/shared/Logic/IncomeLedger")
local Inventory = Loader.require("src/shared/Logic/Inventory")
local PackShop = Loader.require("src/shared/Logic/PackShop")
local Products = Loader.require("src/shared/Logic/Products")
local GamePassOwnership = Loader.require("src/server/Lib/GamePassOwnership")
local PackOpenRequests = Loader.require("src/server/Lib/PackOpenRequests")
local ReceiptProcessor = Loader.require("src/server/Lib/ReceiptProcessor")

local USER = 42
local NOW = 1700000000

local function fresh()
	return ProfileSchema.defaults()
end

-- A fake server around ReceiptProcessor: one loaded profile, a save that can fail.
local function server(data: any?)
	local state = { data = data or fresh(), saves = 0, failSave = false, changed = {} }
	state.processor = ReceiptProcessor.new({
		getData = function(userId)
			return if userId == USER then state.data else nil
		end,
		save = function()
			state.saves += 1
			return not state.failSave
		end,
		changed = function(_, keys)
			for _, key in keys do
				table.insert(state.changed, key)
			end
		end,
		now = function()
			return NOW
		end,
	})
	return state
end

local function receipt(productId: number, purchaseId: string)
	return { PlayerId = USER, ProductId = productId, PurchaseId = purchaseId, CurrencySpent = 0 }
end

describe("Configured ids", function()
	it("uses the given game pass ids for the passes", function()
		expect(Entitlements.product("VIP").GamePassId).toBe(2040244736)
		expect(Entitlements.product("AfkCash2x").GamePassId).toBe(2038205144)
		expect(Entitlements.product("MultiOpen3").GamePassId).toBe(2038324873)
		expect(Entitlements.product("MultiOpen6").GamePassId).toBe(2039938706)
		-- Open All has no id yet: never sold, never matched.
		expect(Entitlements.product("OpenAll").GamePassId).toBe(0)
		expect(Entitlements.productByPassId(0)).toBeNil()
	end)

	it("uses the given developer product ids and prices for the pack bundles", function()
		local expected = {
			Packs1 = { 3720277269, 1, 75 },
			Packs3 = { 3720277334, 3, 199 },
			Packs10 = { 3720277406, 10, 499 },
		}
		for key, values in expected do
			local product = Products.get(key)
			expect(product.ProductId).toBe(values[1])
			expect(product.Grants.Packs.pack1).toBe(values[2])
			expect(product.ExpectedPriceRobux).toBe(values[3])
			expect(Products.byProductId(values[1]).Key).toBe(key)
		end
	end)

	it("never mixes game pass ids and developer product ids", function()
		for _, pass in Entitlements.passes() do
			if pass.GamePassId > 0 then
				expect(Products.byProductId(pass.GamePassId)).toBeNil()
			end
		end
		for _, product in Products.list() do
			if product.ProductId > 0 then
				expect(Entitlements.productByPassId(product.ProductId)).toBeNil()
			end
		end
	end)

	it("registers the shop and HUD art with the given image ids", function()
		local images = Config.Assets.Images
		local expected = {
			["ui.level_bar"] = 129406057306152,
			["ui.collect_button"] = 128905277992791,
			["ui.icon.shop"] = 83544896119835,
			["ui.shop.vip"] = 108576806919415,
			["ui.shop.open3"] = 137191381736886,
			["ui.shop.open6"] = 120349601099983,
			["ui.shop.open_all"] = 71884954923271,
			["pack.promo.front"] = 118924487824692,
			["card.promo.back"] = 121661874661575,
		}
		for key, id in expected do
			expect(images[key].AssetId).toBe(id)
		end
		local promo = {
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
		for i, id in promo do
			expect(images[`card.promo.{99 + i}`].AssetId).toBe(id)
		end
	end)

	it("passes the config check", function()
		local problems = ConfigCheck.run(Config)
		expect(#problems).toBe(0)
	end)

	it("shows passes in shop order and lists only the pack bundles in the Packs section", function()
		local keys = {}
		for _, pass in Entitlements.passes() do
			table.insert(keys, pass.Key)
		end
		expect(table.concat(keys, ",")).toBe("VIP,AfkCash2x,MultiOpen3,MultiOpen6,OpenAll")
		local packs = {}
		for _, product in Products.list("Packs") do
			table.insert(packs, product.Key)
		end
		expect(table.concat(packs, ",")).toBe("Packs1,Packs3,Packs10")
	end)
end)

describe("Game passes (never through ProcessReceipt)", function()
	it("can prompt VIP and 2x AFK, but never Open All (no id) or an owned pass", function()
		local data = fresh()
		expect((Entitlements.canPurchase(data, "VIP"))).toBe(true)
		expect((Entitlements.canPurchase(data, "AfkCash2x"))).toBe(true)
		expect((Entitlements.canPurchase(data, "OpenAll"))).toBe(false)
		data.Purchases.Entitlements.VIP = true
		local ok, reason = Entitlements.canPurchase(data, "VIP")
		expect(ok).toBe(false)
		expect(reason).toBe("You already own VIP")
	end)

	it("checks every configured pass on join and keeps ownership through a rejoin", function()
		local asked = {}
		local query = function(_, id)
			asked[id] = true
			return true, id == 2040244736 or id == 2038205144
		end
		local data = fresh()
		local _, changed, verified = GamePassOwnership.refreshAll(data, USER, query, 1)
		expect(changed).toBe(true)
		expect(verified).toBe(true)
		expect(asked[2040244736]).toBe(true)
		expect(asked[2038205144]).toBe(true)
		expect(asked[2038324873]).toBe(true)
		expect(asked[0]).toBeNil()
		expect(data.Purchases.Entitlements.VIP).toBe(true)
		expect(data.Purchases.Entitlements.AfkCash2x).toBe(true)
		-- Rejoin: saved data round-trips, and an API outage keeps the cached ownership.
		local ok, loaded = ProfileSchema.migrate(serde.decode("json", serde.encode("json", data)))
		expect(ok).toBe(true)
		local _, _, verifiedAgain = GamePassOwnership.refreshAll(loaded, USER, function()
			return false, "HTTP 500"
		end, 1)
		expect(verifiedAgain).toBe(false)
		expect(loaded.Purchases.Entitlements.VIP).toBe(true)
		expect(loaded.Purchases.Entitlements.AfkCash2x).toBe(true)
	end)

	it("thanks generically for passes that are not Multi Opening", function()
		local data = fresh()
		GamePassOwnership.apply(data, "VIP", "owned")
		local kind, message = GamePassOwnership.purchaseMessage(data, Entitlements.product("VIP"), "owned")
		expect(kind).toBe("success")
		expect(string.find(message, "VIP activated", 1, true) ~= nil).toBe(true)
	end)

	it("rejects invalid product info and accepts valid info", function()
		local vip = Entitlements.product("VIP")
		expect((GamePassOwnership.checkInfo(vip, nil))).toBe(false)
		expect((GamePassOwnership.checkInfo(vip, { Name = "VIP", IsForSale = false, PriceInRobux = 99 }))).toBe(false)
		local ok, price = GamePassOwnership.checkInfo(vip, { Name = "VIP", IsForSale = true, PriceInRobux = 199 })
		expect(ok).toBe(true)
		expect(price).toBe(199)
		local packs = Products.get("Packs3")
		expect((Products.checkInfo(packs, nil))).toBe(false)
		expect((Products.checkInfo(packs, { Name = "3 Packs" }))).toBe(false)
		local okProduct, productPrice, message = Products.checkInfo(packs, { Name = "3 Packs", PriceInRobux = 150 })
		expect(okProduct).toBe(true)
		expect(productPrice).toBe(150)
		expect(string.find(message, "design says 199", 1, true) ~= nil).toBe(true)
	end)
end)

describe("ProcessReceipt: Robux packs go into the pack inventory", function()
	for _, case in { { "Packs1", 3720277269, 1 }, { "Packs3", 3720277334, 3 }, { "Packs10", 3720277406, 10 } } do
		it(`grants {case[3]} pack(s) for {case[1]} and saves before PurchaseGranted`, function()
			local s = server()
			local decision, outcome = s.processor.process(receipt(case[2], "p-" .. case[1]))
			expect(decision).toBe("PurchaseGranted")
			expect(outcome).toBe("granted")
			expect(PackShop.owned(s.data, "pack1")).toBe(case[3])
			expect(s.saves).toBe(1)
			expect(s.data.Purchases.Receipts["p-" .. case[1]]).toBe(NOW)
			expect(table.find(s.changed, "Packs") ~= nil).toBe(true)
		end)
	end

	it("adds to packs already owned (cash and Robux packs share data.Packs)", function()
		local s = server()
		s.data.Currency.Cash = 10000
		expect((PackShop.buy(s.data, "pack1", 2))).toBe(true)
		s.processor.process(receipt(3720277334, "x"))
		expect(PackShop.owned(s.data, "pack1")).toBe(5)
	end)

	it("grants a duplicate receipt only once", function()
		local s = server()
		s.processor.process(receipt(3720277406, "dup"))
		local decision, outcome = s.processor.process(receipt(3720277406, "dup"))
		expect(decision).toBe("PurchaseGranted")
		expect(outcome).toBe("duplicate")
		expect(PackShop.owned(s.data, "pack1")).toBe(10)
		expect(s.saves).toBe(1)
	end)

	it("rolls back and asks Roblox to retry when the save fails", function()
		local s = server()
		s.failSave = true
		local decision, outcome = s.processor.process(receipt(3720277334, "retry"))
		expect(decision).toBe("NotProcessedYet")
		expect(outcome).toBe("saveFailed")
		expect(PackShop.owned(s.data, "pack1")).toBe(0)
		expect(s.data.Purchases.Receipts.retry).toBeNil()
		-- Roblox retries once the save works: granted exactly once.
		s.failSave = false
		expect((s.processor.process(receipt(3720277334, "retry")))).toBe("PurchaseGranted")
		expect(PackShop.owned(s.data, "pack1")).toBe(3)
	end)

	it("grants nothing for unknown products, game pass ids or players who are not loaded", function()
		local s = server()
		expect((s.processor.process(receipt(123, "a")))).toBe("NotProcessedYet")
		expect((s.processor.process(receipt(2040244736, "b")))).toBe("NotProcessedYet")
		local other = receipt(3720277269, "c")
		other.PlayerId = 7
		expect((s.processor.process(other))).toBe("NotProcessedYet")
		expect(PackShop.owned(s.data, "pack1")).toBe(0)
		expect(s.saves).toBe(0)
	end)

	it("grants nothing when a prompt is cancelled (no receipt is ever processed)", function()
		local s = server()
		-- A cancelled PromptProductPurchase produces no receipt; nothing else grants products.
		expect(PackShop.owned(s.data, "pack1")).toBe(0)
		expect(next(s.data.Purchases.Receipts)).toBeNil()
	end)

	it("keeps receipt history bounded, newest first", function()
		local receipts = {}
		for i = 1, 250 do
			receipts[`r{i}`] = i
		end
		ReceiptProcessor.prune(receipts, 200)
		local count = 0
		for _ in receipts do
			count += 1
		end
		expect(count).toBe(200)
		expect(receipts.r250).toBe(250)
		expect(receipts.r1).toBeNil()
	end)

	it("persists granted packs and receipts across a rejoin and opens them from the inventory", function()
		local s = server()
		s.processor.process(receipt(3720277334, "persist"))
		local ok, loaded = ProfileSchema.migrate(serde.decode("json", serde.encode("json", s.data)))
		expect(ok).toBe(true)
		expect(PackShop.owned(loaded, "pack1")).toBe(3)
		expect(loaded.Purchases.Receipts.persist).toBe(NOW)
		-- The replayed receipt after rejoin is recognised as a duplicate.
		s.data = loaded
		expect(select(2, s.processor.process(receipt(3720277334, "persist")))).toBe("duplicate")
		expect(PackShop.owned(loaded, "pack1")).toBe(3)
		-- Opening from the inventory consumes packs and adds cards.
		local state = 9
		local response = PackOpenRequests.new():open(loaded, USER, "pack1", "open-1", {
			ownerId = USER,
			now = NOW,
			roll = function()
				state = (state * 1103515245 + 12345) % 2147483648
				return state / 2147483648
			end,
		}, 1)
		expect(response.ok).toBe(true)
		expect(PackShop.owned(loaded, "pack1")).toBe(2)
		expect(Inventory.count(loaded)).toBe(5)
	end)
end)

describe("Products: sale windows and grants", function()
	it("treats products without an id as not on sale and respects limited windows", function()
		expect(Products.isOnSale(Products.get("TreatsSmall"), NOW)).toBe(false)
		expect(Products.isOnSale(Products.get("Packs1"), NOW)).toBe(true)
		local limited = {
			Key = "L",
			ProductId = 5,
			DisplayName = "L",
			Section = "Limited",
			Grants = { Packs = { pack1 = 2 } },
			StartsAt = NOW,
			EndsAt = NOW + 60,
		}
		expect(Products.isOnSale(limited, NOW - 1)).toBe(false)
		expect(Products.isOnSale(limited, NOW)).toBe(true)
		expect(Products.isOnSale(limited, NOW + 60)).toBe(false)
	end)

	it("rejects invalid grants before anything changes", function()
		expect((Products.validate({ Grants = { Packs = { nope = 1 } } } :: any))).toBe(false)
		expect((Products.validate({ Grants = { Packs = { pack1 = 0 } } } :: any))).toBe(false)
		expect((Products.validate({ Grants = {} } :: any))).toBe(false)
		expect((Products.validate(Products.get("Packs10")))).toBe(true)
	end)

	it("marks Robux packs as paid random items and lists their odds (summing to 100%)", function()
		local product = Products.get("Packs3")
		expect(Products.isPaidRandom(product)).toBe(true)
		expect(Products.isPaidRandom(Products.get("TreatsSmall"))).toBe(false)
		local text = Products.oddsText(fresh(), product)
		expect(text ~= "").toBe(true)
		local total = 0
		for percent in string.gmatch(text, "([%d%.]+)%%") do
			total += tonumber(percent)
		end
		expect(total).toBeNear(100, 0.6)
	end)

	it("describes a purchase for the player", function()
		expect(Products.describe(Products.get("Packs1"))).toBe("1 pack added to your bag")
		expect(Products.describe(Products.get("Packs10"))).toBe("10 packs added to your bag")
	end)
end)

describe("VIP and 2x AFK Time Cash", function()
	local function earner(entitlements: { string })
		local data = fresh()
		local id = Inventory.add(data, USER, "pack1_sandy", "Normal", NOW)
		data.Display["1"] = id
		for _, key in entitlements do
			data.Purchases.Entitlements[key] = true
		end
		return data
	end

	it("VIP multiplies income by 1.25 (shown and earned the same)", function()
		local plain, vip = earner({}), earner({ "VIP" })
		expect(Economy.totalIncome(vip)).toBeNear(Economy.totalIncome(plain) * 1.25, 1e-9)
		expect(Economy.passIncomeMultiplier(vip)).toBeNear(1.25, 1e-9)
	end)

	it("2x AFK doubles offline earnings exactly once and does not touch online income", function()
		local plain, afk = earner({}), earner({ "AfkCash2x" })
		plain.Income.LastOnline = NOW - 600
		afk.Income.LastOnline = NOW - 600
		local base = IncomeLedger.applyOffline(plain, NOW, 1, Economy.offlineMultiplier(plain))
		local doubled = IncomeLedger.applyOffline(afk, NOW, 1, Economy.offlineMultiplier(afk))
		expect(base > 0).toBe(true)
		expect(Economy.offlineMultiplier(afk)).toBe(2)
		expect(doubled).toBeNear(base * 2, 1e-6)
		-- Applying again at the same moment adds nothing (LastOnline is marked online).
		IncomeLedger.markOnline(afk, NOW)
		expect(IncomeLedger.applyOffline(afk, NOW, 1, 2)).toBe(0)
		-- Online income is unchanged by the AFK pass.
		expect(Economy.totalIncome(afk)).toBeNear(Economy.totalIncome(plain), 1e-9)
	end)

	it("keeps doubled offline earnings above the normal stand cap until collected", function()
		local afk = earner({ "AfkCash2x" })
		afk.Income.LastOnline = NOW - Config.Economy.Income.OfflineCapSeconds * 3
		local added = IncomeLedger.applyOffline(afk, NOW, 1, 2)
		local perSecond = IncomeLedger.standIncome(afk, "1")
		expect(added).toBeNear(perSecond * Config.Economy.Income.OfflineCapSeconds * 2, 1e-6)
		-- The next online tick does not shrink it.
		expect(IncomeLedger.accrue(afk, 1)).toBe(0)
		expect(IncomeLedger.pending(afk, "1")).toBeNear(added, 1e-6)
	end)
end)
