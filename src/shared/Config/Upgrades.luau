--!strict
-- Permanent upgrades bought with currency. Cost for the next level when at level L:
-- floor(BaseCost * CostGrowth ^ L).
local Types = require(script.Parent.Parent.Types)

local list: { Types.UpgradeDef } = {
	{
		Id = "DisplaySlots",
		DisplayName = "Display Stands",
		Description = "+1 display stand for earning income.",
		Order = 1,
		MaxLevel = 8,
		Currency = "Cash",
		BaseCost = 150,
		CostGrowth = 3,
		PerLevel = 1,
	},
	{
		Id = "IncomeBoost",
		DisplayName = "Cosy Hammocks",
		Description = "+10% income from every displayed card.",
		Order = 2,
		MaxLevel = 25,
		Currency = "Cash",
		BaseCost = 500,
		CostGrowth = 1.8,
		PerLevel = 0.1,
	},
	{
		Id = "Luck",
		DisplayName = "Lucky Paw",
		Description = "+5% luck: rarer cards and variants from packs.",
		Order = 3,
		MaxLevel = 10,
		Currency = "Cash",
		BaseCost = 2000,
		CostGrowth = 2.4,
		PerLevel = 0.05,
	},
	{
		Id = "SellBonus",
		DisplayName = "Haggler",
		Description = "+8% cash when selling cards.",
		Order = 4,
		MaxLevel = 10,
		Currency = "Cash",
		BaseCost = 300,
		CostGrowth = 1.9,
		PerLevel = 0.08,
	},
	{
		Id = "BackpackSpace",
		DisplayName = "Bigger Backpack",
		Description = "+50 card capacity.",
		Order = 5,
		MaxLevel = 10,
		Currency = "Cash",
		BaseCost = 1000,
		CostGrowth = 2,
		PerLevel = 50,
	},
}

local byId: { [string]: Types.UpgradeDef } = {}
for _, def in list do
	byId[def.Id] = def
end

return table.freeze({
	List = list,
	ById = byId,
})
