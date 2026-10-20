--!strict
-- Developer commands (spec §31: development-only test utilities; roadmap A1).
--
-- Safety model:
--   * DevService only creates the DevCommand remote inside Roblox Studio, so these commands
--     do not exist on live servers at all.
--   * A command line is parsed against the fixed COMMANDS table below. Nothing is ever
--     evaluated as code; every argument is range-checked.
--   * Commands only touch the calling player's own data, through the same pure rules the
--     game uses (Wallet, Inventory, PackShop, IncomeLedger, PackRoller).
--
-- Pure module: unit-tested under Lune with a fake context.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local ProfileSchema = require(Shared.Data.ProfileSchema)
local CardRegistry = require(Shared.Logic.CardRegistry)
local Economy = require(Shared.Logic.Economy)
local IncomeLedger = require(Shared.Logic.IncomeLedger)
local Inventory = require(Shared.Logic.Inventory)
local PackRoller = require(Shared.Logic.PackRoller)
local PackShop = require(Shared.Logic.PackShop)
local Format = require(Shared.Util.Format)

export type Context = {
	data: Types.PlayerData,
	ownerId: number,
	now: number,
	roll: (() -> number)?,
}

type Command = {
	Usage: string,
	Description: string,
	Run: (ctx: Context, args: { string }) -> (boolean, string, { string }?),
}

local DevCommands = {}

DevCommands.MAX_LINE = 200
DevCommands.MAX_ARGS = 6

