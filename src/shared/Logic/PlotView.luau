--!strict
-- What each physical stand on a player's plot should show, derived only from the player's
-- saved data (Display + Cards + upgrades). The server applies this to the stand models; the
-- client renders illustrations from it. Pure and testable.
local Types = require(script.Parent.Parent.Types)
local Economy = require(script.Parent.Economy)

export type StandState = {
	Slot: number,
	Unlocked: boolean,
	CardId: string?,
	Variant: string?,
	-- The card's income per second from the central formula (Economy.cardIncome: base x
	-- variant x grade), so clients can show it without recomputing it.
	CardIncome: number?,
}

local PlotView = {}

-- One entry per physical stand 1..maxStands.
function PlotView.standStates(data: Types.PlayerData, maxStands: number): { StandState }
	local unlocked = math.min(Economy.displaySlotCount(data), maxStands)
	local out: { StandState } = {}
	for slot = 1, maxStands do
		local state: StandState =
			{ Slot = slot, Unlocked = slot <= unlocked, CardId = nil, Variant = nil, CardIncome = nil }
		if state.Unlocked then
			local instanceId = data.Display[tostring(slot)]
			local instance = if instanceId then data.Cards[instanceId] else nil
			if instance then
				state.CardId = instance.CardId
				state.Variant = instance.Variant
				state.CardIncome = Economy.cardIncome(instance)
			end
		end
		table.insert(out, state)
	end
	return out
end

-- The state of every stand on an unowned plot (cleared and locked).
function PlotView.empty(maxStands: number): { StandState }
	local out: { StandState } = {}
	for slot = 1, maxStands do
		table.insert(out, { Slot = slot, Unlocked = false, CardId = nil, Variant = nil, CardIncome = nil })
	end
	return out
end

return PlotView
