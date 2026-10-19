--!strict
-- Idempotent pack opening (spec §7.5, roadmap A7).
--
-- Each OpenPack request carries a request id the client generates once per click. The first
-- request with an id opens exactly ONE owned pack (PackShop.open: the pack is consumed and
-- CardsPerOpen cards are rolled and added on the server). A repeated id - a double click
-- that slipped through, or a retry after a dropped response - gets the remembered result
-- back without opening another pack, so a click can never be rewarded twice.
--
-- Only successful openings are remembered (a failed request changed nothing, so retrying
-- it is safe), and only the last `limit` per player. Forget a player when they leave.
--
-- Pure module: unit-tested under Lune.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Economy = require(Shared.Logic.Economy)
local PackShop = require(Shared.Logic.PackShop)

export type RevealCard = {
	InstanceId: string,
	CardId: string,
	Variant: string,
	IsNew: boolean,
	OneIn: number,
	-- Income per second from the central formula (base x variant x grade).
	Income: number,
}

export type Response = {
	ok: boolean,
	error: string?,
	packId: string?,
	requestId: string?,
	cards: { RevealCard }?,
	levelsGained: number?,
	treatsGained: number?,
}

type PlayerLog = { order: { string }, byId: { [string]: Response } }

export type Ledger = {
	limit: number,
	players: { [number]: PlayerLog },
	open: (
		self: Ledger,
		data: Types.PlayerData,
		userId: number,
		packId: string,
		requestId: string,
		ctx: PackShop.Context
	) -> (Response, PackShop.Opening?),
	forget: (self: Ledger, userId: number) -> (),
	remembered: (self: Ledger, userId: number) -> number,
}

local DEFAULT_LIMIT = 16

local PackOpenRequests = {}

local function remember(ledger: Ledger, userId: number, requestId: string, response: Response)
	local log = ledger.players[userId]
	if not log then
		log = { order = {}, byId = {} }
		ledger.players[userId] = log
	end
	log.byId[requestId] = response
	table.insert(log.order, requestId)
	while #log.order > ledger.limit do
		local oldest = table.remove(log.order, 1)
		if oldest then
			log.byId[oldest] = nil
		end
	end
end

-- Opens one pack for `requestId`, or replays the remembered result for a repeated id.
-- Returns (response for the client, Opening when a pack was actually opened now).
local function open(
	self: Ledger,
	data: Types.PlayerData,
	userId: number,
	packId: string,
	requestId: string,
	ctx: PackShop.Context
): (Response, PackShop.Opening?)
	local log = self.players[userId]
	local previous = if log then log.byId[requestId] else nil
	if previous then
		return previous, nil
	end

	local ok, result = PackShop.open(data, packId, 1, ctx)
	if not ok then
		return { ok = false, error = result }, nil
	end
	local opening: PackShop.Opening = result
	local cards: { RevealCard } = {}
	for _, card in opening.Cards do
		local instance = data.Cards[card.InstanceId]
		table.insert(cards, {
			InstanceId = card.InstanceId,
			CardId = card.CardId,
			Variant = card.Variant,
			IsNew = card.IsNew,
			OneIn = card.OneIn,
			Income = if instance then Economy.cardIncome(instance) else 0,
		})
	end
	local response: Response = {
		ok = true,
		packId = packId,
		requestId = requestId,
		cards = cards,
		levelsGained = opening.LevelsGained,
		treatsGained = opening.TreatsGained,
	}
	remember(self, userId, requestId, response)
	return response, opening
end

local function forget(self: Ledger, userId: number)
	self.players[userId] = nil
end

local function remembered(self: Ledger, userId: number): number
	local log = self.players[userId]
	return if log then #log.order else 0
end

function PackOpenRequests.new(limit: number?): Ledger
	return {
		limit = limit or DEFAULT_LIMIT,
		players = {},
		open = open,
		forget = forget,
		remembered = remembered,
	}
end

return PackOpenRequests
