local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local ProfileSchema = Loader.require("src/shared/Data/ProfileSchema")
local Account = Loader.require("src/shared/Logic/Account")
local PackShop = Loader.require("src/shared/Logic/PackShop")
local Display = Loader.require("src/shared/Logic/Display")
local Market = Loader.require("src/shared/Logic/Market")
local UpgradeShop = Loader.require("src/shared/Logic/UpgradeShop")
local Economy = Loader.require("src/shared/Logic/Economy")
local Inventory = Loader.require("src/shared/Logic/Inventory")
local Progression = Loader.require("src/shared/Logic/Progression")

-- A fresh player after the starter grant, plus two cheap cards for stand tests.
local function newPlayer(cash: number?)
	local data = ProfileSchema.defaults()
	Account.grantStarter(data)
	Inventory.add(data, 7, "burrow_sable_scout", "Normal", 0)
	Inventory.add(data, 7, "burrow_sock_bandit", "Normal", 0)
	if cash then
		data.Currency.Cash = cash
	end
	return data
end

local ctx = { ownerId = 7, now = 50 }
local CardRegistry = Loader.require("src/shared/Logic/CardRegistry")

describe("PackShop.buy", function()
	it("charges the price and puts packs in the pack inventory without opening them", function()
		local pack = Config.Packs.ById.burrow_pack
		local data = newPlayer(pack.Price * 2 + 123)
		local ownedBefore = PackShop.owned(data, "burrow_pack")
		local cardsBefore = Inventory.count(data)
		local ok, cost = PackShop.buy(data, "burrow_pack", 2)
		expect(ok).toBe(true)
		expect(cost).toBe(pack.Price * 2)
		expect(data.Currency.Cash).toBe(123)
		expect(PackShop.owned(data, "burrow_pack")).toBe(ownedBefore + 2)
		expect(Inventory.count(data)).toBe(cardsBefore)
		expect(data.Stats.PacksOpened).toBe(0)
	end)

	it("rejects unknown packs, bad amounts, locked packs and low cash without changes", function()
		local data = newPlayer(10)
		local before = ProfileSchema.deepCopy(data)
		expect((PackShop.buy(data, "fake_pack", 1))).toBe(false)
		expect((PackShop.buy(data, "burrow_pack", 0))).toBe(false)
		expect((PackShop.buy(data, "burrow_pack", 1.5))).toBe(false)
		expect((PackShop.buy(data, "burrow_pack", Config.Game.Limits.MaxPacksPerPurchase + 1))).toBe(false)
		local ok, reason = PackShop.buy(data, "burrow_pack", 1)
		expect(ok).toBe(false)
		expect(reason).toBe("Not enough Cash")
		data.Currency.Cash = 1e12
		local ok2, reason2 = PackShop.buy(data, "midnight_pack", 1)
		expect(ok2).toBe(false)
		expect(string.find(reason2, "level", 1, true) ~= nil).toBe(true)
		data.Currency.Cash = 10
		expect(data).toEqual(before)
	end)
end)

