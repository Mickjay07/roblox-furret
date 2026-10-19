--!strict
-- Cross-reference checks over all Config modules. Returns a list of problems (empty when
-- valid). Run by the unit tests and logged by the server at startup.
local DefaultConfig = require(script.Parent.Parent.Config)

local ConfigCheck = {}

-- `config` defaults to the live Config; tests pass deliberately broken copies.
function ConfigCheck.run(config: any?): { string }
	local Config = config or DefaultConfig
	local problems: { string } = {}
	local function problem(message: string)
		table.insert(problems, message)
	end

	local species = {}
	for _, name in Config.Cards.Species do
		species[name] = true
	end

	local seenIds = {}
	local collectionNumbers: { [string]: { [number]: boolean } } = {}
	for _, card in Config.Cards.List do
		local where = `card {card.Id}`
		if seenIds[card.Id] then
			problem(`{where}: duplicate id`)
		end
		seenIds[card.Id] = true
		if not string.match(card.Id, "^[%w_]+$") or #card.Id > Config.Game.Limits.MaxIdLength then
			problem(`{where}: id must be [A-Za-z0-9_] and <= {Config.Game.Limits.MaxIdLength} chars`)
		end
		if card.Name == "" or card.Description == "" then
			problem(`{where}: missing name or description`)
		end
		if not species[card.Species] then
			problem(`{where}: unknown species {card.Species}`)
		end
		if not Config.Rarities.ById[card.Rarity] then
			problem(`{where}: unknown rarity {card.Rarity}`)
		end
		if not Config.Collections.ById[card.Collection] then
			problem(`{where}: unknown collection {card.Collection}`)
		end
		if card.BaseIncome <= 0 or card.BaseSaleValue <= 0 then
			problem(`{where}: income and sale value must be positive`)
		end
		local numbers = collectionNumbers[card.Collection] or {}
		collectionNumbers[card.Collection] = numbers
		if numbers[card.CollectionNumber] then
			problem(`{where}: duplicate CollectionNumber {card.CollectionNumber}`)
		end
		numbers[card.CollectionNumber] = true
		if card.Variants then
			for _, variant in card.Variants do
				if not Config.Variants.ById[variant] then
					problem(`{where}: unknown variant {variant}`)
				end
			end
		end
		if card.Unlock and card.Unlock.CollectionComplete then
			if not Config.Collections.ById[card.Unlock.CollectionComplete] then
				problem(`{where}: unlock references unknown collection`)
			end
		end
	end

	for _, pack in Config.Packs.List do
		local where = `pack {pack.Id}`
		if pack.Price <= 0 or pack.CardsPerOpen < 1 then
			problem(`{where}: price and CardsPerOpen must be positive`)
		end
		if not Config.Economy.Currencies[pack.Currency] then
			problem(`{where}: unknown currency {pack.Currency}`)
		end
		for rarity, weight in pack.RarityWeights do
			if not Config.Rarities.ById[rarity] then
				problem(`{where}: unknown rarity {rarity}`)
			elseif weight <= 0 then
				problem(`{where}: weight for {rarity} must be positive`)
			end
		end
		for _, collectionId in pack.Collections do
			if not Config.Collections.ById[collectionId] then
				problem(`{where}: unknown collection {collectionId}`)
			end
		end
		-- Every weighted rarity should have at least one card in the pack's collections.
		for rarity in pack.RarityWeights do
			local found = false
			for _, card in Config.Cards.List do
				if card.Rarity == rarity and table.find(pack.Collections, card.Collection) then
					found = true
					break
				end
			end
			if not found then
				problem(`{where}: no {rarity} card in its collections`)
			end
		end
	end

	for packId, count in Config.Economy.StarterPacks do
		if not Config.Packs.ById[packId] then
			problem(`starter pack {packId} does not exist`)
		elseif count % 1 ~= 0 or count < 1 then
			problem(`starter pack {packId}: count must be a positive integer`)
		end
	end
	local income = Config.Economy.Income
	if income.StandCapSeconds <= 0 or income.OfflineCapSeconds < 0 or income.OfflineRate < 0 then
		problem("income: StandCapSeconds must be positive, offline settings non-negative")
	end

	for currency in Config.Economy.StartingCurrency do
		if not Config.Economy.Currencies[currency] then
			problem(`starting currency {currency} is not a defined currency`)
		end
	end

	for _, upgrade in Config.Upgrades.List do
		if upgrade.MaxLevel < 1 or upgrade.BaseCost <= 0 or upgrade.CostGrowth < 1 then
			problem(`upgrade {upgrade.Id}: invalid level/cost settings`)
		end
		if not Config.Economy.Currencies[upgrade.Currency] then
			problem(`upgrade {upgrade.Id}: unknown currency {upgrade.Currency}`)
		end
	end

	if #Config.Grading.Multipliers ~= 10 or #Config.Grading.Labels ~= 10 or #Config.Grading.SubGradeWeights ~= 10 then
		problem("grading: Multipliers, Labels and SubGradeWeights need exactly 10 entries")
	end

	-- Every pack and card must be reachable: each card appears in at least one pack.
	for _, card in Config.Cards.List do
		local inPack = false
		for _, pack in Config.Packs.List do
			if table.find(pack.Collections, card.Collection) and pack.RarityWeights[card.Rarity] then
				inPack = true
				break
			end
		end
		if not inPack then
			problem(`card {card.Id}: not obtainable from any pack`)
		end
	end

	return problems
end

return ConfigCheck
