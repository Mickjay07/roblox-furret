--!strict
-- Card variants (finishes). A variant multiplies the card's income and sale value.
local Types = require(script.Parent.Parent.Types)

local function variant(
	id: string,
	order: number,
	color: Color3,
	mult: number,
	weight: number,
	luck: boolean
): Types.VariantDef
	return table.freeze({
		Id = id,
		DisplayName = string.upper(id),
		Order = order,
		Color = color,
		IncomeMultiplier = mult,
		SaleMultiplier = mult,
		DropWeight = weight,
		LuckAffected = luck,
	})
end

local list: { Types.VariantDef } = {
	variant("Normal", 1, Color3.fromRGB(255, 255, 255), 1, 1000, false),
	variant("Shiny", 2, Color3.fromRGB(190, 240, 255), 1.5, 60, true),
	variant("Gold", 3, Color3.fromRGB(255, 205, 60), 3, 15, true),
	variant("Holo", 4, Color3.fromRGB(150, 220, 255), 6, 4, true),
	variant("Rainbow", 5, Color3.fromRGB(255, 120, 200), 12, 1, true),
}

local byId: { [string]: Types.VariantDef } = {}
for _, def in list do
	byId[def.Id] = def
end

return table.freeze({
	Default = "Normal",
	List = table.freeze(list),
	ById = table.freeze(byId),
})
