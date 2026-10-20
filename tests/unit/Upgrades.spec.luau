-- Upgrade purchases: full-price labels, affordability (balance >= price, same rule on client
-- and server), exact-once deduction, maxed upgrades, repeated requests and toast dedupe.
local TestKit = require("../TestKit")
local Loader = require("../Loader")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local Config = Loader.require("src/shared/Config")
local ProfileSchema = Loader.require("src/shared/Data/ProfileSchema")
local Economy = Loader.require("src/shared/Logic/Economy")
local UiLayout = Loader.require("src/shared/Logic/UiLayout")
local UpgradeShop = Loader.require("src/shared/Logic/UpgradeShop")
local Dedupe = Loader.require("src/shared/Util/Dedupe")
local Format = Loader.require("src/shared/Util/Format")

local HAMMOCKS = Config.Upgrades.ById.IncomeBoost

local function player(cash: number, level: number?)
	local data = ProfileSchema.defaults()
	data.Currency.Cash = cash
	if level then
		data.Upgrades.IncomeBoost = level
	end
	return data
end

describe("Upgrade buttons show the full price", function()
	it("reproduces the reported bug: level 21 Cosy Hammocks with $108.8M", function()
		-- floor(500 * 1.8^21) = 114,734,125; balance 108,819,342 -> short by 5,914,783.
		local price = Economy.upgradeCost(HAMMOCKS, 21)
		expect(price).toBe(114734125)
		local button = UiLayout.upgradeButton(HAMMOCKS, 21, 108819342)
		-- The button shows the full price, never the shortfall.
		expect(button.Text).toBe("$115M")
		expect(string.find(button.Text, "NEED", 1, true)).toBeNil()
		expect(button.Affordable).toBe(false)
		expect(button.Style).toBe("Gray")
		expect(button.Hint).toBe("Need $5.92M more")
		expect(button.Price).toBe(price)
	end)

	it("is green with the full price when affordable, and has no hint", function()
		local button = UiLayout.upgradeButton(HAMMOCKS, 0, 10000)
		expect(button.Text).toBe("$500")
		expect(button.Style).toBe("Green")
		expect(button.Affordable).toBe(true)
		expect(button.Hint).toBeNil()
	end)

	it("treats an exact balance as affordable and one cash less as not", function()
		local price = Economy.upgradeCost(HAMMOCKS, 5)
		expect(UiLayout.upgradeButton(HAMMOCKS, 5, price).Affordable).toBe(true)
		expect(UiLayout.upgradeButton(HAMMOCKS, 5, price - 1).Affordable).toBe(false)
		expect(UiLayout.upgradeButton(HAMMOCKS, 5, price - 1).Hint).toBe("Need $1 more")
		expect(UiLayout.upgradeButton(HAMMOCKS, 5, price + 1).Affordable).toBe(true)
	end)

	it("shows MAXED at the max level, with no price", function()
		local button = UiLayout.upgradeButton(HAMMOCKS, HAMMOCKS.MaxLevel, 1e15)
		expect(button.Text).toBe("MAXED")
		expect(button.Maxed).toBe(true)
		expect(button.Price).toBeNil()
		expect(button.Affordable).toBe(false)
	end)

	it("uses the same price formula as the server for every upgrade and level", function()
		for _, def in Config.Upgrades.List do
			for level = 0, def.MaxLevel - 1 do
				expect(UiLayout.upgradeButton(def, level, 0).Price).toBe(Economy.upgradeCost(def, level))
			end
		end
	end)
end)

describe("Format.price never understates a price", function()
	it("rounds up to 3 significant digits", function()
		expect(Format.price(150000000, 1e6)).toBe("150M")
		expect(Format.price(5910000, 1e6)).toBe("5.91M")
		expect(Format.price(5914783, 1e6)).toBe("5.92M")
		expect(Format.price(114734125, 1e6)).toBe("115M")
		expect(Format.price(1500, 1e6)).toBe("1,500")
		expect(Format.price(999999999, 1e6)).toBe("1B")
	end)

	it("is never below the real price, so a displayed balance >= displayed price is real", function()
		local state = 12345
		for _ = 1, 500 do
			state = (state * 1103515245 + 12345) % 2147483648
			local price = 1e6 + state * 37
			local shown = Format.price(price, 1e6)
			local number, suffix = string.match(shown, "^([%d%.]+)(%a+)$")
			local scale = ({ K = 1e3, M = 1e6, B = 1e9, T = 1e12 })[suffix]
			expect(tonumber(number) * scale + 1e-3 >= price).toBe(true)
		end
	end)
end)

describe("UpgradeShop.buy (server validation)", function()
	it("deducts the price exactly once and raises the level", function()
		local price = Economy.upgradeCost(HAMMOCKS, 0)
		local data = player(price + 7)
		local ok, level = UpgradeShop.buy(data, "IncomeBoost")
		expect(ok).toBe(true)
		expect(level).toBe(1)
		expect(data.Currency.Cash).toBe(7)
		expect(data.Upgrades.IncomeBoost).toBe(1)
	end)

	it("buys with an exact balance", function()
		local price = Economy.upgradeCost(HAMMOCKS, 3)
		local data = player(price, 3)
		expect((UpgradeShop.buy(data, "IncomeBoost"))).toBe(true)
		expect(data.Currency.Cash).toBe(0)
	end)

	it("rejects an unaffordable upgrade and changes nothing", function()
		local data = player(108819342, 21)
		local ok, message = UpgradeShop.buy(data, "IncomeBoost")
		expect(ok).toBe(false)
		expect(message).toBe("Not enough Cash")
		expect(data.Currency.Cash).toBe(108819342)
		expect(data.Upgrades.IncomeBoost).toBe(21)
	end)

	it("rejects a maxed upgrade without charging", function()
		local data = player(1e15, HAMMOCKS.MaxLevel)
		local ok, message = UpgradeShop.buy(data, "IncomeBoost")
		expect(ok).toBe(false)
		expect(message).toBe("Already at max level")
		expect(data.Currency.Cash).toBe(1e15)
	end)

	it("rejects unknown upgrades", function()
		local data = player(1e9)
		expect((UpgradeShop.buy(data, "Nope"))).toBe(false)
		expect(data.Currency.Cash).toBe(1e9)
	end)

	it("a duplicate request only buys what the balance pays for (each one priced again)", function()
		local first = Economy.upgradeCost(HAMMOCKS, 0)
		local data = player(first + 10)
		expect((UpgradeShop.buy(data, "IncomeBoost"))).toBe(true)
		-- The repeat is for the next level, which now costs more than what is left.
		expect((UpgradeShop.buy(data, "IncomeBoost"))).toBe(false)
		expect(data.Upgrades.IncomeBoost).toBe(1)
		expect(data.Currency.Cash).toBe(10)
	end)
end)

describe("Toast dedupe", function()
	it("shows an identical message once within the window", function()
		local now = 0
		local show = Dedupe.new(3, function()
			return now
		end)
		expect(show("error|Not enough Cash")).toBe(true)
		now = 1
		expect(show("error|Not enough Cash")).toBe(false)
		now = 2.9
		expect(show("error|Not enough Cash")).toBe(false)
		-- A different message is not affected.
		expect(show("success|Collected $5")).toBe(true)
		now = 4
		expect(show("error|Not enough Cash")).toBe(true)
	end)
end)
