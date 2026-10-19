-- Multi Opening (3x / 6x game passes): ownership from Roblox, purchase completion, the 6x
-- prerequisite and API failures; the manual synchronised reveal order; the card back.
local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local ProfileSchema = Loader.require("src/shared/Data/ProfileSchema")
local CardArt = Loader.require("src/shared/Logic/CardArt")
local Entitlements = Loader.require("src/shared/Logic/Entitlements")
local Inventory = Loader.require("src/shared/Logic/Inventory")
local PackShop = Loader.require("src/shared/Logic/PackShop")
local RevealPlan = Loader.require("src/shared/Logic/RevealPlan")
local PackOpenRequests = Loader.require("src/server/Lib/PackOpenRequests")
local GamePassOwnership = Loader.require("src/server/Lib/GamePassOwnership")

local USER = 42
local ID3 = 2038324873
local ID6 = 2039938706

local function ctx(seed: number?)
	local state = seed or 7
	return {
		ownerId = USER,
		now = 1700000000,
		roll = function()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end,
	}
end

local function player(packs: number, entitlements: { string }?)
	local data = ProfileSchema.defaults()
	if packs > 0 then
		PackShop.grant(data, "pack1", packs)
	end
	for _, key in entitlements or {} do
		data.Purchases.Entitlements[key] = true
	end
	return data
end

