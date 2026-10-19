# Implementation status

Last updated: 2026-10-19 (specification review after Phase 2).

Legend: ✅ implemented and covered by automated tests · 🟡 implemented, needs a Studio play
test · ⬜ not started.

None of this has been play-tested in Roblox Studio yet. Studio cannot run in the cloud
environment. See [TESTING.md](TESTING.md) for the manual checklist.

## Phase 2: Core gameplay loop

| Area | Status | Where |
| --- | --- | --- |
| Buy and open packs: server-side rolls, unlock and capacity checks, XP and level-ups with a Treats reward | ✅ logic / 🟡 live | `Logic/PackShop.luau`, `Services/PackService.luau` |
| Card reveal overlay (staggered pop-in, NEW! badges, "1 IN X" odds) | 🟡 | `Controllers/PacksController.luau` |
| Pack shop window (quantity ×1–10, found count, chase-card odds, lock reasons) | 🟡 | `PacksController` |
| Display stands: place, move, remove, Place Best, sanitize | ✅ logic / 🟡 UI | `Logic/Display.luau`, `Services/CardService.luau`, `DisplayController` |
| Passive income every second from stands (upgrade and collection multipliers) | ✅ maths / 🟡 live | `Logic/Economy.luau`, `Services/EconomyService.luau` |
| Backpack window (grid, sort by recent, rarity or best; capacity; detail panel with stand, favourite and sell actions) | 🟡 | `BackpackController` |
| Selling: all-or-nothing, protects favourite and displayed cards; favourites | ✅ logic / 🟡 UI | `Logic/Market.luau`, `CardService` |
| Upgrades window and purchases (stands, income, luck, sell bonus, backpack space) | ✅ logic / 🟡 UI | `Logic/UpgradeShop.luau`, `UpgradeService`, `UpgradesController` |
| Binder window (collection progress, discovered and unknown cards, completion bonus) | 🟡 | `BinderController` |
| Starter cards placed on stands automatically | ✅ | `Logic/Account.luau` |
| Economy pacing simulation | ✅ tool | `scripts/simulate.luau` |

### Not in Phase 2

- **Physical plot:** there are no 3D display stands or world stations yet. Stands exist
  only in the UI.
- **Grading service and UI:** not built. The rules and config are ready.
- **Pack stock and restock timers:** not built.
- **Boosts, quests, daily rewards, offline earnings:** not built.
- **Monetization purchase handling:** not built.
- **Sound and music:** none yet.
- **Final card and pack artwork:** placeholder tiles for now.

## Phase 1: Foundation

| Area | Status | Where |
| --- | --- | --- |
| Configuration (game, economy, rarities, variants, collections, cards, packs, grading, upgrades, monetization) | ✅ | `src/shared/Config/` |
| Config cross-reference validation (tests + server startup warnings) | ✅ | `Logic/ConfigCheck.luau` |
| Card registry: 36 original cards in 6 collections, with lookups | ✅ | `Config/Cards.luau`, `Logic/CardRegistry.luau` |
| Unique card instance ids (`<userId>-<serial>`) | ✅ | `Logic/Inventory.luau` |
| Player data schema v1, defaults, reconcile, versioned migrations | ✅ | `Data/ProfileSchema.luau` |
| Session-locked persistence (retries, lock expiry, lost-lock detection, never resetting data on failure) | ✅ logic / 🟡 live | `server/Lib/SessionStore.luau` |
| DataService (join/leave, autosave, BindToClose, Studio mock store, leaderstats) | 🟡 | `server/Services/DataService.luau` |
| Starter rewards granted once (flag + session lock) | ✅ logic / 🟡 live | `Logic/Account.luau` |
| Remotes with rate limiting and argument validation | ✅ validators and limiter / 🟡 wiring | `server/Lib/Net.luau`, `Util/Validate.luau`, `Util/RateLimiter.luau` |
| Replication (snapshot, full-key changes, map patches) | 🟡 | `DataService`, `client/Controllers/DataController.luau` |
| Settings (validated, persisted, Settings window) | ✅ logic / 🟡 UI | `SettingsService`, `SettingsController` |
| HUD (cash, treats, income/s, level bar, navigation, notifications) | 🟡 | `client/Controllers/HUDController.luau`, `NotificationController.luau` |
| Pure rules for economy, progression, collections, pack rolls and grading | ✅ | `src/shared/Logic/` |

