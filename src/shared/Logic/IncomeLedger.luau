--!strict
-- Stand earnings (spec §10, owner decision Q3). Each display stand accumulates the income of
-- the card on it; the player collects one stand or all stands at once. Offline time is
-- capped and accrues onto the stands, so it is collected the same way.
--
-- Pending earnings belong to the stand, not the card: swapping or removing a card keeps what
-- the stand has already earned. Only the server calls the mutating functions.
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)
local Economy = require(script.Parent.Economy)
local Wallet = require(script.Parent.Wallet)

local IncomeLedger = {}

-- Effective income per second of one stand (0 when empty or locked).
function IncomeLedger.standIncome(data: Types.PlayerData, slotKey: string, extra: number?): number
	local slot = tonumber(slotKey)
	if not slot or slot < 1 or slot > Economy.displaySlotCount(data) then
		return 0
	end
	local instanceId = data.Display[slotKey]
	local instance = if instanceId then data.Cards[instanceId] else nil
	if not instance then
		return 0
	end
	return Economy.cardIncome(instance) * Economy.incomeMultiplier(data, extra)
end

function IncomeLedger.pending(data: Types.PlayerData, slotKey: string): number
	return data.Income.Pending[slotKey] or 0
end

function IncomeLedger.pendingTotal(data: Types.PlayerData): number
	local total = 0
	for _, amount in data.Income.Pending do
		total += amount
	end
	return total
end

-- Adds `seconds` of income to every occupied stand, respecting each stand's cap.
-- Returns the total amount added.
function IncomeLedger.accrue(data: Types.PlayerData, seconds: number, extra: number?): number
	if seconds <= 0 or seconds ~= seconds then
		return 0
	end
	local cap = Config.Economy.Income.StandCapSeconds
	local added = 0
	for slotKey in data.Display do
		local perSecond = IncomeLedger.standIncome(data, slotKey, extra)
		if perSecond > 0 then
			local current = IncomeLedger.pending(data, slotKey)
			local limit = perSecond * cap
			local new = math.min(limit, current + perSecond * seconds)
			if new > current then
				data.Income.Pending[slotKey] = new
				added += new - current
			end
		end
	end
	return added
end

-- Moves one stand's earnings into Cash. Returns the amount collected (0 if nothing).
-- Whole cash only: the fractional remainder stays on the stand.
function IncomeLedger.collect(data: Types.PlayerData, slotKey: string): number
	local amount = math.floor(IncomeLedger.pending(data, slotKey))
	if amount <= 0 then
		return 0
	end
	local remainder = IncomeLedger.pending(data, slotKey) - amount
	if remainder > 0 then
		data.Income.Pending[slotKey] = remainder
	else
		data.Income.Pending[slotKey] = nil
	end
	Wallet.add(data, "Cash", amount)
	return amount
end

-- Central collection of every stand.
function IncomeLedger.collectAll(data: Types.PlayerData): number
	local total = 0
	local keys = {}
	for slotKey in data.Income.Pending do
		table.insert(keys, slotKey)
	end
	for _, slotKey in keys do
		total += IncomeLedger.collect(data, slotKey)
	end
	return total
end

-- Credits capped offline earnings onto the stands, based on the saved LastOnline timestamp
-- (server time only). Returns (amount added, seconds counted). LastOnline = 0 means the
-- player has never been online, so nothing is awarded. `offlineMultiplier` (2x AFK Time
-- Cash) scales only these offline earnings; the caller applies it exactly once per join.
function IncomeLedger.applyOffline(
	data: Types.PlayerData,
	now: number,
	extra: number?,
	offlineMultiplier: number?
): (number, number)
	local last = data.Income.LastOnline
	if last <= 0 or now <= last then
		return 0, 0
	end
	local settings = Config.Economy.Income
	local seconds = math.min(now - last, settings.OfflineCapSeconds)
	local added = IncomeLedger.accrue(data, seconds * settings.OfflineRate, (extra or 1) * (offlineMultiplier or 1))
	return added, seconds
end

function IncomeLedger.markOnline(data: Types.PlayerData, now: number)
	data.Income.LastOnline = now
end

-- Repairs pending entries after load. Invalid amounts are dropped; valid earnings on stands
-- that no longer exist (e.g. after a slot-count config change) are paid out as Cash, because
-- they were earned. Earnings on empty but existing stands stay. Returns true if changed.
function IncomeLedger.sanitize(data: Types.PlayerData): boolean
	local changed = false
	local slots = Economy.displaySlotCount(data)
	local keys = {}
	for slotKey in data.Income.Pending do
		table.insert(keys, slotKey)
	end
	for _, slotKey in keys do
		local amount = data.Income.Pending[slotKey]
		local slot = tonumber(slotKey)
		local validAmount = type(amount) == "number" and amount == amount and amount >= 0 and amount ~= math.huge
		local validSlot = slot ~= nil and slot >= 1 and slot <= slots and slot % 1 == 0
		if not validAmount then
			data.Income.Pending[slotKey] = nil
			changed = true
		elseif not validSlot then
			data.Income.Pending[slotKey] = nil
			Wallet.add(data, "Cash", math.floor(amount))
			changed = true
		end
	end
	return changed
end

return IncomeLedger
