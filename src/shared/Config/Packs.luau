--!strict
-- Card packs. Buying a pack immediately opens it: each of CardsPerOpen cards rolls a rarity
-- from RarityWeights, then a card of that rarity from the pack's collections, then a variant.
local Types = require(script.Parent.Parent.Types)

local list: { Types.PackDef } = {
	{
		Id = "burrow_pack",
		DisplayName = "Burrow Pack",
		Description = "Backyard favourites. The perfect first pack.",
		Order = 1,
		Price = 750,
		Currency = "Cash",
		CardsPerOpen = 3,
		Collections = { "Burrow" },
		RarityWeights = {
			Common = 600,
			Uncommon = 300,
			Rare = 80,
			Epic = 20,
		},
		Xp = 5,
		Color = Color3.fromRGB(196, 140, 90),
		Artwork = "",
	},
	{
		Id = "snack_pack",
		DisplayName = "Snack Pack",
		Description = "Crumbs, cuddles and one very golden croissant.",
		Order = 2,
		Price = 20000,
		Currency = "Cash",
		CardsPerOpen = 3,
		Collections = { "Snack" },
		RarityWeights = {
			Common = 550,
			Uncommon = 320,
			Rare = 100,
			Legendary = 30,
		},
		Xp = 10,
		Color = Color3.fromRGB(255, 150, 90),
		Artwork = "",
		Unlock = { Level = 3 },
	},
	{
		Id = "knight_pack",
		DisplayName = "Knight Pack",
		Description = "Brave little knights of the ferret realm.",
		Order = 3,
		Price = 125000,
		Currency = "Cash",
		CardsPerOpen = 3,
		Collections = { "Knight" },
		RarityWeights = {
			Common = 500,
			Uncommon = 330,
			Rare = 140,
			Epic = 30,
		},
		Xp = 18,
		Color = Color3.fromRGB(120, 150, 210),
		Artwork = "",
		Unlock = { Level = 5 },
	},
	{
		Id = "shore_pack",
		DisplayName = "Shore Pack",
		Description = "Sun, sand and a lot of seashells.",
		Order = 4,
		Price = 1000000,
		Currency = "Cash",
		CardsPerOpen = 3,
		Collections = { "Shore" },
		RarityWeights = {
			Common = 450,
			Uncommon = 330,
			Rare = 160,
			Epic = 45,
			Legendary = 15,
		},
		Xp = 30,
		Color = Color3.fromRGB(80, 200, 230),
		Artwork = "",
		Unlock = { Level = 8 },
	},
	{
		Id = "cosmic_pack",
		DisplayName = "Cosmic Pack",
		Description = "Ferrets from beyond the stars.",
		Order = 5,
		Price = 15000000,
		Currency = "Cash",
		CardsPerOpen = 3,
		Collections = { "Cosmic" },
		RarityWeights = {
			Uncommon = 500,
			Rare = 330,
			Epic = 120,
			Legendary = 40,
			Mythic = 10,
		},
		Xp = 45,
		Color = Color3.fromRGB(110, 90, 230),
		Artwork = "",
		Unlock = { Level = 11 },
	},
	{
		Id = "midnight_pack",
		DisplayName = "Midnight Pack",
		Description = "Spooky, sneaky and secretly legendary.",
		Order = 6,
		Price = 200000000,
		Currency = "Cash",
		CardsPerOpen = 3,
		Collections = { "Midnight" },
		RarityWeights = {
			Rare = 600,
			Epic = 270,
			Legendary = 90,
			Mythic = 35,
			Secret = 5,
		},
		Xp = 65,
		Color = Color3.fromRGB(70, 50, 110),
		Artwork = "",
		Unlock = { Level = 14 },
	},
}

local byId: { [string]: Types.PackDef } = {}
for _, def in list do
	byId[def.Id] = def
end

return table.freeze({
	List = list,
	ById = byId,
})
