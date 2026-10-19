# Developer tools (Studio only)

These tools test the game in Roblox Studio without grinding. They implement spec §31's
development-only test mode and roadmap item A1.

## Safety model

| Rule | How it's enforced |
| --- | --- |
| Never available to ordinary players | `DevService` creates the `DevCommand` remote **only when `RunService:IsStudio()`**. On live servers the remote doesn't exist, so there's nothing to call. `Config.Game.Dev.EnabledInStudio = false` also switches the tools off in Studio |
| No arbitrary code execution | A command line is parsed into a name and plain tokens, and looked up in a fixed table (`server/Lib/DevCommands.luau`). Nothing is ever evaluated as code. Tokens may only contain letters, digits and `_ . -` |
| Validated arguments | Every number is range-checked; pack, card and variant ids must exist in Config |
| Server-authoritative | Commands run on the server, on the **calling player's own data only**, through the same rules the game uses (Wallet, Inventory, PackShop, IncomeLedger, PackRoller). Changes replicate like any other change |
| Rate-limited | `Config.Game.RateLimits.DevCommand` |

`tests/unit/DevCommands.spec.luau` covers parsing, unknown commands, range checks and every
command.

## Using the tools

1. Press Play in Studio. The Output shows
   `[Dev] Developer commands enabled (Studio only)`.
2. Click the pink **DEV** button (bottom-left) to open the panel. Use the quick buttons, or
   type a command and press Enter. The result appears in the panel and in the Output
   window (`[Dev] Name> command`).

| Command | What it does |
| --- | --- |
| `help` | Lists every command |
| `cash <amount>` / `setcash <amount>` | Adds Cash / sets it exactly (up to 1e15) |
| `packs <packId> [count]` | Adds unopened packs, for example `packs pack1 5` |
| `card <cardId> [variant] [count]` | Creates test cards, for example `card pack1_frost Gold 2`. Ignores backpack capacity |
| `allcards` | One Normal copy of every card definition |
| `level <n>` | Sets the player level (unlocks packs) |
| `accrue <seconds>` | Fast-forwards stand earnings (respects the 2 h stand cap) |
| `offline <seconds>` | Pretends you were offline that long and applies offline earnings now (shows the cap) |
| `roll <packId> [cards]` | Rolls N cards **without granting them** and compares rarity results with the configured odds |
| `stands` | Each stand: card, instance id, income/s, uncollected earnings |
| `income` | Total income/s, uncollected total, last-online age, caps |
| `data` | Profile summary: schema version, counts, starter flag, stats |
| `plots` | Plot ownership on this server and cards displayed per plot |
| `save` | Saves your profile now; says whether the in-memory mock store is active |
| `home` | Teleports you to your plot |
| `reset` | Replaces your profile with defaults (rejoin for the starter grant). With real DataStores this overwrites your test profile on the next save |

**Typical checks:**
- `roll pack1 20000` to check drop rates.
- `card pack1_aurora`, place it on a stand, then watch its effects.
- `accrue 600` then collect, to test collection.
- `offline 9000` to check the 2 h offline cap.
- `plots` with two test players to check plot ownership.
