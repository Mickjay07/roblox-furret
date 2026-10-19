# Architecture

## Principles

1. **The server is authoritative.** Currency, cards, rolls, upgrades and income are only
   ever calculated and changed on the server. Clients send *intents* made of identifiers and
   quantities (for example "buy 3 of pack X"). The server validates every one of them and
   never accepts prices, rolls or rewards from a client.
2. **Data-driven design.** Every gameplay number lives in `src/shared/Config/`. Code never
   hard-codes balance values.
3. **Pure rules, thin Roblox glue.** Rules that can be written without the Roblox API sit
   in pure modules (`src/shared/Logic`, `src/server/Lib/SessionStore.luau`) and are
   unit-tested under Lune. Services and controllers connect those rules to Roblox APIs.
4. **No third-party runtime dependencies.** There are no frameworks and no Wally packages.
   Persistence uses an in-house session store so its safety rules are fully testable.

## Runtime layout

```
ReplicatedStorage.Shared          (src/shared)  - required by server and client
  Config/                         all tunable data (see below)
  Types                           shared type definitions
  Remotes                         names of every remote
  Data/ProfileSchema              saved-data defaults, migrations, reconcile
  Logic/                          pure game rules
    CardRegistry, Economy, Progression, Collections, PackRoller, Grading,
    Wallet, Inventory, Account, ConfigCheck,
    PackShop, Display, Market, UpgradeShop,    (gameplay transactions)
    IncomeLedger                               (stand earnings, collection, offline)
  Util/                           WeightedRandom, Validate, RateLimiter, Signal, Format

ServerScriptService.Server        (src/server)
  init.server                     bootstrap: config check, then Init/Start of Services
  Lib/
    SessionStore                  session-locked DataStore profiles (pure, tested)
    MockDataStore                 in-memory store (Studio without API access, tests)
    Net                           remote creation, validation, rate limiting
  Services/
    DataService                   load/save lifecycle, replication, leaderstats
    SettingsService               UpdateSetting
    PackService                   BuyPack (to pack inventory), OpenPack (server-side Random)
    CardService                   PlaceCard, RemoveCard, PlaceBest, SellCards, SetFavorite
    UpgradeService                BuyUpgrade
    EconomyService                stand earnings tick, CollectEarnings, offline earnings

StarterPlayerScripts.Client       (src/client)
  init.client                     bootstrap: Init/Start of Controllers
  Lib/Remotes, Lib/Request        safe invoke / event helpers; Request toasts errors and
                                  drops duplicate in-flight requests (double-clicks)
  UI/                             Theme, Create, Components, Windows, CardTile
  Controllers/
    DataController                client mirror of the player's data
    NotificationController        toasts
    HUDController                 HUD and navigation
    SettingsController            Settings window
    PacksController               pack shop + reveal overlay
    BackpackController            backpack grid + card actions
    DisplayController             "My Stands"
    UpgradesController            upgrades
    BinderController              collections
```

### Gameplay transaction pattern

Every request follows the same steps:

1. `Net` validates the argument types and the rate limit.
2. The service fetches the live data with `DataService:GetData`.
3. The service calls a pure transaction (`PackShop.buy`, `Display.place`, `Market.sell`,
   `UpgradeShop.buy`, …). The transaction **checks everything before changing anything**,
   then returns `(true, result)` or `(false, message for the player)`.
4. The service replicates exactly what changed: `Changed` for whole fields, `Patched` for
   map entries.

Because the transactions are pure, the Lune tests exercise the same code the server runs.

### Service / controller lifecycle

A module returns a table with optional `Init` and `Start` methods. The bootstrap requires
every module, then calls each `Init` (synchronous; must not yield or call other services),
and then each `Start` (each in its own thread). A failing module is logged and does not stop
the others. Register remote handlers in `Start`. `Net` creates the remotes lazily.

## Configuration (`src/shared/Config`)

| Module | Contents |
| --- | --- |
| `Game` | DataStore settings (store name, autosave, lock expiry, retries), per-remote rate limits, request limits, display and backpack base sizes |
| `Economy` | Currencies, starting currency, starter cards, income tick, sale multiplier, XP curve |
| `Rarities` | Common → Secret: order, colour, whether luck applies |
| `Variants` | Normal, Shiny, Gold, Holo, Rainbow: multipliers and drop weights |
| `Collections` | 6 collections with completion income bonuses |
| `Cards` | 36 card definitions (id, name, description, species, rarity, income, sale value, artwork, collection and number, optional variants and unlock requirement) |
| `Packs` | 6 packs: price, cards per open, collections, rarity weights, XP, unlock requirement |
| `Grading` | Sub-grades, roll weights, labels, grade multipliers, cost formula |
| `Upgrades` | Display stands, income boost, luck, sell bonus, backpack space |
| `Monetization` | Game pass and developer product placeholders (`Id = 0` means disabled) |

`Logic/ConfigCheck` checks every cross-reference: unknown rarities, collections and
variants, unreachable cards, starter cards that don't exist, and so on. The tests require a
clean result, and the server logs any problem at startup.

**Card ids are permanent.** They are stored in player data, so never rename or reuse one.

## Player data (`Data/ProfileSchema`, version 1)