describe("Shared card back asset", function()
	it("maps card.back to the uploaded image id in rbxassetid format", function()
		expect(Config.Assets.Images["card.back"].AssetId).toBe(129297477524368)
		expect(CardArt.back()).toBe("rbxassetid://129297477524368")
		expect(CardArt.image("card.back")).toBe("rbxassetid://129297477524368")
	end)

	it("keeps every card front unchanged and separate from the back", function()
		expect(CardArt.image("card.pack1.sandy")).toBe("rbxassetid://140074029273080")
		expect(CardArt.image("pack.pack1.front")).toBe("rbxassetid://104453844983670")
		local ids = CardArt.allContentIds()
		expect(table.find(ids, "rbxassetid://129297477524368") ~= nil).toBe(true)
		-- 6 card fronts + pack front + card back + 5 HUD images.
		expect(#ids).toBe(13)
	end)

	it("uses a thumbnail only when one is uploaded, else the full image", function()
		local asset = Config.Assets.Images["card.pack1.boba"]
		expect(CardArt.thumbnail("card.pack1.boba")).toBe("rbxassetid://84086042476135")
		asset.ThumbAssetId = 555
		expect(CardArt.thumbnail("card.pack1.boba")).toBe("rbxassetid://555")
		asset.ThumbAssetId = 0
		expect(CardArt.thumbnail("card.pack1.boba")).toBe("rbxassetid://84086042476135")
		asset.ThumbAssetId = nil
	end)
end)

describe("Entitlements: unlock prerequisites", function()
	it("configures the two game passes as 3x then 6x, with only 3x's price in config", function()
		expect(Entitlements.product("MultiOpen3").GamePassId).toBe(ID3)
		expect(Entitlements.product("MultiOpen6").GamePassId).toBe(ID6)
		expect(Entitlements.product("MultiOpen6").Requires).toBe("MultiOpen3")
		expect(Entitlements.product("MultiOpen3").ExpectedPriceRobux).toBe(100)
		expect(Entitlements.product("MultiOpen6").ExpectedPriceRobux).toBeNil()
		expect(Entitlements.productByPassId(ID6).Key).toBe("MultiOpen6")
		expect(Entitlements.productByPassId(1)).toBeNil()
		expect((Config.Monetization.MultiOpen.MultiOpen3 :: any).ProductId).toBeNil()
	end)

	it("allows 1 pack always, 3x with MultiOpen3, and 6x only with both", function()
		local none = player(0)
		expect(Entitlements.canUseMode(none, 1)).toBe(true)
		expect(Entitlements.canUseMode(none, 3)).toBe(false)
		expect(Entitlements.canUseMode(none, 6)).toBe(false)
		local three = player(0, { "MultiOpen3" })
		expect(Entitlements.canUseMode(three, 3)).toBe(true)
		expect(Entitlements.canUseMode(three, 6)).toBe(false)
		-- 6x bought without 3x (outside the game's UI): recorded but unusable.
		local sixOnly = player(0, { "MultiOpen6" })
		expect(Entitlements.canUseMode(sixOnly, 6)).toBe(false)
		local both = player(0, { "MultiOpen3", "MultiOpen6" })
		expect(Entitlements.canUseMode(both, 6)).toBe(true)
		expect(Entitlements.canUseMode(both, 2)).toBe(false)
		expect(table.concat(Entitlements.modes(both), ",")).toBe("1,3,6")
	end)

	it("only offers 6x once 3x is owned, and never re-offers an owned unlock", function()
		local none = player(0)
		expect((Entitlements.canPurchase(none, "MultiOpen3"))).toBe(true)
		local ok6, reason6 = Entitlements.canPurchase(none, "MultiOpen6")
		expect(ok6).toBe(false)
		expect(reason6).toBe("Unlock 3x Multi Opening first")
		local three = player(0, { "MultiOpen3" })
		expect((Entitlements.canPurchase(three, "MultiOpen3"))).toBe(false)
		expect((Entitlements.canPurchase(three, "MultiOpen6"))).toBe(true)
		expect((Entitlements.canPurchase(three, "nope"))).toBe(false)
	end)

	it("adds Purchases.Entitlements to existing profiles", function()
		local old = ProfileSchema.defaults() :: any
		old.Purchases = { Receipts = { a = 1 } }
		ProfileSchema.reconcile(old)
		expect(type(old.Purchases.Entitlements)).toBe("table")
		expect(old.Purchases.Receipts.a).toBe(1)
	end)
end)

-- Fake UserOwnsGamePassAsync: `owned` maps pass id -> boolean; `fails` makes the first N
-- calls error like an API outage. Returns the query and a call counter.
local function fakeQuery(owned: { [number]: boolean }, fails: number?)
	local calls = 0
	local query = function(_userId: number, passId: number)
		calls += 1
		if fails and calls <= fails then
			return false, "HTTP 503 (Service Unavailable)"
		end
		return true, owned[passId] == true
	end
	return query, function()
		return calls
	end
end

describe("GamePassOwnership: ownership from Roblox", function()
	it("records passes Roblox confirms and removes passes it confirms are not owned", function()
		local data = player(0, { "MultiOpen6" })
		local query = fakeQuery({ [ID3] = true, [ID6] = false })
		local results, changed, verified = GamePassOwnership.refreshAll(data, USER, query, 3)
		expect(results.MultiOpen3).toBe("owned")
		expect(results.MultiOpen6).toBe("notOwned")
		expect(changed).toBe(true)
		expect(verified).toBe(true)
		expect(data.Purchases.Entitlements.MultiOpen3).toBe(true)
		expect(data.Purchases.Entitlements.MultiOpen6).toBeNil()
		expect(Entitlements.canUseMode(data, 3)).toBe(true)
	end)

	it("never concludes 'not owned' when the API fails: cached ownership is kept", function()
		local data = player(0, { "MultiOpen3", "MultiOpen6" })
		local query = fakeQuery({}, 1000)
		local results, changed, verified = GamePassOwnership.refreshAll(data, USER, query, 3)
		expect(results.MultiOpen3).toBe("failed")
		expect(changed).toBe(false)
		expect(verified).toBe(false)
		expect(Entitlements.canUseMode(data, 6)).toBe(true)
	end)

	it("never grants a pass from a failed query", function()
		local data = player(0)
		local query = fakeQuery({ [ID3] = true }, 1000)
		GamePassOwnership.refreshAll(data, USER, query, 2)
		expect(data.Purchases.Entitlements.MultiOpen3).toBeNil()
	end)

	it("retries a failing query and pauses between attempts", function()
		local query, calls = fakeQuery({ [ID3] = true }, 2)
		local pauses = {}
		local result = GamePassOwnership.check(query, USER, ID3, 3, function(attempt)
			table.insert(pauses, attempt)
		end)
		expect(result).toBe("owned")
		expect(calls()).toBe(3)
		expect(table.concat(pauses, ",")).toBe("1,2")
		local failing = fakeQuery({}, 1000)
		expect(GamePassOwnership.check(failing, USER, ID3, 2)).toBe("failed")
	end)

	it("treats a malformed answer as a failure, not as 'not owned'", function()
		local query = function()
			return true, nil
		end
		expect(GamePassOwnership.check(query, USER, ID3, 1)).toBe("failed")
	end)
end)

describe("GamePassOwnership: purchase completion and the 6x prerequisite", function()
	it("activates 3x after a purchase Roblox confirms", function()
		local data = player(0)
		local product = Entitlements.product("MultiOpen3")
		local result = GamePassOwnership.check(fakeQuery({ [ID3] = true }), USER, ID3, 3)
		GamePassOwnership.apply(data, product.Key, result)
		local kind, message = GamePassOwnership.purchaseMessage(data, product, result)
		expect(kind).toBe("success")
		expect(string.find(message, "activated", 1, true) ~= nil).toBe(true)
		expect(Entitlements.canUseMode(data, 3)).toBe(true)
	end)

	it("does not activate anything while Roblox hasn't confirmed the purchase", function()
		local data = player(0)
		local product = Entitlements.product("MultiOpen3")
		local result = GamePassOwnership.check(fakeQuery({}, 1000), USER, ID3, 2)
		expect(GamePassOwnership.apply(data, product.Key, result)).toBe(false)
		local kind, message = GamePassOwnership.purchaseMessage(data, product, result)
		expect(kind).toBe("info")
		expect(string.find(message, "activated", 1, true)).toBeNil()
		expect(Entitlements.canUseMode(data, 3)).toBe(false)
	end)

	it("keeps a 6x pass bought without 3x but does not report it as activated", function()
		local data = player(0)
		local product = Entitlements.product("MultiOpen6")
		local result = GamePassOwnership.check(fakeQuery({ [ID6] = true }), USER, ID6, 1)
		GamePassOwnership.apply(data, product.Key, result)
		expect(data.Purchases.Entitlements.MultiOpen6).toBe(true)
		expect(Entitlements.canUseMode(data, 6)).toBe(false)
		local kind, message = GamePassOwnership.purchaseMessage(data, product, result)
		expect(kind).toBe("warning")
		expect(string.find(message, "activates once you also own 3x Multi Opening", 1, true) ~= nil).toBe(true)
		expect(string.find(message, "activated!", 1, true)).toBeNil()
		-- Buying 3x afterwards activates 6x without buying 6x again.
		GamePassOwnership.apply(data, "MultiOpen3", "owned")
		expect(Entitlements.canUseMode(data, 6)).toBe(true)
		local okKind = GamePassOwnership.purchaseMessage(data, product, "owned")
		expect(okKind).toBe("success")
	end)

	it("does not offer 6x before 3x and never re-offers an owned pass", function()
		local data = player(0)
		expect((Entitlements.canPurchase(data, "MultiOpen6"))).toBe(false)
		GamePassOwnership.apply(data, "MultiOpen3", "owned")
		expect((Entitlements.canPurchase(data, "MultiOpen3"))).toBe(false)
		expect((Entitlements.canPurchase(data, "MultiOpen6"))).toBe(true)
	end)
end)

describe("GamePassOwnership: game pass info", function()
	it("accepts 3x when it is for sale at 100 Robux", function()
		local three = Entitlements.product("MultiOpen3")
		local available, price, message =
			GamePassOwnership.checkInfo(three, { Name = "3x", PriceInRobux = 100, IsForSale = true })
		expect(available).toBe(true)
		expect(price).toBe(100)
		expect(string.find(message, "for sale, 100 Robux", 1, true) ~= nil).toBe(true)
	end)

	it("flags a 3x price that differs from the design", function()
		local three = Entitlements.product("MultiOpen3")
		local available, price, message =
			GamePassOwnership.checkInfo(three, { Name = "3x", PriceInRobux = 80, IsForSale = true })
		expect(available).toBe(true)
		expect(price).toBe(80)
		expect(string.find(message, "design says 100", 1, true) ~= nil).toBe(true)
	end)

	it("reads the 6x price from Roblox instead of assuming one", function()
		local six = Entitlements.product("MultiOpen6")
		local available, price = GamePassOwnership.checkInfo(six, { Name = "6x", PriceInRobux = 249, IsForSale = true })
		expect(available).toBe(true)
		expect(price).toBe(249)
	end)

	it("marks passes that are off sale or unreadable as unavailable", function()
		local three = Entitlements.product("MultiOpen3")
		expect((GamePassOwnership.checkInfo(three, { Name = "3x", PriceInRobux = 100, IsForSale = false }))).toBe(false)
		expect((GamePassOwnership.checkInfo(three, nil))).toBe(false)
	end)
end)

describe("Multi opening: pack consumption and reward counts", function()
	it("opens 1 pack into 5 cards without any unlock", function()
		local ledger = PackOpenRequests.new()
		local data = player(6)
		local response = ledger:open(data, USER, "pack1", "a", ctx(), 1)
		expect(response.ok).toBe(true)
		expect(#response.cards).toBe(5)
		expect(PackShop.owned(data, "pack1")).toBe(5)
	end)

	it("rejects 3x without the unlock and changes nothing", function()
		local ledger = PackOpenRequests.new()
		local data = player(6)
		local response, opening = ledger:open(data, USER, "pack1", "a", ctx(), 3)
		expect(response.ok).toBe(false)
		expect(opening).toBeNil()
		expect(PackShop.owned(data, "pack1")).toBe(6)
		expect(Inventory.count(data)).toBe(0)
	end)

	it("opens 3 packs into 15 cards with the 3x unlock", function()
		local ledger = PackOpenRequests.new()
		local data = player(4, { "MultiOpen3" })
		local response = ledger:open(data, USER, "pack1", "a", ctx(), 3)
		expect(response.ok).toBe(true)
		expect(response.packs).toBe(3)
		expect(response.cardsPerPack).toBe(5)
		expect(#response.cards).toBe(15)
		expect(PackShop.owned(data, "pack1")).toBe(1)
		expect(Inventory.count(data)).toBe(15)
		expect(data.Stats.PacksOpened).toBe(3)
		for index, card in response.cards do
			expect(card.Pack).toBe((index - 1) // 5 + 1)
			expect(card.Slot).toBe((index - 1) % 5 + 1)
		end
	end)

	it("opens 6 packs into 30 cards only with both unlocks", function()
		local ledger = PackOpenRequests.new()
		local threeOnly = player(6, { "MultiOpen3" })
		expect(ledger:open(threeOnly, USER, "pack1", "a", ctx(), 6).ok).toBe(false)
		expect(PackShop.owned(threeOnly, "pack1")).toBe(6)
		local both = player(6, { "MultiOpen3", "MultiOpen6" })
		local response = ledger:open(both, 7, "pack1", "b", ctx(), 6)
		expect(response.ok).toBe(true)
		expect(#response.cards).toBe(30)
		expect(both.Packs.pack1).toBeNil()
		expect(Inventory.count(both)).toBe(30)
	end)

	it("requires enough owned packs before starting", function()
		local ledger = PackOpenRequests.new()
		local data = player(2, { "MultiOpen3" })
		local response = ledger:open(data, USER, "pack1", "a", ctx(), 3)
		expect(response.ok).toBe(false)
		expect(PackShop.owned(data, "pack1")).toBe(2)
		expect(Inventory.count(data)).toBe(0)
	end)

	it("replays a repeated 3x request without consuming more packs", function()
		local ledger = PackOpenRequests.new()
		local data = player(6, { "MultiOpen3" })
		local first = ledger:open(data, USER, "pack1", "same", ctx(1), 3)
		local again, opening = ledger:open(data, USER, "pack1", "same", ctx(2), 3)
		expect(opening).toBeNil()
		expect(again).toBe(first)
		expect(PackShop.owned(data, "pack1")).toBe(3)
		expect(Inventory.count(data)).toBe(15)
	end)
end)

describe("RevealPlan: manual, synchronised reveal", function()
	local function cards(packs: number)
		local list = {}
		for p = 1, packs do
			for k = 1, 5 do
				table.insert(list, `p{p}c{k}`)
			end
		end
		return list
	end

	it("never advances without a click and ignores clicks in the wrong state", function()
		local plan = RevealPlan.new(cards(1), 1, 5)
		expect(plan.phase).toBe("intro")
		expect(RevealPlan.reveal(plan)).toBe(false)
		expect(RevealPlan.start(plan)).toBe(true)
		expect(plan.phase).toBe("hidden")
		expect(RevealPlan.next(plan)).toBe(false) -- NEXT before revealing does nothing
		expect(RevealPlan.reveal(plan)).toBe(true)
		expect(RevealPlan.reveal(plan)).toBe(false) -- double click on reveal
		expect(plan.round).toBe(1)
		expect(RevealPlan.next(plan)).toBe(true)
		expect(plan.phase).toBe("hidden")
		expect(plan.round).toBe(2)
	end)

	it("reveals one card per click for a single pack and ends on the summary", function()
		local plan = RevealPlan.new(cards(1), 1, 5)
		RevealPlan.start(plan)
		local seen = {}
		for round = 1, 5 do
			expect(plan.round).toBe(round)
			RevealPlan.reveal(plan)
			local current = RevealPlan.current(plan)
			expect(#current).toBe(1)
			table.insert(seen, current[1])
			expect(RevealPlan.isLast(plan)).toBe(round == 5)
			RevealPlan.next(plan)
		end
		expect(plan.phase).toBe("summary")
		expect(table.concat(seen, ",")).toBe("p1c1,p1c2,p1c3,p1c4,p1c5")
	end)

	it("reveals card k of all 3 packs together, never finishing one pack first", function()
		local plan = RevealPlan.new(cards(3), 3, 5)
		RevealPlan.start(plan)
		RevealPlan.reveal(plan)
		expect(table.concat(RevealPlan.current(plan), ",")).toBe("p1c1,p2c1,p3c1")
		RevealPlan.next(plan)
		RevealPlan.reveal(plan)
		expect(table.concat(RevealPlan.current(plan), ",")).toBe("p1c2,p2c2,p3c2")
		expect(#plan.rounds).toBe(5)
	end)

	it("reveals 6 cards per click for 6 packs, 5 clicks for all 30", function()
		local plan = RevealPlan.new(cards(6), 6, 5)
		RevealPlan.start(plan)
		local total = 0
		local clicks = 0
		while plan.phase ~= "summary" do
			expect(RevealPlan.reveal(plan)).toBe(true)
			clicks += 1
			local current = RevealPlan.current(plan)
			expect(#current).toBe(6)
			total += #current
			RevealPlan.next(plan)
		end
		expect(clicks).toBe(5)
		expect(total).toBe(30)
	end)

	it("can skip to the summary at any time", function()
		local plan = RevealPlan.new(cards(3), 3, 5)
		RevealPlan.start(plan)
		RevealPlan.finish(plan)
		expect(plan.phase).toBe("summary")
		expect(RevealPlan.reveal(plan)).toBe(false)
	end)
end)