-- Splits "/cash 1000" into ("cash", { "1000" }). Returns (nil, reason) on bad input.
function DevCommands.parse(line: any): (string?, { string } | string)
	if type(line) ~= "string" or #line == 0 or #line > DevCommands.MAX_LINE then
		return nil, "empty or too long"
	end
	local tokens = {}
	for token in string.gmatch(line, "%S+") do
		if not string.match(token, "^[%w_%.%-]+$") and not (#tokens == 0 and string.match(token, "^/[%w_]+$")) then
			return nil, `invalid token "{token}"`
		end
		table.insert(tokens, token)
		if #tokens > DevCommands.MAX_ARGS + 1 then
			return nil, "too many arguments"
		end
	end
	if #tokens == 0 then
		return nil, "empty"
	end
	local name = string.lower((string.gsub(tokens[1], "^/", "")))
	table.remove(tokens, 1)
	return name, tokens
end

local function int(value: string?, min: number, max: number, default: number?): number?
	if value == nil then
		return default
	end
	local n = tonumber(value)
	if n == nil or n ~= n or n % 1 ~= 0 or n < min or n > max then
		return nil
	end
	return n
end

local function percent(x: number): string
	return string.format("%.2f%%", x * 100)
end

local COMMANDS: { [string]: Command } = {}

COMMANDS.cash = {
	Usage = "cash <amount>",
	Description = "Add Cash (1 to 1e15).",
	Run = function(ctx, args)
		local amount = int(args[1], 1, 1e15)
		if not amount then
			return false, "amount must be an integer from 1 to 1e15"
		end
		ctx.data.Currency.Cash = (ctx.data.Currency.Cash or 0) + amount
		return true, `+{Format.commas(amount)} Cash`, { "Currency" }
	end,
}

COMMANDS.setcash = {
	Usage = "setcash <amount>",
	Description = "Set Cash exactly (0 to 1e15).",
	Run = function(ctx, args)
		local amount = int(args[1], 0, 1e15)
		if not amount then
			return false, "amount must be an integer from 0 to 1e15"
		end
		ctx.data.Currency.Cash = amount
		return true, `Cash = {Format.commas(amount)}`, { "Currency" }
	end,
}

COMMANDS.packs = {
	Usage = "packs <packId> [count]",
	Description = "Add unopened packs to the pack inventory (count 1 to 100).",
	Run = function(ctx, args)
		local packId = args[1]
		if not packId or not Config.Packs.ById[packId] then
			return false, "unknown pack id"
		end
		local count = int(args[2], 1, 100, 1)
		if not count then
			return false, "count must be 1 to 100"
		end
		PackShop.grant(ctx.data, packId, count)
		return true, `+{count} {packId} (now {PackShop.owned(ctx.data, packId)})`, { "Packs" }
	end,
}

COMMANDS.card = {
	Usage = "card <cardId> [variant] [count]",
	Description = "Create test cards (ignores backpack capacity; count 1 to 50).",
	Run = function(ctx, args)
		local cardId = args[1]
		if not cardId or not CardRegistry.exists(cardId) then
			return false, "unknown card id"
		end
		local variant = args[2] or Config.Variants.Default
		local count = int(args[3], 1, 50, 1)
		if not count then
			return false, "count must be 1 to 50"
		end
		for _ = 1, count do
			local id, reason = Inventory.add(ctx.data, ctx.ownerId, cardId, variant, ctx.now, true)
			if not id then
				return false, tostring(reason)
			end
		end
		return true, `+{count} {cardId} ({variant})`, { "Cards", "Discovered", "Stats" }
	end,
}

COMMANDS.allcards = {
	Usage = "allcards",
	Description = "Create one Normal copy of every card definition.",
	Run = function(ctx)
		for _, def in CardRegistry.all() do
			Inventory.add(ctx.data, ctx.ownerId, def.Id, Config.Variants.Default, ctx.now, true)
		end
		return true, `+{CardRegistry.count()} cards`, { "Cards", "Discovered", "Stats" }
	end,
}

COMMANDS.level = {
	Usage = "level <n>",
	Description = "Set the player level (XP resets to 0).",
	Run = function(ctx, args)
		local level = int(args[1], 1, Config.Economy.Progression.MaxLevel)
		if not level then
			return false, `level must be 1 to {Config.Economy.Progression.MaxLevel}`
		end
		ctx.data.Progression.Level, ctx.data.Progression.Xp = level, 0
		return true, `level = {level}`, { "Progression" }
	end,
}

COMMANDS.accrue = {
	Usage = "accrue <seconds>",
	Description = "Fast-forward stand earnings (respects the stand cap).",
	Run = function(ctx, args)
		local seconds = int(args[1], 1, 30 * 24 * 3600)
		if not seconds then
			return false, "seconds must be 1 to 2592000"
		end
		local added = IncomeLedger.accrue(ctx.data, seconds)
		return true, `stands earned {Format.commas(added)} over {Format.duration(seconds)}`, { "Income" }
	end,
}

COMMANDS.offline = {
	Usage = "offline <seconds>",
	Description = "Simulate being offline for <seconds> and apply offline earnings now.",
	Run = function(ctx, args)
		local seconds = int(args[1], 1, 30 * 24 * 3600)
		if not seconds then
			return false, "seconds must be 1 to 2592000"
		end
		ctx.data.Income.LastOnline = math.max(1, ctx.now - seconds)
		-- Same rule as a real join: 2x AFK Time Cash doubles these earnings once.
		local multiplier = Economy.offlineMultiplier(ctx.data)
		local added, counted = IncomeLedger.applyOffline(ctx.data, ctx.now, 1, multiplier)
		IncomeLedger.markOnline(ctx.data, ctx.now)
		return true,
			`offline {Format.duration(seconds)}: counted {Format.duration(counted)} (cap {Format.duration(
				Config.Economy.Income.OfflineCapSeconds
			)}), stands earned {Format.commas(added)}{if multiplier > 1 then ` (x{multiplier} AFK pass)` else ""}`,
			{ "Income" }
	end,
}

COMMANDS.roll = {
	Usage = "roll <packId> [cards]",
	Description = "Roll cards from a pack WITHOUT granting them; compare rarity results with the configured odds.",
	Run = function(ctx, args)
		local pack = args[1] and Config.Packs.ById[args[1]]
		if not pack then
			return false, "unknown pack id"
		end
		local n = int(args[2], 1, 100000, 1000)
		if not n then
			return false, "cards must be 1 to 100000"
		end
		local options = { roll = ctx.roll }
		local byRarity: { [string]: number } = {}
		local byVariant: { [string]: number } = {}
		for _ = 1, n do
			local result = PackRoller.rollCard(pack, options)
			local def = CardRegistry.get(result.CardId)
			if def then
				byRarity[def.Rarity] = (byRarity[def.Rarity] or 0) + 1
			end
			byVariant[result.Variant] = (byVariant[result.Variant] or 0) + 1
		end
		local expected: { [string]: number } = {}
		for cardId, p in PackRoller.odds(pack, options) do
			local def = CardRegistry.get(cardId)
			if def then
				expected[def.Rarity] = (expected[def.Rarity] or 0) + p
			end
		end
		local lines = { `{n} rolls of {pack.Id}:` }
		for _, rarity in Config.Rarities.List do
			if expected[rarity.Id] or byRarity[rarity.Id] then
				local got = (byRarity[rarity.Id] or 0) / n
				table.insert(lines, `  {rarity.Id}: {percent(got)} (expected {percent(expected[rarity.Id] or 0)})`)
			end
		end
		local variants = {}
		for _, variant in Config.Variants.List do
			if byVariant[variant.Id] then
				table.insert(variants, `{variant.Id} {byVariant[variant.Id]}`)
			end
		end
		table.insert(lines, "  variants: " .. table.concat(variants, ", "))
		return true, table.concat(lines, "\n"), nil
	end,
}

COMMANDS.stands = {
	Usage = "stands",
	Description = "List your stands: card, income/s and uncollected earnings.",
	Run = function(ctx)
		local data = ctx.data
		local lines = { `{Economy.displaySlotCount(data)} stands unlocked:` }
		for slot = 1, Economy.displaySlotCount(data) do
			local key = tostring(slot)
			local id = data.Display[key]
			local instance = if id then data.Cards[id] else nil
			local name = if instance then `{instance.CardId} ({instance.Variant}) [{id}]` else "empty"
			table.insert(
				lines,
				`  #{slot}: {name}  +{Format.short(IncomeLedger.standIncome(data, key), 1e6)}/s  pending {Format.short(
					IncomeLedger.pending(data, key),
					1e6
				)}`
			)
		end
		return true, table.concat(lines, "\n"), nil
	end,
}

COMMANDS.income = {
	Usage = "income",
	Description = "Income diagnostics: total/s, uncollected total, offline timestamp and caps.",
	Run = function(ctx)
		local data = ctx.data
		local settings = Config.Economy.Income
		local last = data.Income.LastOnline
		return true,
			table.concat({
				`income {Format.short(Economy.totalIncome(data), 1e6)}/s, uncollected {Format.short(
					IncomeLedger.pendingTotal(data),
					1e6
				)}`,
				`LastOnline {if last > 0 then Format.duration(ctx.now - last) .. " ago" else "never"}`,
				`stand cap {Format.duration(settings.StandCapSeconds)}, offline cap {Format.duration(
					settings.OfflineCapSeconds
				)} at rate {settings.OfflineRate}`,
			}, "\n"),
			nil
	end,
}

COMMANDS.data = {
	Usage = "data",
	Description = "Profile summary (schema, counts, flags, stats).",
	Run = function(ctx)
		local data = ctx.data
		local packs = 0
		for _, count in data.Packs do
			packs += count
		end
		local discovered = 0
		for _ in data.Discovered do
			discovered += 1
		end
		return true,
			table.concat({
				`schema v{data.SchemaVersion}, level {data.Progression.Level}, cash {Format.commas(
					data.Currency.Cash or 0
				)}`,
				`cards {Inventory.count(data)}/{Economy.backpackCapacity(data)}, unopened packs {packs}, discovered {discovered}/{CardRegistry.count()}`,
				`starter granted {tostring(data.Flags.StarterGranted)}, packs opened {data.Stats.PacksOpened or 0}, joins {data.Stats.Joins or 0}`,
			}, "\n"),
			nil
	end,
}

COMMANDS.reset = {
	Usage = "reset",
	Description = "Replace your profile with defaults (Studio testing of a new player). Saved on the next save.",
	Run = function(ctx)
		local fresh = ProfileSchema.defaults() :: any
		local data = ctx.data :: any
		for key in data do
			data[key] = nil
		end
		for key, value in fresh do
			data[key] = value
		end
		local changed = {}
		for key in fresh do
			table.insert(changed, key)
		end
		table.sort(changed)
		return true, "profile reset to defaults (rejoin to receive the starter grant again)", changed
	end,
}

DevCommands.COMMANDS = COMMANDS

-- Names that DevService handles itself because they need live services (plots, saving).
DevCommands.SERVICE_COMMANDS = {
	plots = "plots - list plot ownership on this server",
	save = "save - save your profile now",
	home = "home - teleport to your plot",
} :: { [string]: string }

function DevCommands.help(): string
	local names = {}
	for name in COMMANDS do
		table.insert(names, name)
	end
	table.sort(names)
	local lines = { "Developer commands (Studio only):" }
	for _, name in names do
		table.insert(lines, `  {COMMANDS[name].Usage} - {COMMANDS[name].Description}`)
	end
	for _, text in DevCommands.SERVICE_COMMANDS do
		table.insert(lines, "  " .. text)
	end
	return table.concat(lines, "\n")
end

-- Runs a parsed command against the context. Unknown names fail safely.
function DevCommands.run(ctx: Context, name: string, args: { string }): (boolean, string, { string }?)
	if name == "help" then
		return true, DevCommands.help(), nil
	end
	local command = COMMANDS[name]
	if not command then
		return false, `unknown command "{name}" (try help)`, nil
	end
	return command.Run(ctx, args)
end

return DevCommands
