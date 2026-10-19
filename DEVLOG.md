# Development log

Newest entries first. Each entry records what changed, how it was verified, and where that
verification ran (CI, cloud, or a local Studio session).

## 2026-10-19: Card income audit (artwork = source of truth)

**Artwork vs config:** the printed "+N/s" was re-read from each Pack 1 image: Sandy 70,
Boba 118, Sky 420, Kingston 750, Aurora 1,200, Frost 1,500. `Config/Cards.luau` already
matched all six, so no values changed. No artwork exists for Shiny or any other variant, so
the printed value is the Normal (base) income. The older placeholder sets (Burrow etc.) have
no artwork and were left unchanged. Each card also shows four paw icons with three filled;
no rule maps them to data, so they were not interpreted.

**Formulas audited (no change needed):**
- One formula, in `Logic/Economy`: card income = BaseIncome × variant × grade.
  - Stand income = card income × (1 + IncomeBoost + completed-collection bonuses) × server
    extra (`EconomyService:ExtraMultiplier`, currently 1).
  - CASH/S (`Economy.totalIncome`) = the sum of the stand incomes.
- The variant multiplier is applied exactly once. Every caller (HUD, Display window,
  backpack, reveal, stands, DevCommands, server accrual) uses `Economy`/`IncomeLedger`;
  nothing recomputes income.
- Per-stand accrual, the 2 h stand cap, single-stand collect and Collect All all use
  `IncomeLedger.standIncome`. Collect All pays the same as collecting each stand.

**Display fix:**
- **Problem:** the 3D stand illustration showed the printed base income even for a
  variant copy. A Shiny Sandy floated with "+70/s" while earning 105/s, and the placeholder
  card also printed BaseIncome.
- **Fix:** `PlotView`/`PlotService` now publish each stand's `CardIncome` attribute, from
  `Economy.cardIncome` on the server. The stand shows an income tag when it differs from the
  printed value (as inventory tiles already did), and the placeholder prints it. The client
  only displays the number and never recomputes it.

**Tests:** new `tests/unit/CardIncome.spec.luau` (12 tests):
- the printed incomes match `BaseIncome`;
- Shiny and every other variant are applied once (Sandy Shiny = 105, not 157.5);
- grade stacks once on top of the variant;
- the stand `CardIncome` matches `Economy.cardIncome`;
- CASH/S = the sum of printed incomes × the Pack 1 completion bonus, and = the sum of
  stand incomes with variants and upgrades; locked and empty stands count nothing;
- per-stand accrual, Collect All (pays the sum once), stand-by-stand collection = Collect
  All, and the cap at variant income.

`SKIP_SELENE_IF_OFFLINE=1 ./scripts/check.sh`: all checks passed, 197 tests. Not verified in
Studio.

## 2026-10-19: Fix `install-tools.sh` on macOS (Apple Silicon)

**Problem:** the installer always downloaded the Linux x86-64 builds. On an Apple Silicon Mac,
`~/.local/bin/stylua` and `selene` were therefore Linux ELF files, and `./scripts/check.sh`
failed with "cannot execute binary file".

**Fix (tool versions unchanged):**
- `scripts/install-tools.sh` now detects the platform (macOS arm64/x86_64, Linux
  x86_64/arm64). A shell running under Rosetta on Apple Silicon still gets arm64 tools.
- Each tool's release file for each platform was checked against the pinned release.
  Exceptions:
  - Selene 0.27.1 has one build per OS: `linux` = x86_64 and `macos` = arm64 only.
  - luau-lsp's macOS build is universal.
  - Rojo 7.4.4 and Selene have no Linux arm64 build, and Selene has none for Intel Macs.
    Those are built with `cargo install --locked` when Rust is installed; otherwise the
    script says so.
- **Before installing,** each binary must be a native executable for this platform (`file`;
  a magic-byte check when `file` is missing) and run `--version` with the pinned version.
  Otherwise it is refused. Existing wrong-platform binaries are detected and replaced.
- Other tools still install when one fails, and the script exits non-zero naming the
  failures. `--dry-run` prints the URLs for the platform; `TOOLS_OS`/`TOOLS_ARCH`
  override detection in that mode only.
