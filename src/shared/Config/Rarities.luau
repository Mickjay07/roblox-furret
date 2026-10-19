--!strict
local Types = require(script.Parent.Parent.Types)

local function rarity(id: string, order: number, color: Color3, luck: boolean): Types.RarityDef
	return table.freeze({
		Id = id,
		DisplayName = string.upper(id),
		Order = order,
		Color = color,
		LuckAffected = luck,
	})
end

local list: { Types.RarityDef } = {
	rarity("Common", 1, Color3.fromRGB(176, 180, 190), false),
	rarity("Uncommon", 2, Color3.fromRGB(96, 206, 72), true),
	rarity("Rare", 3, Color3.fromRGB(58, 146, 255), true),
	rarity("Epic", 4, Color3.fromRGB(176, 86, 255), true),
	rarity("Legendary", 5, Color3.fromRGB(255, 196, 40), true),
	rarity("Mythic", 6, Color3.fromRGB(255, 72, 118), true),
	rarity("Secret", 7, Color3.fromRGB(32, 32, 44), true),
}

local byId: { [string]: Types.RarityDef } = {}
for _, def in list do
	byId[def.Id] = def
end

return table.freeze({
	List = table.freeze(list),
	ById = table.freeze(byId),
})