describe("PackShop.open", function()
	it("opens owned packs into CardsPerOpen cards each and spends the packs", function()
		local pack = Config.Packs.ById.burrow_pack
		local data = newPlayer()
		PackShop.grant(data, "burrow_pack", 2)
		local owned = PackShop.owned(data, "burrow_pack")
		local cardsBefore = Inventory.count(data)
		local ok, opening = PackShop.open(data, "burrow_pack", 2, ctx)
		expect(ok).toBe(true)
		expect(pack.CardsPerOpen).toBe(5)
		expect(#opening.Cards).toBe(pack.CardsPerOpen * 2)
		expect(Inventory.count(data)).toBe(cardsBefore + pack.CardsPerOpen * 2)
		expect(PackShop.owned(data, "burrow_pack")).toBe(owned - 2)
		for _, card in opening.Cards do
			expect(data.Cards[card.InstanceId].CardId).toBe(card.CardId)
			expect(card.OneIn >= 1).toBe(true)
		end
		expect(data.Stats.PacksOpened).toBe(2)
		expect(opening.XpGained).toBe(pack.Xp * 2)
	end)

	it("removes the inventory entry when the last pack is opened", function()
		local data = ProfileSchema.defaults()
		PackShop.grant(data, "snack_pack", 1)
		expect((PackShop.open(data, "snack_pack", 1, ctx))).toBe(true)
		expect(data.Packs.snack_pack).toBeNil()
	end)

	it("rejects packs the player does not own, bad amounts and unknown packs without changes", function()
		local data = newPlayer()
		local before = ProfileSchema.deepCopy(data)
		local owned = PackShop.owned(data, "burrow_pack")
		local ok, reason = PackShop.open(data, "burrow_pack", owned + 1, ctx)
		expect(ok).toBe(false)
		expect(reason).toBe("You don't have that many packs")
		expect((PackShop.open(data, "snack_pack", 1, ctx))).toBe(false)
		expect((PackShop.open(data, "burrow_pack", 0, ctx))).toBe(false)
		expect((PackShop.open(data, "nope", 1, ctx))).toBe(false)
		expect(data).toEqual(before)
	end)

	it("refuses to open when the cards would overflow the backpack, keeping the pack", function()
		local data = newPlayer()
		local free = Inventory.freeSpace(data)
		for i = 1, free - 2 do
			data.Cards["x-" .. i] =
				{ CardId = "burrow_sable_scout", Variant = "Normal", Obtained = 0, Favorite = false }
		end
		local owned = PackShop.owned(data, "burrow_pack")
		local ok, reason = PackShop.open(data, "burrow_pack", 1, ctx)
		expect(ok).toBe(false)
		expect(string.find(reason, "backpack", 1, true) ~= nil).toBe(true)
		expect(PackShop.owned(data, "burrow_pack")).toBe(owned)
	end)

	it("levels up and grants treats", function()
		local data = newPlayer()
		PackShop.grant(data, "burrow_pack", 20)
		local levels = 0
		for _ = 1, 20 do
			local ok, opening = PackShop.open(data, "burrow_pack", 1, ctx)
			expect(ok).toBe(true)
			levels += opening.LevelsGained
			for _, id in opening.NewInstanceIds do
				data.Cards[id] = nil
			end
			if levels > 0 then
				break
			end
		end
		expect(levels >= 1).toBe(true)
		expect(data.Progression.Level).toBe(1 + levels)
		expect(data.Currency.Treats).toBe(levels * Config.Economy.Progression.TreatsPerLevel)
	end)

	it("never drops cards the player has not unlocked", function()
		local data = newPlayer()
		data.Progression.Level = Config.Packs.ById.midnight_pack.Unlock.Level
		PackShop.grant(data, "midnight_pack", 30)
		math.randomseed(11)
		for _ = 1, 30 do
			local ok, opening = PackShop.open(data, "midnight_pack", 1, ctx)
			expect(ok).toBe(true)
			for _, card in opening.Cards do
				expect(Progression.meets(data, CardRegistry.get(card.CardId).Unlock)).toBe(true)
			end
			for _, id in opening.NewInstanceIds do
				data.Cards[id] = nil -- keep space free
			end
		end
	end)

	it("grant rejects unknown packs and invalid amounts", function()
		local data = ProfileSchema.defaults()
		expect(function()
			PackShop.grant(data, "nope", 1)
		end).toThrow()
		expect(function()
			PackShop.grant(data, "burrow_pack", 0)
		end).toThrow()
	end)
end)

describe("Display", function()
	it("places into the first empty slot and moves cards between slots", function()
		local data = newPlayer()
		table.clear(data.Display)
		local ids = {}
		for id in data.Cards do
			table.insert(ids, id)
		end
		table.sort(ids)
		expect((Display.place(data, ids[1], 0))).toBe(true)
		expect(data.Display["1"]).toBe(ids[1])
		expect((Display.place(data, ids[2], 0))).toBe(true)
		expect(data.Display["2"]).toBe(ids[2])
		expect((Display.place(data, ids[1], 3))).toBe(true)
		expect(data.Display["1"]).toBeNil()
		expect(data.Display["3"]).toBe(ids[1])
		-- Placing onto an occupied slot replaces its occupant.
		expect((Display.place(data, ids[2], 3))).toBe(true)
		expect(data.Display["3"]).toBe(ids[2])
		expect(Inventory.displaySlotOf(data, ids[1])).toBeNil()
	end)

	it("rejects locked slots, full stands and unowned cards", function()
		local data = newPlayer()
		local id = next(data.Cards)
		expect((Display.place(data, id, Economy.displaySlotCount(data) + 1))).toBe(false)
		expect((Display.place(data, "nope", 1))).toBe(false)
		for slot = 1, Economy.displaySlotCount(data) do
			local filler = Inventory.add(data, 7, "burrow_sable_scout", "Normal", 0)
			data.Display[tostring(slot)] = filler
		end
		local ok, reason = Display.place(data, id, 0)
		expect(ok).toBe(false)
		expect(string.find(reason, "full", 1, true) ~= nil).toBe(true)
	end)

	it("placeBest fills slots with the highest-income cards", function()
		local data = newPlayer()
		local boss = Inventory.add(data, 7, "burrow_burrow_boss", "Normal", 0)
		local gold = Inventory.add(data, 7, "burrow_hammock_napper", "Gold", 0)
		Display.placeBest(data)
		expect(data.Display["1"]).toBe(gold) -- 6 * 3 = 18/s beats 15/s
		expect(data.Display["2"]).toBe(boss)
		expect(Economy.totalIncome(data)).toBe(18 + 15 + 1 + 1)
	end)

	it("sanitize drops dangling and duplicate entries", function()
		local data = newPlayer()
		local id = next(data.Cards)
		data.Display["1"] = id
		data.Display["2"] = id
		data.Display["3"] = "gone"
		data.Display["99"] = id
		expect(Display.sanitize(data)).toBe(true)
		local count = 0
		for _ in data.Display do
			count += 1
		end
		expect(count).toBe(1)
	end)
end)

describe("Market", function()
	it("sells all-or-nothing and protects favourite and displayed cards", function()
		local data = newPlayer(0)
		local a = Inventory.add(data, 7, "burrow_sable_scout", "Normal", 0)
		local b = Inventory.add(data, 7, "burrow_sable_scout", "Gold", 0)
		local c = Inventory.add(data, 7, "burrow_sable_scout", "Normal", 0)
		Market.setFavorite(data, b, true)
		data.Display["1"] = c
		expect((Market.sell(data, { a, b }))).toBe(false)
		expect((Market.sell(data, { a, c }))).toBe(false)
		expect((Market.sell(data, { a, a }))).toBe(false)
		expect((Market.sell(data, { a, "missing" }))).toBe(false)
		expect(Inventory.owns(data, a)).toBe(true)
		expect(data.Currency.Cash).toBe(0)
		local ok, earned = Market.sell(data, { a })
		expect(ok).toBe(true)
		expect(earned).toBe(Config.Cards.List[1].BaseSaleValue)
		expect(data.Currency.Cash).toBe(earned)
		expect(Inventory.owns(data, a)).toBe(false)
		expect(data.Stats.CardsSold).toBe(1)
	end)
end)

describe("UpgradeShop", function()
	it("charges increasing costs and stops at max level", function()
		local data = newPlayer(1e12)
		local def = Config.Upgrades.ById.DisplaySlots
		local slotsBefore = Economy.displaySlotCount(data)
		for level = 1, def.MaxLevel do
			local ok, newLevel = UpgradeShop.buy(data, "DisplaySlots")
			expect(ok).toBe(true)
			expect(newLevel).toBe(level)
		end
		expect(Economy.displaySlotCount(data)).toBe(slotsBefore + def.MaxLevel)
		local ok, reason = UpgradeShop.buy(data, "DisplaySlots")
		expect(ok).toBe(false)
		expect(reason).toBe("Already at max level")
		expect((UpgradeShop.buy(data, "Nope"))).toBe(false)
	end)

	it("does not charge when the player cannot afford it", function()
		local data = newPlayer(1)
		expect((UpgradeShop.buy(data, "IncomeBoost"))).toBe(false)
		expect(data.Currency.Cash).toBe(1)
		expect(data.Upgrades.IncomeBoost).toBeNil()
	end)
end)