### Prepared but not yet used by gameplay

These fields exist in the saved schema and/or config so that later phases need no
migration. No gameplay uses them yet:

- **Quests:** `Quests`.
- **Daily rewards:** `DailyRewards`.
- **Collection reward claims:** `Collections.Claimed`.
- **Purchase receipts:** `Purchases.Receipts`.
- **Monetization IDs:** all set to `0`, meaning disabled.
- **Grading:** the rules and config are tested, but there is no grading service or UI.
- **Volume settings:** stored, but the game has no audio yet.

## Assumption register

**The master specification has not been recovered** (see [SPEC.md](SPEC.md)). As a
result:

- **No assumption below is "confirmed by the original specification".** That category is
  currently empty.
- Requirements that come from the owner's phase briefs (R-x.y in SPEC.md) are not
  assumptions, so they are not listed here.
- Every entry is a design choice made by development, filling a gap.

Classifications:

- **Decision:** a reasonable implementation decision. A technical or UX choice that any
  specification would most likely accept, or that follows directly from a brief
  requirement.
- **Unresolved:** an unresolved design decision. A game-design choice that only the owner or
  the specification can settle. It works today, but may change.
- **Deviation:** a deviation from the intended design. Available evidence (the reference
  design direction, R-1.6.2) points to a different design. The reference shows another
  game, so these deviations are provisional and are listed for an owner decision.