- The script stays compatible with macOS's bash 3.2.
- `scripts/check.sh` first checks that every tool is on PATH and runs on this machine. If
  one doesn't, it names the tool and its binary type and points to the installer.
- `rokit.toml` now also pins luau-lsp 1.70.1, so `rokit install` covers every tool
  `check.sh` needs.

**Verified (Linux x86_64 cloud container; no Mac was available):**
- Every URL from `--dry-run` resolves (HTTP 200) for all four platforms.
- The downloaded macOS arm64 builds of all five tools are Mach-O arm64 (luau-lsp is
  universal). The macOS x86_64 builds of Rojo, StyLua and Lune are Mach-O x86_64.
- Planted wrong-platform binaries (macOS arm64 `stylua`, Linux arm64 `selene`) were detected
  and replaced; a second run reports everything already installed.
- A deliberately wrong download (the macOS StyLua build on Linux) was refused; the other
  tools installed and the exit code was 1.
- `check.sh` names a broken tool and stops.
- `SKIP_SELENE_IF_OFFLINE=1 ./scripts/check.sh` on this container: all checks passed,
  179 tests.
- **Not run on macOS:** the installer and `check.sh` still need a run on the owner's Mac.

## 2026-10-19: Phase A1–A3: developer tools, 3D world, physical plots, Pack 1 art

**Input**
- The owner uploaded the Pack 1 art (`Pack 1/`: six cards and `obal.png`, the pack front).

**Art (`assets/README.md`)**
- **Inspection** (all seven files are 1024×1536 PNG, RGBA):
  - The transparency is real, with no baked checkerboard.
  - The card images are complete printed cards: frame, rarity, name, subtitle, printed
    income and number.
  - Five of them have the card body at alpha 251–253 (about 1% see-through).
  - The pack logo reads "FERRET FRENZY" (owner question Q15).
- **Originals** moved byte-identical to `assets/source/Pack 1/`.
- **Processed copies:** `scripts/assets/process_card_art.py` writes them to
  `assets/processed/pack1/` (683×1024; alpha ≥ 250 snapped to opaque; corner check), about
  1 MB each.
- **Mapping:** `Config/Assets` is the single artwork mapping (`AssetId = 0` until uploaded),
  resolved by `Logic/CardArt` with a placeholder fallback.
- **Cards:** six new definitions, `pack1_sandy` … `pack1_frost`, numbered #001–#006 and
  matching the printed rarity, income and subtitle.
- **Pack 1 economics:**
  - Pack 1 (pack front `obal.png`) is now the first and starter pack.
  - Sale value is set to 2× income, and the price to $1,500, so it can't be resold at a
    profit.
  - A new config test enforces that rule for every pack (it replaced the "sorted by price"
    test).
- **Art not on Roblox yet:** the cloud environment cannot upload assets to Roblox, so the
  exact manual upload steps are documented.

**A1 developer tools (`docs/DEVTOOLS.md`)**
- Pure `server/Lib/DevCommands`: a fixed command table with parsed, range-checked
  arguments and no code execution. Commands: cash, setcash, packs, card, allcards, level,
  accrue, offline, roll (distribution vs configured odds, without granting), stands,
  income, data, reset.
- `DevService` handles plots, save and home. It creates the `DevCommand` remote **only in
  Studio**, so it doesn't exist on live servers.
- `DevController` adds a DEV panel. `DataService` gained `KeyChanged`, `SaveNow` and
  `Diagnostics`; `Net` gained optional remotes.

**A2 world**
- `Config/World` (layout) and `Config/Visuals` (palette, illustration settings, rarity
  effects).
- `server/World/WorldBuilder` builds:
  - ground;
  - a spawn plaza with a fountain and a "FERRET CARD TYCOON" monument;
  - the avenue and paths;
  - the Pack Shop, Upgrades and Collect All stations, and a reserved Grader;
  - lamps and trees;
  - Atmosphere and colour correction.
- It removes the Baseplate template.

