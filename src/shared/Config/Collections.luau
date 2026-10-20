--!strict
-- Card collections ("binders"). Each card belongs to exactly one collection.
local Types = require(script.Parent.Parent.Types)

local function collection(id: string, name: string, order: number, color: Color3, bonus: number): Types.CollectionDef
	return table.freeze({
		Id = id,
		DisplayName = name,
		Order = order,
		Color = color,
		CompletionIncomeBonus = bonus,
	})
end

local list: { Types.CollectionDef } = {
	-- Pack 1: the first real artwork set (assets/source/Pack 1), cards #001-#006.
	collection("Pack1", "Pack 1", 0, Color3.fromRGB(70, 170, 255), 0.05),
	collection("Burrow", "Backyard Burrow", 1, Color3.fromRGB(196, 140, 90), 0.05),
	collection("Snack", "Snack Attack", 2, Color3.fromRGB(255, 150, 90), 0.05),
	collection("Knight", "Knight Patrol", 3, Color3.fromRGB(120, 150, 210), 0.08),
	collection("Shore", "Sandy Shores", 4, Color3.fromRGB(80, 200, 230), 0.08),
	collection("Cosmic", "Cosmic Scampers", 5, Color3.fromRGB(110, 90, 230), 0.12),
	collection("Midnight", "Midnight Mischief", 6, Color3.fromRGB(70, 50, 110), 0.15),
	-- Promo Ferrets (#100-#110). Hidden until the owner confirms the card data (Config.Cards).
	table.freeze({
		Id = "Promo",
		DisplayName = "Promo Ferrets",
		Order = 50,
		Color = Color3.fromRGB(255, 120, 200),
		CompletionIncomeBonus = 0,
		Hidden = true,
	}),
}

local byId: { [string]: Types.CollectionDef } = {}
for _, def in list do
	byId[def.Id] = def
end

return table.freeze({
	List = table.freeze(list),
	ById = table.freeze(byId),
})
