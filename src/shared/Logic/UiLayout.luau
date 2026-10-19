--!strict
-- Pure layout and wording helpers for the client UI (unit-tested under Lune).
local Config = require(script.Parent.Parent.Config)
local Format = require(script.Parent.Parent.Util.Format)

local UiLayout = {}

-- Scale for a window authored at `size` so it never leaves the viewport: the normal UI
-- scale, reduced further when the window (plus `margin` px on each side) wouldn't fit.
function UiLayout.fitScale(viewport: Vector2, size: Vector2, baseScale: number, margin: number?): number
	local pad = (margin or 16) * 2
	local fitX = (viewport.X - pad) / size.X
	local fitY = (viewport.Y - pad) / size.Y
	return math.max(0.3, math.min(baseScale, fitX, fitY))
end

-- What an upgrade's total effect means at `level`, e.g. "+30% income" or "+2 stands".
function UiLayout.upgradeEffect(upgradeId: string, level: number): string
	local def = Config.Upgrades.ById[upgradeId]
	if not def then
		return ""
	end
	local value = level * def.PerLevel
	if upgradeId == "DisplaySlots" then
		return `+{value} stand{if value == 1 then "" else "s"}`
	elseif upgradeId == "BackpackSpace" then
		return `+{Format.commas(value)} card slots`
	elseif upgradeId == "IncomeBoost" then
		return `+{math.floor(value * 100 + 0.5)}% income`
	elseif upgradeId == "Luck" then
		return `+{math.floor(value * 100 + 0.5)}% luck`
	elseif upgradeId == "SellBonus" then
		return `+{math.floor(value * 100 + 0.5)}% sell price`
	end
	return `+{value}`
end

-- Label for a price the player can't afford yet, e.g. "NEED $1.2K".
function UiLayout.shortfall(balance: number, price: number): string?
	if balance >= price then
		return nil
	end
	return `NEED ${Format.short(price - balance, 1e6)}`
end

return UiLayout