**A3 plots and stands**
- **Pure modules** (all tested): `Logic/PlotAllocator` (automatic, unique ownership, release,
  full capacity), `Logic/PlotLayout` (8 plots, 12 stands each) and `Logic/PlotView` (stand
  state from saved data).
- **`PlotService`:**
  - Assigns plots only after a safe data load.
  - Shows owner signs and spawns players on their own plot.
  - Adds the MY PLOT teleport (`TeleportHome` remote).
  - Mirrors `Display` onto the stand attributes, with locked-stand visuals.
  - Handles a full server with a toast.
- **Client:**
  - `StandVisualsController`: floating art or placeholder, aspect ratio kept, shared float
    loop, rarity effects near the camera, cleanup.
  - `PlotController`: Place/Change card, Collect $X and Inspect prompts, plus "$X" labels.
  - `WorldController`: station prompts.
  - Backpack: a "PICK FOR STAND #N" mode.
  - `CardTile` and the pack shop show the uploaded art when an asset id exists.

**Integration with existing systems:** no new income formula. Stands use `IncomeLedger` and
`CollectEarnings`, and placement uses `PlaceCard`. No schema change was needed: the physical
stands mirror the saved `Display` map.

**Verified (cloud container)**
- `SKIP_SELENE_IF_OFFLINE=1 ./scripts/check.sh`: StyLua, Selene (offline std), Rojo build
  and luau-lsp strict (0 errors) all pass.
- Lune: **179 passed, 0 failed**. New test files: `DevCommands.spec` (11), `Plots.spec`
  (14), `CardArt.spec` (7), plus new place-structure entries.
- `scripts/simulate.luau`: the Pack 1 starter gives about 1,580/s at once, and every pack
  unlocks within about 1 h. **The economy needs A8** (Q14).

**Not verified**
- **No Roblox Studio session has been run.** The world's look and feel, the prompts, the
  billboards and effects, plot assignment with real players, and persistence of the
  arrangement in a real DataStore are all untested at runtime. The checklist is in
  TESTING.md 1.8–1.12.
- **The art isn't uploaded yet**, so everything in game shows placeholders until the asset
  ids are filled in.

## 2026-10-19: Owner decisions Q1–Q4 applied (start of Phase A)

**Decisions** (owner, in Czech; recorded in `docs/STATUS.md`):

| # | Decision |
| --- | --- |
| Q1 | Packs go to the inventory; the player opens them when they want |
| Q2 | Five cards per pack |
| Q3 | Both: each stand accumulates money, and the player can also collect centrally |
| Q4 | On joining, the player automatically gets their own free plot (binding for roadmap A3; no plots exist yet) |

**Changed**
- **Packs (C1):**
  - `PackShop.buy` now puts packs in a new `Packs` inventory.
  - New `PackShop.open` and `OpenPack` remote; opening checks ownership and backpack space
    before any change.
  - `PackShop.grant` adds packs for rewards.
  - `CardsPerOpen = 5` for every pack.
- **Starter (C5):** $500 (spec §32) plus 3 Burrow Packs, granted once. The starter cards and
  their auto-placement were removed. The welcome toast points to PACKS.
- **Stand earnings (C4):** new pure `Logic/IncomeLedger`.
  - Each occupied stand accumulates its effective income, capped at 2 h of that income.
  - `CollectEarnings(slot)` collects one stand; slot 0 collects every stand.
  - Whole cash is paid out; the fraction stays on the stand. Earnings belong to the stand,
    so they survive a card swap.
  - `EconomyService` no longer credits Cash directly.
- **Offline earnings (§10):**
  - `Income.LastOnline` is updated every tick, so a crash never double-counts.
  - On load, offline time is capped at 2 h (×`OfflineRate` 1) and credited onto the stands,
    with a toast that mentions the cap.
- **Schema:** new fields `Packs` and `Income { LastOnline, Pending }`. They are additive, so
  `reconcile` fills them into existing v1 profiles (test added). No version bump.
- **Client:**
  - Packs rows show BUY (greys out when unaffordable or locked: C15) and OPEN (n).
  - The HUD has a central COLLECT $X button.
  - My Stands has per-stand COLLECT buttons, updated in place, plus COLLECT ALL.
