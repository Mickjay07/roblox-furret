-- Economy pacing simulation: `lune run scripts/simulate [hours]`.
-- Plays a simple greedy strategy against the real Config and Logic modules, one-second
-- ticks, and reports when packs unlock and how income grows. A balancing aid, not a test.

local process = require("@lune/process")
local Loader = require("../tests/Loader")

local Config = Loader.require("src/shared/Config")
local ProfileSchema = Loader.require("src/shared/Data/ProfileSchema")
local Account = Loader.require("src/shared/Logic/Account")
local Display = Loader.require("src/shared/Logic/Display")
local Economy = Loader.require("src/shared/Logic/Economy")
local Inventory = Loader.require("src/shared/Logic/Inventory")
local Market = Loader.require("src/shared/Logic/Market")
local PackShop = Loader.require("src/shared/Logic/PackShop")
local UpgradeShop = Loader.require("src/shared/Logic/UpgradeShop")
local Format = Loader.require("src/shared/Util/Format")
local IncomeLedger = Loader.require("src/shared/Logic/IncomeLedger")

local hours = tonumber(process.args[1]) or 2
math.randomseed(1)

local data = ProfileSchema.defaults()
Account.grantStarter(data)
-- Open the starter packs straight away, as a new player would.
for packId, count in data.Packs do
	PackShop.open(data, packId, count, { ownerId = 1, now = 0 })
end
Display.placeBest(data)

local unlocked = {}
local function report(t: number, text: string)
	print(
		string.format(
			"%8s  lvl %2d  %10s/s  %s",
			Format.duration(t),
			data.Progression.Level,
			Format.short(Economy.totalIncome(data)),
			text
		)
	)
end

for t = 1, hours * 3600 do
	-- Stands accumulate; the bot collects everything every 10 seconds.
	IncomeLedger.accrue(data, 1)
	if t % 10 == 0 then
		IncomeLedger.collectAll(data)
	end
	local income = math.max(Economy.totalIncome(data), 1)

	-- Upgrades that pay back within 60 seconds of income.
	for _, def in Config.Upgrades.List do
		local cost = Economy.upgradeCost(def, Economy.upgradeLevel(data, def.Id))
		if cost and cost <= data.Currency.Cash and cost <= income * 60 then
			UpgradeShop.buy(data, def.Id)
			Display.placeBest(data)
		end
	end

	-- Save for the best unlocked pack, then buy it.
	for i = #Config.Packs.List, 1, -1 do
		local pack = Config.Packs.List[i]
		if PackShop.isUnlocked(data, pack) then
			if not unlocked[pack.Id] then
				unlocked[pack.Id] = true
				report(t, "unlocked " .. pack.DisplayName)
			end
			if data.Currency.Cash >= pack.Price then
				if Inventory.freeSpace(data) < pack.CardsPerOpen then
					-- Sell the weakest cards that are not on a stand.
					local spare = {}
					for id, inst in data.Cards do
						if not Inventory.displaySlotOf(data, id) then
							table.insert(spare, { id = id, income = Economy.cardIncome(inst) })
						end
					end
					table.sort(spare, function(a, b)
						return a.income < b.income
					end)
					local ids = {}
					for k = 1, math.min(Config.Game.Limits.MaxCardsPerSell, #spare) do
						table.insert(ids, spare[k].id)
					end
					if #ids > 0 then
						Market.sell(data, ids)
					end
				end
				if PackShop.buy(data, pack.Id, 1) and PackShop.open(data, pack.Id, 1, { ownerId = 1, now = t }) then
					Display.placeBest(data)
				end
			end
			break
		end
	end
	if t % 900 == 0 then
		report(t, `cash {Format.short(data.Currency.Cash)}, packs {data.Stats.PacksOpened}`)
	end
end