| Field | Purpose |
| --- | --- |
| `Currency` | `{ Cash, Treats }` |
| `Cards` | `instanceId -> { CardId, Variant, Grade?, Obtained, Favorite }` |
| `NextCardSerial` | Per-player counter for unique instance ids `<userId>-<serial>` |
| `Discovered` | `cardId -> { First, Count, Variants }` (collection progress derives from this) |
| `Display` | `slot ("1", "2", …) -> instanceId` |
| `Upgrades` | `upgradeId -> level` |
| `Collections.Claimed` | Reserved for collection reward claims |
| `Quests`, `DailyRewards` | Reserved for later phases |
| `Settings` | Music/SFX volume, notifications, reduced motion (validated by `SETTINGS`) |
| `Progression` | `{ Level, Xp }` |
| `Stats` | Packs opened, cards obtained or sold, cash earned or spent, play time, joins |
| `Flags.StarterGranted` | Starter-reward guard |
| `Purchases.Receipts` | Reserved for de-duplicating developer product receipts |

Maps use string keys so they save as dictionaries.

**Schema changes:** bump `ProfileSchema.VERSION` and add `MIGRATIONS[old]`. Migrations run
on a copy, and a failure rejects the load. `reconcile` fills in new fields from the
defaults without touching existing values.

## Persistence (`Lib/SessionStore` + `Services/DataService`)

Each DataStore record has the shape
`{ Data, Meta = { LockJobId, LockTime, SavedAt, SaveCount } }`.

**Loading:** the load is one `UpdateAsync` call:

- **No record:** create defaults and take the lock.
- **Locked by another live server:** abort without writing, wait, then retry.
  `ContestedLockRetries × ContestedLockDelay` covers fast rejoins.
- **Lock expired** (`LockExpirySeconds`, 10 minutes, with no save): take it over.
- **Data from a newer schema, a failed migration, or a malformed record:** reject it and
  leave it untouched.
- **DataStore errors:** retry with exponential backoff. If every attempt fails, the
  **player is kicked** and default data is never used.

**Saving:**

- **Every save checks the lock inside `UpdateAsync`.** A server that lost the lock gets
  nothing written, and the player is kicked ("opened on another server").
- **Autosave:** every 90 seconds, with saves staggered across players.
- **Leaving:** the final save also releases the lock.
- **Shutdown:** `BindToClose` releases every profile and waits up to 25 seconds for pending
  saves.
- **Per-key operations are serialized,** so an autosave and a release never interleave.

**Starter rewards:** `Account.grantStarter` checks and sets `Flags.StarterGranted`, which is
saved in the same profile. Combined with the session lock, the reward can't be granted
twice.

**Studio:** if the DataStore probe fails in Studio (API access disabled), the game uses
`MockDataStore`. It warns loudly and shows a toast, and nothing is saved. Live servers never
use the mock store.

## Networking (`Lib/Net`, `Shared/Remotes`)

- Remote names are declared once, in `Shared/Remotes`.
- The server creates them under `ReplicatedStorage.Remotes`.
- `Net.onInvoke(name, checkers, handler)` adds three layers:
  1. **Rate limiting:** a token bucket per player per remote (`Config.Game.RateLimits`).
  2. **Validation:** argument count and type checks (`Util/Validate`: ids, integers with
     range checks, NaN and infinity rejected, strict arrays).
  3. **Error isolation:** a handler error is logged and the client receives a generic
     failure.
- Handlers return `{ ok = true, ... }` or `{ ok = false, error = "..." }`.

Requests (client to server): `GetSnapshot`, `UpdateSetting(key, value)`,
`BuyPack(packId, amount 1-10)` (into the pack inventory), `OpenPack(packId, amount 1-10)`,
`CollectEarnings(slot 0-100)` (0 = every stand), `PlaceCard(instanceId, slot 0-100)`,
`RemoveCard(instanceId)`, `PlaceBest()`, `SellCards({instanceId} up to 50)`,
`SetFavorite(instanceId, bool)` and `BuyUpgrade(upgradeId)`. Instance ids must match
`^%-?%d+%-%d+$` (Studio test players have negative UserIds), and pack and upgrade ids must exist in Config.
- Handlers must also check game rules: ownership, affordability, unlocks and capacity.

**Replication:**

- `DataChanged(key, value)` sends a whole field.
- `DataPatched(key, set, remove)` sends changed entries of map fields such as `Cards`.
- `DataChanged("__snapshot", data)` sends the full snapshot after load. The client also
  requests it through `GetSnapshot`, in case it connected late.

## Client UI

The HUD and windows are built in code (`UI/Create`, `UI/Components`) using the theme taken
from the reference screenshots (`docs/reference-screenshots/README.md`). Layouts are
authored for a 1280×760 viewport and scaled to the screen with `Components.autoScale`.
`UI/Windows` is a single-window modal manager: features register a window, and HUD
navigation opens it. Unregistered features show "Coming soon!".

## World geometry

Rojo is a poor fit for hand-built 3D layouts. The plan is to export plot templates from
Studio as `.rbxm` files to `assets/models/` and map them in `default.project.json`, or to
generate simple geometry in code. This will be decided in the phase that builds the
physical plot.
