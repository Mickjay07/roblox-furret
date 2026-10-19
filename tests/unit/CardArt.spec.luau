local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local CardArt = Loader.require("src/shared/Logic/CardArt")
local CardRegistry = Loader.require("src/shared/Logic/CardRegistry")

-- Pack 1 mapping as supplied by the artist (card number -> name -> source file).
local PACK1 = {
	{ id = "pack1_sandy", number = 1, name = "Sandy", rarity = "Uncommon", income = 70, file = "sandy 001.png" },
	{ id = "pack1_boba", number = 2, name = "Boba", rarity = "Rare", income = 118, file = "boba 002.png" },
	{ id = "pack1_sky", number = 3, name = "Sky", rarity = "Epic", income = 420, file = "Sky 003.png" },
	{
		id = "pack1_kingston",
		number = 4,
		name = "Kingston",
		rarity = "Legendary",
		income = 750,
		file = "Kingston 004.png",
	},
	{ id = "pack1_aurora", number = 5, name = "Aurora", rarity = "Mythic", income = 1200, file = "Aurora 005.png" },
	{ id = "pack1_frost", number = 6, name = "Frost", rarity = "Mythic", income = 1500, file = "Frost 006.png" },
}

describe("Pack 1 artwork mapping", function()
	it("maps each card to its own uploaded source file and matches the printed card", function()
		local seen = {}
		for _, expected in PACK1 do
			local def = CardRegistry.get(expected.id)
			expect(def ~= nil).toBe(true)
			expect(def.Name).toBe(expected.name)
			expect(def.CollectionNumber).toBe(expected.number)
			expect(def.Rarity).toBe(expected.rarity)
			expect(def.BaseIncome).toBe(expected.income)
			local asset = Config.Assets.Images[def.Artwork]
			expect(asset ~= nil).toBe(true)
			expect(asset.Source).toBe("assets/source/Pack 1/" .. expected.file)
			expect(seen[def.Artwork]).toBeNil() -- no shared image between cards
			seen[def.Artwork] = true
		end
	end)

	it("uses obal.png as the Pack 1 front", function()
		local pack = Config.Packs.ById.pack1
		expect(Config.Assets.Images[pack.Artwork].Source).toBe("assets/source/Pack 1/obal.png")
	end)

	it("makes Pack 1 the starter pack and the first pack", function()
		expect(Config.Economy.StarterPacks.pack1).toBe(3)
		expect(Config.Packs.List[1].Id).toBe("pack1")
		expect(Config.Packs.ById.pack1.CardsPerOpen).toBe(5)
	end)
end)

describe("CardArt fallback", function()
	it("returns nil for images that are not uploaded yet (AssetId = 0)", function()
		for key, asset in Config.Assets.Images do
			if asset.AssetId == 0 then
				expect(CardArt.image(key)).toBeNil()
			end
		end
		expect(CardArt.forCard(CardRegistry.get("pack1_sandy"))).toBe(CardArt.image("card.pack1.sandy"))
	end)

	it("returns nil for unknown keys, empty or non-string input", function()
		expect(CardArt.image("card.nope")).toBeNil()
		expect(CardArt.image("")).toBeNil()
		expect(CardArt.image(nil)).toBeNil()
		expect(CardArt.image(42 :: any)).toBeNil()
		expect(CardArt.forCard(CardRegistry.get("burrow_sable_scout"))).toBeNil()
	end)

	it("resolves configured asset ids and accepts raw content ids", function()
		local asset = Config.Assets.Images["card.pack1.boba"]
		local original = asset.AssetId
		asset.AssetId = 1234567
		expect(CardArt.image("card.pack1.boba")).toBe("rbxassetid://1234567")
		asset.AssetId = -1
		expect(CardArt.image("card.pack1.boba")).toBeNil()
		asset.AssetId = 1.5
		expect(CardArt.image("card.pack1.boba")).toBeNil()
		asset.AssetId = original
		expect(CardArt.image("rbxassetid://99")).toBe("rbxassetid://99")
		expect(CardArt.image("rbxassetid://abc")).toBeNil()
	end)

	it("reports the art aspect ratio (2:3 default)", function()
		expect(CardArt.aspect("card.pack1.sky")).toBeNear(683 / 1024, 1e-9)
		expect(CardArt.aspect("unknown")).toBeNear(2 / 3, 1e-9)
	end)
end)