"Migration" means what a change would require of saved player data (schema v1). See
[Migration notes](#migration-notes).

### Concept and scope

| # | Current behaviour | Evidence | Class | Where | Migration if changed |
| --- | --- | --- | --- | --- | --- |
| A1 | Core loop: buy packs, get cards, put cards on stands for income, upgrade, collect sets | Proposed by development (R-2.1 had no scope); consistent with the reference | Unresolved | whole game | Depends on change |
| A2 | Display stands exist only as a UI window; no physical plot or 3D stands | The reference shows a physical plot with stands in the world (shots 01, 14), and the brief calls the game a "tycoon" | **Deviation** (temporary; a physical plot was the proposed Phase 3) | `DisplayController`, `Logic/Display` | None: `Display` slots can drive 3D stands |
| A3 | No trading, gifting or leaderboards (except a Cash leaderstat) | No source | Unresolved | — | None (instance ids are already globally unique) |
| A4 | Game name "Ferret Card Tycoon"; ferret theme | R-0.1 | (requirement) | — | — |

### Cards and collections

| # | Current behaviour | Evidence | Class | Where | Migration if changed |
| --- | --- | --- | --- | --- | --- |
| A5 | 36 original cards in 6 collections of 6 (Backyard Burrow, Snack Attack, Knight Patrol, Sandy Shores, Cosmic Scampers, Midnight Mischief); all names and descriptions invented | R-1.2 asks for ≥30 original cards; the content is invented | Unresolved | `Config/Cards`, `Config/Collections` | Adding cards: none. Renaming display names: none. **Removing or renaming card ids: required** (remap owned instances and `Discovered`) |
| A6 | "Species" = ferret colour morphs (Sable, Albino, Champagne, …, plus Polecat); cosmetic only, no gameplay effect | R-1.2 requires the field; its meaning is undefined | Unresolved | `Config/Cards.Species` | None (not stored in player data) |
| A7 | 7 rarities: Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret | Partly matches the reference (Common to Epic visible); the tiers above Epic are invented | Unresolved | `Config/Rarities` | None (rarity is per definition, not stored per instance) |
| A8 | 5 variants that multiply income and sale value: Normal ×1, Shiny ×1.5, Gold ×3, Holo ×6, Rainbow ×12; drop weights 1000/60/15/4/1 | R-1.2 requires variants. The reference shows Gold, Holo and Rainbow tags (shot 16) and a "Shiny" boost; all multipliers and weights are invented | Unresolved | `Config/Variants` | Changing multipliers or weights: none. **Removing or renaming a variant id: required** (remap `Cards[*].Variant` and `Discovered[*].Variants`) |
| A9 | Unlock requirements on 3 cards (level 10, level 14, level 16 plus Backyard Burrow complete); locked cards cannot drop | R-1.2 requires the field; which cards are gated is invented | Unresolved | `Config/Cards` | None |
| A10 | Completing a collection gives a permanent global income bonus (+5% to +15%) | The reference shows binder bonuses as **luck** (shot 11); ours are **income** | Unresolved (differs from the reference) | `Config/Collections`, `Logic/Collections` | None (derived from `Discovered`) |
| A11 | Artwork: an empty asset id shows a placeholder tile (rarity gradient plus species initials) | R-1.2 asks for configurable placeholders | Decision | `UI/CardTile` | None |
| A12 | Card ids are permanent; retired cards stay defined but are removed from packs | Required for data safety (R-1.4) | Decision | `Config/Cards` header | — |

### Packs

| # | Current behaviour | Evidence | Class | Where | Migration if changed |
| --- | --- | --- | --- | --- | --- |
| A13 | **Packs open immediately on purchase**; there is no unopened-pack inventory | The reference shows packs as backpack items ("Packs" filter, "No packs yet", "Tap or swipe to open", shots 06, 08 and 10) | **Deviation** | `Logic/PackShop`, `PacksController` | Additive: a new `Packs` map in the schema; `reconcile` adds it automatically (bump the version only if existing data needs transforming) |
| A14 | 3 cards per pack | The reference reveal shows 5 cards (shot 07) | Unresolved (differs from the reference) | `Config/Packs.CardsPerOpen` | None |
| A15 | 6 packs, one per collection; rarity weights per pack | Invented | Unresolved | `Config/Packs` | None |
| A16 | Pack prices 750 / 20K / 125K / 1M / 15M / 200M Cash (about 15 minutes of per-card income), gated by level 1/3/5/8/11/14 | Tuned with `scripts/simulate.luau`; no design target exists | Unresolved | `Config/Packs` | None |
| A17 | No stock limits or restock timers | The reference shows stock counts and a restock countdown (shot 04) | Unresolved (differs from the reference) | — | Additive if added |
| A18 | Odds shown as "1 IN X" per card and as a "chase" card in the shop | The reference shows "1 IN X" (shots 01, 05, 07) | Decision | `PackRoller.odds`, `PacksController` | None |
| A19 | Up to 10 packs per purchase | Invented (abuse limit) | Decision | `Config/Game.Limits` | None |

### Economy and progression

| # | Current behaviour | Evidence | Class | Where | Migration if changed |
| --- | --- | --- | --- | --- | --- |
| A20 | Two currencies: **Cash** (main) and **Treats** (secondary) | R-1.6.1 mentions "relevant currency values". The reference has a second currency ("Kibble"); the name "Treats" is invented | Unresolved | `Config/Economy.Currencies` | **Renaming Treats: required** (move the `Currency.Treats` balance to the new key) |
| A21 | **Treats are earned (5 per level) but nothing spends them** | Gap: no sink is designed | Unresolved (**needs a decision**) | `PackShop`, `Config/Economy` | None until a sink exists |
| A22 | Starter bundle: 1,500 Cash plus two Common Backyard Burrow cards, placed on stands automatically; granted once | R-1.4 requires duplicate protection; the contents are invented | Unresolved (contents) / Decision (mechanism) | `Config/Economy`, `Logic/Account` | Changing contents: none for existing players (`Flags.StarterGranted` is already set) |
| A23 | Income comes only from displayed cards: Σ(base × variant × grade) × (1 + income upgrade + collection bonuses), every 1 s; no offline or AFK income | The reference shows "Cash/s" and a "2x AFK time" pass (shot 18), implying AFK income | Unresolved | `Logic/Economy`, `EconomyService` | Offline income: additive (needs a `LastIncomeAt` field) |
| A24 | Base sale value = 15 × base income; sold value includes variant, grade and the sell upgrade | Invented | Unresolved | `Config/Cards`, `Logic/Economy` | None |
| A25 | Selling is all-or-nothing; favourite and displayed cards cannot be sold | Protects players; no source | Decision | `Logic/Market` | None |
| A26 | Player level and XP: XP per pack (5–65), XP to next level = 60·L^1.6, max level 100; levels gate packs and reward Treats | The reference shows "LV 4" (shot 01); everything else is invented | Unresolved | `Config/Economy.Progression`, `Config/Packs.Xp` | None (but changing the curve changes existing players' effective progress) |
| A27 | 4 base stands, plus up to 8 from upgrades; backpack holds 300 base, plus up to 500 | The reference shows a "45/425" backpack (shot 08); the numbers are invented | Unresolved | `Config/Game`, `Config/Upgrades` | **Lowering capacity: required decision** for players already above it (they keep their cards but can't add more) |
| A28 | 5 upgrades: Display Stands, Cosy Hammocks (+10% income), Lucky Paw (+5% luck), Haggler (+8% sale), Bigger Backpack (+50); cost = base × growth^level | R-1.1 requires upgrade config; the list is invented | Unresolved | `Config/Upgrades` | **Removing or renaming an upgrade id: required** (refund or remap `Upgrades[id]`) |
| A29 | Luck multiplies the weights of luck-affected rarities and variants by (1 + luck) | Invented model | Unresolved | `Logic/PackRoller` | None |
| A30 | "Place Best" fills stands with the highest-income cards | The reference has a "PLACE BEST" button (shot 01) | Decision | `Logic/Display` | None |

### Grading, quests, daily rewards, monetization (config only)

| # | Current behaviour | Evidence | Class | Where | Migration if changed |
| --- | --- | --- | --- | --- | --- |
| A31 | Grading: four sub-grades (Corners, Centering, Surface, Edges), each 1–10; grade = floor(average); multipliers ×0.8 (grade 1) to ×3 (grade 10); cost = 50 + 0.5 × sale value. No service or UI | R-1.1 requires grading config. The sub-grade names follow the reference (shot 02); the formula and multipliers are invented | Unresolved | `Config/Grading`, `Logic/Grading` | None yet: no card has been graded, and `Grade` is nil for every instance |
| A32 | Quests and daily rewards: reserved empty fields only | R-1.3 requires the fields; the design is missing | Unresolved | `ProfileSchema` | Restructuring the reserved fields: none while they're empty |
| A33 | Monetization placeholders: VIP (+25% income), 2× Income, Triple Open, two Treats bundles; all `Id = 0` (disabled) | R-1.1 requires placeholders; the product ideas are partly from the reference (shots 17–18) | Unresolved | `Config/Monetization` | None while disabled |

### Technical and UX decisions

| # | Current behaviour | Evidence | Class | Where |
| --- | --- | --- | --- | --- |
| A34 | Card instance id `<userId>-<serial>` from a persistent per-player counter | Satisfies R-1.2 | Decision | `Logic/Inventory` |
| A35 | Session lock with a 10-minute expiry, autosave every 90 s, retries with backoff, kick on failed load, newer-schema data refused | Satisfies R-1.4 | Decision | `Config/Game.Data`, `Lib/SessionStore` |
| A36 | In-memory mock store in Studio when API access is off (warns loudly) | Testing convenience | Decision | `DataService` |
| A37 | Per-remote token-bucket rate limits; strict argument validators | Satisfies R-1.5 | Decision | `Config/Game.RateLimits`, `Lib/Net` |
| A38 | Settings: music volume, SFX volume, notifications, reduced motion | R-1.3 requires settings; the list is invented, and there's no audio yet | Unresolved (list) | `ProfileSchema.SETTINGS` |
| A39 | UI style: FredokaOne font, outlined white text, pill buttons, dark panels, left stats, top-centre actions, right rail, bottom-right toasts | R-1.6.2 (reference direction) | Decision | `UI/Theme`, `HUDController` |
| A40 | HUD labels and navigation set (BUY PACKS, MY STANDS, BAG, BINDER, UPGRADES, SETTINGS); no Shop button and no goal panel | The reference rail has Shop and More buttons, and a goal panel top-left (shots 01, 03, 13) | Unresolved | `HUDController` |

### Summary

| Classification | Count | Items |
| --- | --- | --- |
| Confirmed by the original specification | **0** | (specification not recovered) |
| Reasonable implementation decision | 12 | A11, A12, A18, A19, A25, A30, A34–A37, A39, and A22's grant-once mechanism |
| Unresolved design decision | 26 | A1, A3, A5–A10, A14–A17, A20–A24, A26–A29, A31–A33, A38, A40 |
| Deviation from the intended design (per the reference direction) | 2 | A2 (UI-only stands), A13 (packs open immediately) |

## Configuration values versus the original design

Without the specification, **no configuration value can be checked against the original
design**, so no value changes are recommended at this time. Changing numbers to match
unknown targets would be inventing requirements.

These are recommended once the specification is available, in this order:

1. **A21 (Treats have no use):** decide what Treats buy, or remove them. This is the only
   current design gap that affects players: they collect a currency they can't spend.
2. **A13 and A2 (deviations):** confirm whether packs should be stored and opened later,
   and whether stands should be physical. Both are architecturally ready (see migration
   notes).
3. **A16 and A26 (pacing):** set target times, then re-tune with
   `lune run scripts/simulate`.
4. **A5, A8, A20 and A28 (ids):** confirm card, variant, currency and upgrade ids
   **before the first public release**. Renaming any of them afterwards needs a data
   migration.

## Migration notes

**Current schema:** version 1 (`ProfileSchema.VERSION = 1`). No migration is required now:
this review changed no gameplay code, config or schema.

If the specification changes things, the impact on saved data is:

| Change | Migration needed? | How |
| --- | --- | --- |
| Add a new field (pack inventory, offline income timestamp, boosts, quest structure) | No version bump required | `ProfileSchema.reconcile` fills new fields from the defaults on load. Add the field to `defaults()` |
| Add cards, collections, packs, upgrades or variants | No | Config only |
| Change numbers (prices, weights, multipliers, curves) | No | Config only. Existing balances and levels are kept, so check fairness |
| **Rename or remove a card id** | **Yes** | Bump `VERSION`; `MIGRATIONS[1]` remaps `Cards[*].CardId` and the `Discovered` keys (or converts removed cards to Cash at sale value) |
| **Rename or remove a variant id** | **Yes** | Remap `Cards[*].Variant` and `Discovered[*].Variants` |
| **Rename the Treats currency** | **Yes** | Move `Currency.Treats` to the new key |
| **Remove or rename an upgrade** | **Yes** | Remap `Upgrades[id]`, or refund the cumulative cost in Cash |
| Lower the backpack capacity or the stand count | Policy decision | Keep the existing cards. `Display.sanitize` already drops stands beyond the new count on load |
| Change the instance id format | **Avoid** | Ids are referenced by `Display`. A change needs a full remap |

Migration rules (also in `ProfileSchema`):

- Migrations run on a copy.
- A failure rejects the load: the player is kicked, and their data is never reset.
- Every migration gets a unit test in `tests/unit/ProfileSchema.spec.luau`.
