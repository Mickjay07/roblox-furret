# Implementation status

Last updated: 2026-10-19 (Phase 1).

Legend: ✅ implemented and covered by automated tests · 🟡 implemented, needs a Studio play
test · ⬜ not started.

None of this has been play-tested in Roblox Studio yet. Studio cannot run in the cloud
environment. See [TESTING.md](TESTING.md) for the manual checklist.

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

## Design assumptions (pending the specification)

`docs/SPEC.md` is still empty, so these choices were made from the phase briefs and the
reference screenshots. Every value is in `src/shared/Config/`.

1. **Currencies:**
   - Cash is the main currency.
   - Treats are a secondary currency, earned as a level-up reward.
2. **Starter bundle:** 100 Cash plus two Common Backyard Burrow cards.
3. **Packs open immediately on purchase.** There is no unopened-pack inventory. Each pack
   gives 3 cards.
4. **Prices:** each pack costs roughly 60 seconds of its expected income per card.
5. **Variants multiply income and sale value:** Normal ×1, Shiny ×1.5, Gold ×3, Holo ×6,
   Rainbow ×12.
6. **Grades:**
   - A card's grade is the floor of its four sub-grades' average.
   - Grade multipliers run from ×0.8 (grade 1) to ×3 (grade 10).
7. **Collections:** completing one gives a permanent global income bonus (5–15%).
8. **Card instance ids:** `<userId>-<serial>`. They are globally unique, which leaves room
   for trading later.
9. **Card ids are permanent.** Retiring a card means removing it from packs, never deleting
   its definition.
