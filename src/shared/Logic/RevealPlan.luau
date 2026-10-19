--!strict
-- Manual, synchronised reveal order for a pack opening (roadmap A7).
--
-- An opening of P packs (1, 3 or 6) holds P x CardsPerOpen cards, stored pack by pack by
-- PackShop.open: card k of pack p is cards[(p - 1) * perPack + k]. The reveal goes by
-- ROUND instead: round k shows card k of every pack at once, so one click reveals P cards
-- and no pack is finished before the others.
--
-- The state machine only moves on explicit player actions (no timers):
--   "intro"    -> start()  -> "hidden"   (round 1 face down)
--   "hidden"   -> reveal() -> "revealed" (round flipped)
--   "revealed" -> next()   -> "hidden" (next round) or "summary" (after the last round)
--   any        -> finish() -> "summary"
-- Calls in the wrong state return false and change nothing (double clicks are harmless).

export type Plan = {
	packs: number,
	perPack: number,
	rounds: { { any } },
	phase: string,
	round: number,
}

local RevealPlan = {}

-- rounds[k][p] = card k of pack p.
function RevealPlan.rounds<T>(cards: { T }, packs: number, perPack: number): { { T } }
	local rounds: { { T } } = {}
	for k = 1, perPack do
		local round: { T } = {}
		for p = 1, packs do
			local card = cards[(p - 1) * perPack + k]
			if card ~= nil then
				table.insert(round, card)
			end
		end
		if #round > 0 then
			table.insert(rounds, round)
		end
	end
	return rounds
end

function RevealPlan.new(cards: { any }, packs: number, perPack: number): Plan
	return {
		packs = packs,
		perPack = perPack,
		rounds = RevealPlan.rounds(cards, packs, perPack),
		phase = "intro",
		round = 0,
	}
end

function RevealPlan.start(plan: Plan): boolean
	if plan.phase ~= "intro" then
		return false
	end
	if #plan.rounds == 0 then
		plan.phase = "summary"
	else
		plan.phase, plan.round = "hidden", 1
	end
	return true
end

function RevealPlan.reveal(plan: Plan): boolean
	if plan.phase ~= "hidden" then
		return false
	end
	plan.phase = "revealed"
	return true
end

function RevealPlan.next(plan: Plan): boolean
	if plan.phase ~= "revealed" then
		return false
	end
	if plan.round >= #plan.rounds then
		plan.phase = "summary"
	else
		plan.phase, plan.round = "hidden", plan.round + 1
	end
	return true
end

function RevealPlan.finish(plan: Plan)
	plan.phase = "summary"
end

-- Cards in the current round, in pack order.
function RevealPlan.current(plan: Plan): { any }
	return plan.rounds[plan.round] or {}
end

-- True when the current round is the last one.
function RevealPlan.isLast(plan: Plan): boolean
	return plan.round >= #plan.rounds
end

return RevealPlan
