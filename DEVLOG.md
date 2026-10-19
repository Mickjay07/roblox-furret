# Development log

Newest entries first. Each entry records what changed, how it was verified, and where that
verification ran (CI, cloud, or a local Studio session).

## 2026-10-19: Phase 1: foundation

**Inputs**
- 18 reference screenshots arrived on `main`. They were merged in and moved to
  `docs/reference-screenshots/`, with a duplicate (12 = 11) removed. Their design direction
  is documented in that folder's README.
- `docs/SPEC.md` was still empty. The design assumptions are listed in
  [docs/STATUS.md](docs/STATUS.md).

**Changed**
- **Config:**
  - Modules: Game, Economy, Rarities, Variants, Collections, Cards (36 original ferret
    cards in 6 collections), Packs (6), Grading, Upgrades (5) and Monetization
    placeholders.
  - `Logic/ConfigCheck` validates the config's cross-references.
- **Pure rules (`src/shared/Logic`):** card registry, economy (income, sale value, upgrade
  effects and costs), progression (XP and unlocks), collections, pack rolling (rarity, then
  card, then variant, with luck, unlock filtering and odds), grading, wallet, inventory
  (unique instance ids) and account (starter grant, joins, settings).
- **Player data:** schema v1 with defaults, versioned migrations and reconcile.
- **Persistence:** `server/Lib/SessionStore` provides session locking, retries with
  backoff, lock expiry and takeover, lost-lock detection, and never falls back to defaults
  on failure. `DataService` handles join, leave, autosave, BindToClose, the Studio mock
  store, leaderstats and replication.
- **Networking:** `server/Lib/Net` creates the remotes and adds per-player rate limits,
  argument validation and error isolation. `SettingsService` implements a validated
  `UpdateSetting`.
- **Client:**
  - Infrastructure: a remote helper, UI theme, components and window manager, viewport
    scaling, and a DataController that mirrors replicated data.
  - Notifications: toasts.
  - HUD: cash, treats, cash/s, level bar, top navigation and right rail.
  - Settings window.
- **Tooling:**
  - Upgraded luau-lsp from 1.32.1 to 1.70.1. Version 1.32.1 reported false errors on
    valid early-return narrowing.
  - Fixed `install-tools.sh`: its `install` helper shadowed the system `install` command,
    so any fresh install, including CI's, would have failed.
  - Added an offline Selene fallback and a Lune `tests/Loader.luau` that runs
    Roblox-style modules under Lune.

**Verified (cloud container)**
- StyLua ✅. Rojo build ✅. luau-lsp 1.70.1 strict type check, 0 errors ✅.
- Lune: **91 passed, 0 failed** ✅. This covers config validity, rolls and odds, economy,
  progression, schema migration and reconcile, inventory and account, utilities, grading,
  SessionStore safety rules, and the built-place structure.
- Mutation checks: breaking the save lock check, the starter-grant flag or the load lock
  check each made the tests fail.
- Selene with the offline approximation ✅. The full Roblox std runs in CI only.
- The tests found and fixed two real bugs:
  - `SessionStore.withKey` dropped multiple return values, so failed loads lost their
    reason.
  - The install-script bug above.

**Not verified**
- **No Roblox Studio play test has been run.** DataStore behaviour against the real
  service, remotes, the HUD and the Settings window are untested at runtime. The checklist
  is in docs/TESTING.md.

**Open items**
- Spec document still missing.
- Run the Studio checklist locally.

## 2026-10-19: Phase 0: inspection and project setup

**Changed**
- Inspected the repository: both the local clone and the GitHub remote were empty. The game
  specification and the reference screenshots were not available. See
  [docs/PHASE0_REPORT.md](docs/PHASE0_REPORT.md).
- Set up the Rojo project structure, the server and client bootstraps (Init/Start
  lifecycle), and the shared Config, Remotes and `Util/WeightedRandom` modules.
- Added tool pins, format, lint and type-check configs, `scripts/install-tools.sh`,
  `scripts/check.sh`, the Lune test harness, GitHub Actions CI and a SessionStart hook for
  cloud sessions.
- Wrote the README, ARCHITECTURE, TESTING and SPEC placeholder documents.

**Verified (cloud container)**
- StyLua ✅, Rojo build ✅, luau-lsp strict type check ✅, Lune tests 12/12 ✅.
- Selene ⚠️ skipped: the Roblox API dump host is blocked by the cloud network. It will run
  in CI.

**Not verified**
- Any Roblox Studio play test. Studio is not available in the cloud environment.

**Open items**
- Spec document missing (`docs/SPEC.md`).
- Reference screenshots missing (`docs/reference-screenshots/`).
- First local Studio smoke test still to be run (checklist in docs/TESTING.md).
