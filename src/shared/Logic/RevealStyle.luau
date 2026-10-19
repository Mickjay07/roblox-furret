--!strict
-- How exciting each card's reveal is in the pack opening sequence (spec §7.5, roadmap A7).
-- Pure: the client animates from this, and tests check that rarer cards get bigger effects.
local Config = require(script.Parent.Parent.Config)
local Format = require(script.Parent.Parent.Util.Format)

export type Style = {
	Tier: number, -- 1 (Common/Uncommon) .. 4 (Legendary and above)
	Glow: boolean,
	Burst: number, -- sparkle particles fired when the card flips
	Rays: boolean, -- rotating light rays behind the card
	Flash: boolean, -- full-screen flash and stage shake
	Banner: string?, -- big rarity banner ("LEGENDARY!")
	Hold: number, -- seconds before the reveal auto-advances
}

local RevealStyle = {}

-- Tier from the rarity's Order: 1-2 -> 1, 3 (Rare) -> 2, 4 (Epic) -> 3, 5+ -> 4.
function RevealStyle.tier(rarityId: string): number
	local rarity = Config.Rarities.ById[rarityId]
	local order = if rarity then rarity.Order else 1
	return math.clamp(order - 1, 1, 4)
end

function RevealStyle.forRarity(rarityId: string): Style
	local tier = RevealStyle.tier(rarityId)
	local rarity = Config.Rarities.ById[rarityId]
	return {
		Tier = tier,
		Glow = tier >= 1,
		Burst = ({ 0, 10, 18, 30 })[tier],
		Rays = tier >= 3,
		Flash = tier >= 4,
		Banner = if tier >= 3 and rarity then `{rarity.DisplayName}!` else nil,
		Hold = ({ 2.2, 2.6, 3.2, 4 })[tier],
	}
end

-- The highest tier among the opened cards: drives how much the pack shakes before opening.
function RevealStyle.packTier(rarityIds: { string }): number
	local best = 1
	for _, rarityId in rarityIds do
		best = math.max(best, RevealStyle.tier(rarityId))
	end
	return best
end

-- Variant label shown on the reveal, e.g. "SHINY +2%"; nil for Normal copies.
function RevealStyle.variantLabel(variantId: string, income: number, baseIncome: number): string?
	if variantId == Config.Variants.Default then
		return nil
	end
	local variant = Config.Variants.ById[variantId]
	local name = if variant then variant.DisplayName else string.upper(variantId)
	local bonus = Format.bonusPercent(income, baseIncome)
	return if bonus then `{name} {bonus}` else name
end

return RevealStyle