- **`scripts/simulate.luau`** follows the new flow (open starter packs, buy then open,
  collect every 10 s). Pacing with 5 cards per pack:
  - Snack Pack unlocks at about 13 minutes, Knight at about 40 and Midnight at about 1h33.
  - It is faster than before; the rebalance to the §32 rarity bands is still roadmap A8.
- **Interim values (config, not from the spec):** 3 starter packs; 2 h stand cap; 2 h
  offline cap; offline rate 1.

**Verified (cloud container)**
- `SKIP_SELENE_IF_OFFLINE=1 ./scripts/check.sh`: StyLua, Selene (offline std), Rojo build
  and luau-lsp all pass. Lune **131 passed, 0 failed**: 13 new IncomeLedger tests and 8 new
  pack inventory and opening tests; the starter, config and migration tests were updated.
- STATUS summary is now: ✅ 58 · 🟡 14 · 🟠 37 · ⬜ 58 · ❌ 11.

**Not verified**
- No Roblox Studio session has been run: the new UI, remotes, offline toast and persistence
  of `Packs` and `Income` are untested at runtime. The checklist is in TESTING.md 1.3, 1.4
  and 1.6.

## 2026-10-19: Audit against the recovered specification

**Input:** the owner committed the original master specification to `docs/SPEC.md`
(commit `60c0cc8`, 36 sections, 2,081 lines). It is now the source of truth, replacing the
earlier "spec not recovered" document and the assumption register.

**Changed**
- **`docs/STATUS.md`:** rewritten as a requirement-by-requirement audit (178 rows, §1–§33).
  The results:

  | Classification | Rows |
  | --- | --- |
  | ✅ Implemented and tested | 52 |
  | 🟡 Implemented, not verified in Studio | 12 |
  | 🟠 Partially implemented | 37 |
  | ⬜ Not implemented | 61 |
  | ❌ Conflicts with the specification | 16 |

  The file also covers:
  - **16 conflicts (C1–C16)**, each with a recommended change and its migration impact.
    The main ones: UI-only stands instead of physical plots; income auto-credited instead
    of collected; no offline earnings; no pack inventory or starter packs; the instant
    reveal instead of the §7.5 sequence; grading by sub-grades instead of a per-grade
    probability table; income scaled by collection tier instead of §32's rarity bands; a
    full-rebuild backpack.
  - **13 documented ambiguities (Q1–Q13)**, left undecided.
  - **Config differences** against §11 and §32.
  - **The data migration plan:** schema v1 stays as it is; everything is additive except
    the optional Treats and SellBonus removals, which are to be batched into one v2
    migration.
  - **The fate of the old assumptions** A1–A40.
- **`docs/ROADMAP.md`** (new): Gate 0 (owner answers and a first Studio smoke test), then
  Phases A–F following the spec's dependency order. **The recommended next phase is
  A:** physical plots, stands, in-world 2D ferret illustrations, collectable and offline
  income, pack inventory and the opening sequence, and rebalancing to §32.
- **`docs/TESTING.md`:** a practical Studio checklist. Part 1 covers what exists today,
  including client command-bar exploit probes. Part 2 is pre-written for each spec feature
  on the roadmap.
- **Bug fix found during the audit:** `Validate.instanceId` rejected the negative UserIds
  that Studio gives local players under *Test → Clients and Servers*. In multiplayer Studio
  tests, every place, remove, sell and favourite request would have failed. The pattern is
  now `^%-?%d+%-%d+$`. A regression test was added, and mutation-checked: it fails without
  the fix.
- No other code, config or schema changes. Working systems were left as they are; the
  conflicts are scheduled in the roadmap.

**Verified (cloud container)**
- `SKIP_SELENE_IF_OFFLINE=1 ./scripts/check.sh`: StyLua, Selene (offline std), Rojo build
  and luau-lsp all pass; Lune **114 passed, 0 failed**.

**Not verified**
- No Roblox Studio session has been run.

## 2026-10-19: Specification review (no features added)

