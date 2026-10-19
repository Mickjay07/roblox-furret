-- A7 pack opening, server side: one request opens exactly one pack of exactly five cards,
-- and repeated clicks (the same request id) never consume a second pack or grant twice.
local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local ProfileSchema = Loader.require("src/shared/Data/ProfileSchema")
local Economy = Loader.require("src/shared/Logic/Economy")
local Inventory = Loader.require("src/shared/Logic/Inventory")
local PackShop = Loader.require("src/shared/Logic/PackShop")
local PackOpenRequests = Loader.require("src/server/Lib/PackOpenRequests")

local USER = 77

local function ctx(seed: number?)
	-- Deterministic linear congruential generator (Lune has no Roblox Random).
	local state = seed or 1
	return {
		ownerId = USER,
		now = 1700000000,
		roll = function()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end,
	}
end

local function player(packs: number)
	local data = ProfileSchema.defaults()
	if packs > 0 then
		PackShop.grant(data, "pack1", packs)
	end
	return data
end

describe("PackOpenRequests: one pack, five cards", function()
	it("consumes exactly one owned pack and adds exactly five cards to the inventory", function()
		local ledger = PackOpenRequests.new()
		local data = player(3)
		local response, opening = ledger:open(data, USER, "pack1", "req-1", ctx())
		expect(response.ok).toBe(true)
		expect(opening ~= nil).toBe(true)
		expect(PackShop.owned(data, "pack1")).toBe(2)
		expect(#response.cards).toBe(5)
		expect(Inventory.count(data)).toBe(5)
		expect(data.Stats.PacksOpened).toBe(1)
		for _, card in response.cards do
			local instance = data.Cards[card.InstanceId]
			expect(instance ~= nil).toBe(true)
			expect(instance.CardId).toBe(card.CardId)
			expect(instance.Variant).toBe(card.Variant)
			-- Server-computed income from the central formula (Shiny = +2%).
			expect(card.Income).toBe(Economy.cardIncome(instance))
		end
	end)

	it("opens the last owned pack and removes the pack entry", function()
		local ledger = PackOpenRequests.new()
		local data = player(1)
		expect(ledger:open(data, USER, "pack1", "req-1", ctx()).ok).toBe(true)
		expect(data.Packs.pack1).toBeNil()
	end)

	it("every configured pack contains exactly five cards", function()
		for _, pack in Config.Packs.List do
			expect(pack.CardsPerOpen).toBe(5)
		end
	end)
end)

describe("PackOpenRequests: repeated clicks", function()
	it("replays the same result for a repeated request id without opening another pack", function()
		local ledger = PackOpenRequests.new()
		local data = player(3)
		local first = ledger:open(data, USER, "pack1", "req-1", ctx(1))
		local again, opening = ledger:open(data, USER, "pack1", "req-1", ctx(2))
		expect(opening).toBeNil()
		expect(again).toBe(first)
		expect(PackShop.owned(data, "pack1")).toBe(2)
		expect(Inventory.count(data)).toBe(5)
		expect(data.Stats.PacksOpened).toBe(1)
	end)

	it("opens a new pack for a new request id", function()
		local ledger = PackOpenRequests.new()
		local data = player(3)
		ledger:open(data, USER, "pack1", "req-1", ctx(1))
		local second, opening = ledger:open(data, USER, "pack1", "req-2", ctx(2))
		expect(second.ok).toBe(true)
		expect(opening ~= nil).toBe(true)
		expect(PackShop.owned(data, "pack1")).toBe(1)
		expect(Inventory.count(data)).toBe(10)
	end)

	it("keeps request ids separate per player", function()
		local ledger = PackOpenRequests.new()
		local a, b = player(1), player(1)
		expect(ledger:open(a, 1, "pack1", "same", ctx()).ok).toBe(true)
		local _, opening = ledger:open(b, 2, "pack1", "same", ctx())
		expect(opening ~= nil).toBe(true)
		expect(PackShop.owned(b, "pack1")).toBe(0)
	end)
end)

describe("PackOpenRequests: rejected requests change nothing", function()
	it("rejects opening without packs and does not remember the failure", function()
		local ledger = PackOpenRequests.new()
		local data = player(0)
		local response, opening = ledger:open(data, USER, "pack1", "req-1", ctx())
		expect(response.ok).toBe(false)
		expect(opening).toBeNil()
		expect(Inventory.count(data)).toBe(0)
		expect(ledger:remembered(USER)).toBe(0)
		-- After getting a pack, the same id now opens it.
		PackShop.grant(data, "pack1", 1)
		expect(ledger:open(data, USER, "pack1", "req-1", ctx()).ok).toBe(true)
		expect(Inventory.count(data)).toBe(5)
	end)

	it("rejects opening with a full backpack and keeps the pack", function()
		local ledger = PackOpenRequests.new()
		local data = player(1)
		local capacity = Economy.backpackCapacity(data)
		for _ = 1, capacity - 4 do
			Inventory.add(data, USER, "pack1_sandy", "Normal", 0)
		end
		local before = Inventory.count(data)
		local response = ledger:open(data, USER, "pack1", "req-1", ctx())
		expect(response.ok).toBe(false)
		expect(PackShop.owned(data, "pack1")).toBe(1)
		expect(Inventory.count(data)).toBe(before)
	end)

	it("rejects unknown packs", function()
		local ledger = PackOpenRequests.new()
		local data = player(1)
		expect(ledger:open(data, USER, "nope", "req-1", ctx()).ok).toBe(false)
		expect(PackShop.owned(data, "pack1")).toBe(1)
	end)
end)

describe("PackOpenRequests: memory", function()
	it("remembers only the last `limit` requests and forgets a player who leaves", function()
		local ledger = PackOpenRequests.new(2)
		local data = player(4)
		ledger:open(data, USER, "pack1", "a", ctx())
		ledger:open(data, USER, "pack1", "b", ctx())
		ledger:open(data, USER, "pack1", "c", ctx())
		expect(ledger:remembered(USER)).toBe(2)
		-- "c" is still remembered: no new pack.
		local _, replay = ledger:open(data, USER, "pack1", "c", ctx())
		expect(replay).toBeNil()
		expect(PackShop.owned(data, "pack1")).toBe(1)
		ledger:forget(USER)
		expect(ledger:remembered(USER)).toBe(0)
	end)
end)

local RevealStyle = Loader.require("src/shared/Logic/RevealStyle")
local Format = Loader.require("src/shared/Util/Format")

describe("RevealStyle: rarer cards get bigger reveals", function()
	it("raises the tier, particles and hold time with rarity", function()
		local previous = nil
		for _, rarity in Config.Rarities.List do
			local style = RevealStyle.forRarity(rarity.Id)
			if previous then
				expect(style.Tier >= previous.Tier).toBe(true)
				expect(style.Burst >= previous.Burst).toBe(true)
				expect(style.Hold >= previous.Hold).toBe(true)
			end
			previous = style
		end
		local uncommon = RevealStyle.forRarity("Uncommon")
		local rare = RevealStyle.forRarity("Rare")
		local epic = RevealStyle.forRarity("Epic")
		local legendary = RevealStyle.forRarity("Legendary")
		local mythic = RevealStyle.forRarity("Mythic")
		expect(uncommon.Burst).toBe(0)
		expect(rare.Burst > 0).toBe(true)
		expect(rare.Rays).toBe(false)
		expect(epic.Rays).toBe(true)
		expect(epic.Flash).toBe(false)
		expect(legendary.Flash).toBe(true)
		expect(legendary.Banner).toBe("LEGENDARY!")
		expect(mythic.Banner).toBe("MYTHIC!")
		expect(uncommon.Banner).toBeNil()
	end)

	it("shakes the pack according to the rarest card inside", function()
		expect(RevealStyle.packTier({ "Uncommon", "Uncommon", "Rare" })).toBe(2)
		expect(RevealStyle.packTier({ "Uncommon", "Mythic" })).toBe(4)
		expect(RevealStyle.packTier({})).toBe(1)
	end)

	it("labels Shiny cards with their +2% bonus and Normal cards with nothing", function()
		local base = 70
		local shiny = base * Config.Variants.ById.Shiny.IncomeMultiplier
		expect(RevealStyle.variantLabel("Shiny", shiny, base)).toBe("SHINY +2%")
		expect(RevealStyle.variantLabel("Normal", base, base)).toBeNil()
		expect(RevealStyle.variantLabel("Gold", base * 3, base)).toBe("GOLD +200%")
	end)
end)

describe("Format.rate", function()
	it("shows one decimal for fractional incomes below 1,000", function()
		expect(Format.rate(70)).toBe("70")
		expect(Format.rate(70 * 1.02)).toBe("71.4")
		expect(Format.rate(118 * 1.02)).toBe("120.3")
		expect(Format.rate(1500 * 1.02)).toBe(Format.short(1530))
	end)
end)