**Searched for the master specification.** Not found in:
- any repository branch;
- GitHub issues or PRs (there are none);
- the container's filesystem;
- the development conversation.

The local path `~/Downloads/Ferret frenzy/` is not reachable from the cloud. **The
specification has not been recovered.**

**Changed (documentation only; no code, config or schema changes)**
- `docs/SPEC.md` now says explicitly that the specification is missing. It records the
  requirements actually given in the phase briefs (R-0.x, R-1.x, R-2.1), notes that the
  Phase 2 scope was proposed by development, and lists 30 missing requirements as
  questions for the owner.
- `docs/STATUS.md` replaces the nine-item assumption list with a full register of 40
  entries, A1–A40, taken from the code and config:
  - **0** confirmed by the specification;
  - **12** reasonable implementation decisions;
  - **26** unresolved design decisions;
  - **2** provisional deviations from the reference direction: A2 (UI-only stands) and A13
    (packs open immediately instead of being stored).
- New finding (A21): Treats are earned but nothing spends them.
- **Config:** no values were changed, because there is no original design to compare
  against. The register lists recommended next steps and the migration impact of each
  possible change. Schema v1 needs no migration.

**Verified (cloud container)**
- `SKIP_SELENE_IF_OFFLINE=1 ./scripts/check.sh`: all steps pass, 113 tests, 0 failures.

## 2026-10-19: Phase 2: core gameplay loop

**Changed**
- **Pure transactions:**
  - `Logic/PackShop` (buy and open packs, with unlock, amount, capacity and cash checks
    before any change; luck; odds; XP, level-ups and Treats).
  - `Logic/Display` (place, move, remove, Place Best, sanitize).
  - `Logic/Market` (all-or-nothing selling that protects favourite and displayed cards;
    favourites).
  - `Logic/UpgradeShop`.
- **Services:** `PackService` (server-side `Random`), `CardService`, `UpgradeService` and
  `EconomyService` (income every second). Seven new validated remotes, plus a rate limit
  for `PlaceBest`.
- **Client:**
  - `CardTile` (rarity-coloured placeholder art, variant, NEW!, FAV, ON STAND and count
    tags) and `Lib/Request` (shows error toasts and drops double-clicks).
  - Windows: Packs with a reveal overlay, Backpack, My Stands, Upgrades and Binder. Every
    HUD navigation button now opens a working window.
- **Starter cards** are placed on stands automatically, so income starts at once.
- **Balance:**
  - `scripts/simulate.luau` showed the first prices were far too low: every pack unlocked
    within 12 minutes, and the simulated player was buying a pack every second.
  - Pack prices were raised to about 15 minutes of per-card income
    (750 / 20K / 125K / 1M / 15M / 200M), starting cash went to 1,500, and the XP curve
    was slowed (60·L^1.6).
  - Simulated unlocks are now Snack at 18 minutes, Knight at 57, Shore at 1h22, Cosmic at
    1h49 and Midnight at 2h11.

**Verified (cloud container)**
- StyLua ✅. Rojo build ✅. luau-lsp strict, 0 errors ✅. Selene with the offline
  approximation ✅.
- Lune: **113 passed, 0 failed** ✅. That includes 22 new gameplay tests: purchases change
  nothing when rejected, capacity, locked cards never drop, level-ups, stand placement and
  moves, Place Best ordering, sanitize, all-or-nothing selling, and upgrade cost and max.
- **CI:** the Phase 1 run on GitHub Actions passed with the full Roblox-std Selene and 91
  tests. The Phase 0 run had failed because of the `install-tools.sh` bug fixed in Phase 1.

**Not verified**
- **No Roblox Studio play test has been run.** The UI layout and feel, remote round trips,
  live income ticks and persistence of Phase 2 data are all untested at runtime. The
  checklist is in docs/TESTING.md ("Core loop").

**Next (proposed Phase 3)**
- A physical tycoon plot: a per-player plot with 3D display stands that show the placed
  cards, and world stations (Packs, Sell, Upgrades).
- Grading service and UI, and the "goal" quest panel.
- First local Studio play test, then UI fixes based on it.

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
