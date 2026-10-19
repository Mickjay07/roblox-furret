# Implementation status: audit against the specification

Last updated: 2026-10-19 (Phase A1–A3: dev tools, world, physical plots, Pack 1 art).

The audit compares the code on branch `claude/ferret-card-tycoon-setup-8vqo00` against the
recovered master specification ([SPEC.md](SPEC.md), 36 sections, 2,081 lines, commit
`60c0cc8`).

**The specification is the source of truth.** Where earlier phase briefs, assumptions or
implementation decisions disagree with it, the specification wins, and the disagreement is
listed under [Conflicts](#conflicts-with-the-specification).

**Nothing has been play-tested in Roblox Studio.** Studio cannot run in the cloud
environment. "Tested" in this document always means automated tests (Lune unit tests, the
type check and the place-structure check), never a Studio session. See
[TESTING.md](TESTING.md).

The prioritised plan that follows from this audit is in [ROADMAP.md](ROADMAP.md).

## Legend

| Mark | Classification | Meaning |
| --- | --- | --- |
| ✅ | Implemented and tested | The rule is implemented, and automated tests cover it. Runtime behaviour in Studio is still unverified |
| 🟡 | Implemented, not verified in Studio | Code exists but has no automated test (wiring, UI, live services) |
| 🟠 | Partially implemented | Some of the requirement exists; the gaps are listed |
| ⬜ | Not implemented | Nothing exists yet (config placeholders or reserved fields don't count) |
| ❌ | Conflicts with the specification | The current behaviour contradicts the specification and must change |

## Summary

| Spec area | ✅ | 🟡 | 🟠 | ⬜ | ❌ |
| --- | --- | --- | --- | --- | --- |
| §1–3 Concept, identity, core loop | 3 | 4 | 1 | 1 | 0 |
| §4 Card system | 5 | 0 | 1 | 3 | 0 |
| §5 Artwork | 2 | 1 | 1 | 1 | 0 |
| §6 Rarity and drop tables | 7 | 0 | 2 | 3 | 1 |
| §7 Pack shop and opening | 6 | 2 | 5 | 3 | 1 |
| §8 Plots and stands | 2 | 5 | 0 | 1 | 0 |
| §9 2D ferrets in the world | 0 | 7 | 0 | 0 | 0 |
| §10 Income and offline earnings | 7 | 1 | 3 | 1 | 0 |
| §11 Grader | 1 | 0 | 1 | 4 | 1 |
| §12 Variants | 2 | 0 | 2 | 1 | 0 |
| §13 Binders | 1 | 1 | 3 | 2 | 0 |
| §14 Backpack | 0 | 3 | 3 | 2 | 1 |
| §15 Upgrades | 3 | 0 | 2 | 0 | 1 |
| §16 Boosts | 0 | 0 | 0 | 2 | 0 |
| §17 Daily rewards and quests | 0 | 0 | 0 | 2 | 0 |
| §18 World and hub | 0 | 1 | 2 | 0 | 0 |
| §19 Selling | 3 | 1 | 2 | 1 | 0 |
| §20 Trading | 0 | 0 | 0 | 1 | 0 |
| §21 Leaderboards and achievements | 0 | 0 | 1 | 1 | 0 |
| §22 Events | 0 | 0 | 0 | 1 | 0 |
| §23 Robux monetization | 1 | 0 | 0 | 4 | 1 |
| §24–25 UI and audio | 1 | 1 | 3 | 2 | 1 |
| §26–29 Architecture, security, persistence, performance | 8 | 3 | 3 | 2 | 1 |
| §30–33 Process, testing, balancing, deliverables | 9 | 0 | 3 | 1 | 2 |
| **Total** | **61** | **30** | **38** | **39** | **10** |

**In short:**

- **Strong:** the foundation. Data-driven config, the card registry, server authority,
  validated remotes, session-locked persistence, the centralised income formula and the
  upgrade cost formula.
- **New (Phase A1–A3):** a generated 3D world, auto-assigned physical plots with 12 stands
  each, floating ferret card illustrations with rarity effects, stand and central
  collection in the world, Studio-only developer tools, and the Pack 1 artwork mapping.
  Almost all of it is still 🟡, because **nothing has run in Roblox Studio yet**.
- **Missing:**
  - The §7.5 opening sequence.
  - The rebalance (Q14).
  - The Grader Station.
  - Boosts, quests, daily rewards, the store and trading.
- **Art:** Pack 1 isn't uploaded to Roblox yet (manual step in `assets/README.md`).
- **Conflicts:** 10 remain; C1, C3, C4 and C5 are resolved.

---

## §1–3 Concept, visual identity, core loop

| Req | Requirement (spec) | Status | Evidence / gap |
| --- | --- | --- | --- |
| §1 | All player-facing text in English; consistent English naming | ✅ | All strings and identifiers are in English |
| §2 | Ferrets, original content, nothing copied from the reference game | 🟡 | 36 original ferret cards. Screenshots used for layout only (`docs/reference-screenshots/README.md`) |
| §2 | Reusable design system: palette, typography, buttons, card frames, rarity colours, modals, **tooltips**, notifications, progress bars, currency displays, **loading states**, hover/selection | 🟠 | `UI/Theme`, `UI/Components`, `UI/CardTile`, `UI/Windows`. No tooltips, no loading states |
| §3.1–2 | Join, then **claim a personal plot** | 🟡 | A free plot is assigned automatically once data has loaded safely (decision Q4; `PlotService`, `Logic/PlotAllocator`; tests: `Plots.spec`). The player spawns on their plot. Not verified in Studio |
| §3.3 | Starter currency **and starter card packs** | ✅ | $500 plus 3 Burrow Packs in the pack inventory, granted once (`Account.grantStarter`, `Config.Economy.StarterPacks`). Tests: `Inventory.spec`, `SessionStore.spec`. The pack count is an interim value |
| §3.4–6 | Open packs, discover cards, place on stands | 🟡 | Packs open into 5 cards; cards go on **physical stands** through stand prompts or My Stands (same validated `PlaceCard`). Not verified in Studio |
| §3.7 | Spawn the illustrated ferrets in the world | 🟡 | `StandVisualsController` floats the card art above every occupied stand on every plot. It shows a placeholder until images are uploaded (assets/README.md). Not verified in Studio |
| §3.8–9 | Earn passive income, **then collect accumulated earnings** | ✅ | Stands accumulate earnings; the player collects per stand or all at once (`Logic/IncomeLedger`, `CollectEarnings`). Tests: `IncomeLedger.spec`. Collection works from the UI; collecting at a physical stand comes with A4 |
| §3 | Guided, resumable tutorial | ⬜ | No tutorial, and no tutorial field in saved data |

## §4 Card system

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §4.1 | Separate definition id and unique per-copy id | ✅ | `CardId` plus instance id `<userId>-<serial>`. Tests: `Inventory.spec` |
| §4.2 | Data-driven definitions in a centralised registry | ✅ | `Config/Cards`, `Logic/CardRegistry`. Tests: `CardRegistry.spec`, `Config.spec` |
| §4.3 | Definition fields: CardId, DisplayName, Description, Species, Rarity, BaseIncomePerSecond, BaseSellValue, ArtworkAssetId, CollectionId, UnlockRequirements, VariantDefinitions | ✅ | Present under our names: `Id`, `Name`, `BaseIncome`, `BaseSaleValue`, `Artwork`, `Collection`, `Unlock`, `Variants` |
| §4.3 | Definition fields **PackPool, DisplayModel/display config, IsLimited, AvailableGrades, Tags** | ⬜ | Missing. The pack pool is derived from the collection |
| §4.4 | Instance fields: UniqueInstanceId, CardId, Variant, Grade, Favorite, acquisition time | ✅ | `Types.CardInstance` |
| §4.4 | Instance "is displayed" and display slot | ✅ | Derived from `Display` (slot → instance). This prevents double-display by construction. Tests: `Gameplay.spec` |
| §4.4 | Optional serial number for special collectibles | ⬜ | Field not present (it can be added without a migration) |
| §4.5 | Inventory: view all, details, favourite, select, select for display, variant info, sell eligible, inspect | 🟠 | Present in `BackpackController`, but not verified in Studio |
| §4.5 | Inventory: **search by name, filter by rarity, sort by grade, duplicate quantities, select for grading** | ⬜ | Missing. Sorting is by recent, rarity or income only. Each copy gets its own tile, with no grouping |

## §5 Ferret artwork and card design

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §5.1 | At least 30 original card definitions | ✅ | 36. Test: `Config.spec` |
| §5.2 | Distinct artwork per character; don't use the same image for every card | 🟠 | Pack 1's six cards have their own uploaded art (`Config/Assets`; test: `CardArt.spec`). It isn't on Roblox yet: the asset ids must be uploaded manually. The 36 placeholder cards have no art |
| §5.3 | Don't pretend final art exists; artwork references are configurable | ✅ | `Config/Assets` is the single mapping (`AssetId = 0` until uploaded); `Logic/CardArt` falls back to a placeholder. Tests: `CardArt.spec` |
| §5.4 | Rarity labels, readable income, optional flavour text on cards | 🟡 | `CardTile` shows the name, rarity and income/s. The description appears in the backpack detail |
| §5.5 | Special visual treatments for rare variants | ⬜ | A text tag only |

## §6 Rarity system and drop tables

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §6.1 | Seven tiers: Common to Secret | ✅ | `Config/Rarities` matches exactly |
| §6.2 | Configurable colours, as suggested | ✅ | Matches the suggestions (grey, green, blue, purple, gold, magenta-red, dark) |
| §6.3 | Per-rarity border and background | 🟠 | Tile colour and gradient by rarity. No distinct borders |
| §6.4 | Per-rarity opening-animation intensity, sound, particles, "collection value" | ⬜ | None |
| §6.5 | Drop tables per pack, not scattered | ✅ | `Config/Packs.RarityWeights`. Tests: `PackRoller.spec` |
| §6.6 | Validate probabilities; handle missing definitions safely | ✅ | `Logic/ConfigCheck` (tests plus server startup) |
| §6.7 | Weighted random; variants; deterministic seed for tests | ✅ | `WeightedRandom`, `PackRoller` (injected `roll`). Tests |
| §6.8 | Limited pools, special events, guaranteed rewards | ⬜ | Not supported |
| §6.9 | Log acquisition events for debugging | ⬜ | Not logged |
| §6.10 | Secret cards obtainable (never impossible by misconfiguration) | 🟠 | ConfigCheck verifies every card can be reached from some pack. It doesn't check that a non-zero probability survives unlock gating |
| §6.11 | Developer tools to test pack probabilities | ✅ | Studio-only `roll <pack> <n>` compares rolled rarities with the configured odds (`Lib/DevCommands`; tests). `scripts/simulate.luau` for pacing |
| §6.12 | Rewards generated and validated on the server only | ✅ | `PackService` with server `Random`. The client only receives the results |
| §6/§32 | Income determined by rarity (§32 bands) | ❌ | Income scales by **collection tier** (×1 to ×12,000), not by rarity band. See C10 |

## §7 Pack shop and opening

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §7.1 | Dedicated shop; buy with in-game currency | 🟡 | `PacksController` plus `BuyPack` |
| §7.2 | Pack fields: name, description, price, currency, card pool, rarity probabilities | ✅ | `Config/Packs`. Tests |
| §7.2 | Pack fields: artwork, pity/guarantee, stock/availability, limited-time window | ⬜ | Missing |
| §7.3 | Buy one or many; quantity selection | ✅ | 1–10 per request. Tests: `Gameplay.spec` |
| §7.3 | Inventory capacity validation | ✅ | `PackShop.buy`. Test |
| §7.3 | Affordability indicators | 🟡 | Buy buttons grey out when unaffordable or locked (`PacksController`) |
| §7.3 | Success / insufficient-currency notifications | 🟠 | The reveal screen, plus an error toast via `Request`. Neither is verified in Studio |
| §7.3 | Purchase confirmation where appropriate | ⬜ | None |
| §7.3 | Restock timers, limited-time packs, event packs | ⬜ | None |
| §7.3 | Pack previews, possible rewards, reward odds | 🟠 | The shop row shows the found count and **one** chase card's odds. There is no full card list or odds table |
| §7.4 | Never charge if the purchase can't complete | ✅ | All checks run before `Wallet.spend`. Test: "rejects … without changes" |
| §7.4 | Never grant twice for a repeated request | 🟠 | Client drops concurrent duplicates (`Lib/Request`), plus a server rate limit. No server-side transaction id (C16) |
| §7.5 | Opening sequence: pack centred, blur, pack animation, open with particles and sound, card flip, rarity effects, name and income reveal | ❌ | Packs open instantly into a pop-in grid of finished cards. No pack object, blur, flip, particles or sound. See C2 |
| §7.5 | Open several packs in succession; clean results screen | 🟠 | The multi-pack results grid exists; there is no one-by-one sequence |
| §7.5 | Option to reduce or skip repeated animations | 🟠 | The Reduced Motion setting skips pop-in tweens. There's no dedicated skip option |
| §7.5 | Reward granted by the server before the client shows the result | ✅ | Results come from the `BuyPack` response |
| §3/§7 | Owned, unopened packs (starter packs; packs as rewards in §13 and §17) | ✅ | Pack inventory `Packs`; `BuyPack` adds packs, `OpenPack` opens them (5 cards each, decision Q2); `PackShop.grant` for rewards. Tests: `Gameplay.spec` |

## §8 Personal plots and display stands

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §8.1 | Physical personal plot in a shared world | 🟡 | 8 plots along an avenue in the generated world (`WorldBuilder.buildPlot`, `Config/World`; layout tests in `Plots.spec`) |
| §8.2 | Unique ownership; claim and release; ownership indicators; owned vs unowned distinction | 🟡 | Automatic assignment (Q4), unique, released on leave, full-server message. Owner name on a two-sided entrance sign; free plots grey. Tests: `PlotAllocator` |
| §8.3 | Customisable decoration | ⬜ | Space reserved: a back strip on every plot (`PlotFeatures.DecorationStripU`) |
| §8.4 | Multiple **physical** stands; small initial number; more via progression and upgrades | 🟡 | 12 physical stands per plot; unlocked = 4 base + Display Stands upgrade; locked stands look greyed out (`PlotView`; tests) |
| §8.5 | Approach a stand → interact → select card → place → see it physically → remove/replace → collect income | 🟡 | Stand prompts: Place/Change card (opens the backpack for that stand), Collect $X; the illustration appears above the stand. Removal happens via the backpack. Not verified in Studio |
| §8.6 | The same card can't be on two stands | ✅ | `Display.place` moves the card. Test |
| §8.7 | Server-validated placement; arrangement saved and restored on rejoin | ✅ | `CardService`, saved `Display`, `Display.sanitize` (tests). Rejoin is untested in Studio |
| §8.8 | Visitors can inspect; no modification without permission | 🟡 | Visitors get a read-only Inspect prompt. No remote accepts a plot or stand id, so every action affects only the caller's own plot (design plus `PlotAllocator` ownership tests) |

## §9 2D ferret illustrations in the 3D world (spec: "one of the most important features")

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §9.1 | The ferret illustration appears above or near the stand when a card is placed | 🟡 | BillboardGui above each occupied stand, built client-side from stand attributes (`StandVisualsController`) |
| §9.2 | Faces the viewer, keeps its aspect ratio, transparent background, readable at distance | 🟡 | BillboardGui always faces the camera; size follows the art aspect (`CardArt.aspect`); alpha cleaned for opacity; `MaxDistance` 160 |
| §9.3 | Stays tied to its stand; updates on replace; disappears on removal | 🟡 | Rebuilt on CardId/Variant change; destroyed on clear or stand removal; stand states tested in `Plots.spec` (`PlotView`) |
| §9.4 | Subtle idle animation (float, bounce, sway) | 🟡 | One shared float loop (sinus bob, per-stand phase); off with Reduced Motion |
| §9.5 | Rarity effects: Rare blue particles, Epic purple glow, Legendary gold sparkles, Mythic aura, Secret unique; lightweight and configurable | 🟡 | `Config/Visuals.RarityEffects` matches the spec list (light particle rates; glow lights) |
| §9.6 | Responds to interactions | 🟡 | Owner: Place/Change and Collect prompts; visitors: Inspect |
| §9.7 | World stays clear with many full plots; limit effects at distance | 🟡 | Particles and lights only within 70 studs (checked twice a second); billboards culled beyond 160 studs. Not profiled |

## §10 Passive income and offline earnings

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §10.1 | Displayed cards generate income; base income per second per card | ✅ | `Economy.cardIncome` and `totalIncome`. Tests |
| §10.2 | Centralised formula: Base × Variant × Grade × Upgrade × Boosts (+ Game Pass, events) | 🟠 | One formula in `Logic/Economy` (variant × grade × (1 + upgrade + collection bonus) × `extra`). Boosts, Game Pass and event multipliers are only a hook (`EconomyService:ExtraMultiplier` returns 1) |
| §10.3 | No double-applied multipliers; no income maths in other scripts | ✅ | Client and server both call `Logic/Economy`. Tests |
| §10.4 | Server is the source of truth | ✅ | `EconomyService` on the server |
| §10.5 | Understandable **collection** of earnings: stands accumulate and are collected by interaction, or a central collector | ✅ | Both (decision Q3): per-stand accumulation with a cap, a per-stand COLLECT button, and a central COLLECT in the HUD. Collection pays once; fractions stay on the stand. Tests: `IncomeLedger.spec`. The physical stand prompt comes with A4 |
| §10.6 | Inspect a displayed card: name, rarity, grade, base and effective income, **accumulated earnings**, bonuses | 🟠 | Stands show uncollected earnings (billboard plus Collect prompt); Inspect shows name, rarity, variant and base income. No full panel with bonus breakdown or grade |
| §10.7 | Collection animations and floating currency indicators | 🟠 | A floating "$X" earnings label over own stands. No collection animation yet |
| §10.8 | No negative balances, duplicated payouts or client-awarded currency; every transaction validated; no client elapsed time | ✅ | `Wallet` (tests); server-only income; no client time |
| §10.9 | Avoid frequent DataStore writes | ✅ | Currency is saved only on autosave or leave |
| §10.10 | Offline earnings from the saved timestamp, capped | ✅ | `Income.LastOnline` (server time, updated every tick, so a crash can't double-count); offline time capped at `OfflineCapSeconds` (2 h, interim) and credited onto the stands for collection. Tests: `IncomeLedger.spec` |
| §10.11 | Game Pass extends offline duration (server-side) | ⬜ | — |
| §10.12 | Communicate offline limits to the player | 🟡 | A rejoin toast shows the offline amount, plus the cap when it was reached. Limits aren't shown anywhere else yet |

## §11 Card Grader Station

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §11.1 | Physical Grader Station in the world | ⬜ | — |
| §11.2 | Submit a card and pay a fee; the server randomly assigns grade 1–10 | ⬜ | No `GradingService` or remote. `Grade` exists on instances (always nil) |
| §11.3 | UI: card, current grade, cost, possible grades, **grade probabilities**, income per grade, value, risk info, Roll button, change card, animation | ⬜ | — |
| §11.4 | Configurable **probability table per grade**; per-category rules possible | ❌ | `Config/Grading` instead rolls four sub-grades and averages them (a model taken from the reference screenshots). It has no direct per-grade probability table. See C7 |
| §11.5 | Centralised grade multiplier table | ✅ | `Config/Grading.Multipliers`, `Economy.gradeMultiplier`. Tests |
| §11.6 | Multiplier values (spec suggestion: 0.8, 0.9, 1.0, 1.1, 1.2, 1.4, 1.7, 2.1, 2.7, 3.5) | 🟠 | Ours: 0.8, 0.85, 0.9, 0.95, 1, 1.1, 1.2, 1.5, 2, 3. The spec calls its values suggestions; see [config differences](#configuration-differences) |
| §11.7 | Atomic: affordability, ownership, displayed-card rule, no duplicate charge, result persisted, no free reroll by rejoining | ⬜ | The service doesn't exist. Only the pure helpers (`Logic/Grading` cost and grade) are tested |

## §12 Card variants

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §12.1 | Variants per instance, data-driven, without a definition per combination | ✅ | `Config/Variants` plus `CardInstance.Variant`. Tests |
| §12.2 | Variant list: Normal, Gold, Rainbow, Shiny, Holographic, Crystal, Shadow, Prismatic, Limited Edition | 🟠 | 5 of 9: Normal, Shiny, Gold, Holo(graphic), Rainbow. Missing: Crystal, Shadow, Prismatic, Limited Edition |
| §12.3 | Not every card needs every variant | ✅ | Optional `Variants` list per card. Test |
| §12.4 | Variants affect appearance (gold frame, animated rainbow, holo overlay, …) | ⬜ | A coloured text tag only |
| §12.5 | Add variants without rewriting systems | 🟠 | Config-driven, but visuals will need a variant-treatment table |

## §13 Binders and collection completion

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §13.1 | Binders as lists of required card definitions | ✅ | `Config/Collections` plus the card `Collection` field. Tests: `Progression.spec` |
| §13.2 | UI: name, completion count, discovered and missing cards | 🟡 | `BinderController` (unknown cards show "?") |
| §13.2 | UI: binder artwork, percentage, rewards list | 🟠 | The completion bonus is shown. No artwork, no percentage, no reward list |
| §13.3 | Rewards (cash, packs, variants, decorations, titles, badges, income bonus, display slots) granted **once**, server-validated, persisted | 🟠 | Only a permanent income bonus, derived from `Discovered`, so it can't be double-granted. No claimable rewards (`Collections.Claimed` is reserved). See C6 |
| §13.4 | Global collection interface plus individual binder pages | 🟠 | Overall count plus per-collection tabs |
| §13.5 | Filters: completed, incomplete, recently discovered, rare collections | ⬜ | — |
| §13.6 | Notification when a new card advances a binder | ⬜ | Only the NEW! badge on the reveal screen |

## §14 Backpack

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §14.1 | Grid, previews, rarity, income, variant indicators, favourite, inspection panel | 🟡 | `BackpackController` |
| §14.1 | Search bar, filter controls, card counts, grade indicators | ⬜ | — |
| §14.1 | Sorting controls | 🟠 | Recent, rarity and income. No grade sort |
| §14.2 | Keyboard, mouse and touch | 🟠 | Mouse and touch through buttons. No keyboard shortcuts |
| §14.3 | Responsive at different resolutions | 🟡 | `Components.autoScale` |
| §14.4 | Large collections must not render every card at once (pagination or virtual scrolling) | ❌ | Renders a tile for every owned card, and rebuilds them all on every change. See C11 |
| §14.5 | Distinguish displayed, favourite and sellable | 🟡 | ON STAND and FAV tags; Sell greys out |
| §14.5 | Distinguish gradeable and collection-needed | ⬜ | — |
| §14.6 | Explain why an action is blocked | 🟠 | The server returns a reason, shown as a toast. The UI doesn't explain *before* the attempt |

## §15 Upgrades

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §15.1 | Upgrade fields: id, name, description, level, max level, base cost, scaling, effect per level, validation, UI | ✅ | `Config/Upgrades`, `UpgradeShop`. Tests |
| §15.2 | `NextCost = BaseCost × CostMultiplier ^ CurrentLevel`, centralised and tested | ✅ | `Economy.upgradeCost`. Test |
| §15.3 | Max level enforced; no negative levels; server-validated; persisted | ✅ | Tests: `Gameplay.spec` |
| §15.4 | The 10 initial upgrades | 🟠 | Implemented with spec equivalents: Cash Multiplier (`IncomeBoost`), Card Display Capacity (`DisplaySlots`), Pack Luck (`Luck`), Inventory Capacity (`BackpackSpace`). **Missing:** Plot Capacity, Offline Earnings, Grading Discount, Income Collection Radius, Automatic Collection, Pack Opening Speed |
| §15 | No upgrades outside the specified set | ❌ | Extra `SellBonus` ("Haggler") upgrade, not in the spec's list. See C13 |
| §15.5 | No single upgrade trivialises the game | 🟠 | Pacing was simulated (`scripts/simulate.luau`) against our own targets, not the spec's (§32) |

## §16 Boosts

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §16.1 | Luck, Super Luck, Cash, Shiny, Grading and Speed boosts | ⬜ | Nothing exists. Hooks: the `extra` multiplier in `Economy`, and `luck` in `PackRoller` |
| §16.2 | Duration, effect, source, stacking rules, remaining time; server timing; stop on expiry; persist when appropriate | ⬜ | — |

## §17 Daily rewards and quests

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §17.1 | Daily rewards: configurable sequence, duplicate-claim protection, server timestamps, consistent across time zones | ⬜ | Reserved `DailyRewards { LastClaimDay, Streak }` only |
| §17.2 | Quests: id, description, objective, progress, reward, completion, claim, optional expiry; server-event driven; completion notifications | ⬜ | Reserved `Quests { Active, Completed }` only. There is no claim state in the schema yet |

## §18 Game world and social hub

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §18.1 | Areas: Spawn Plaza, Pack Shop, Grader, Trading Plaza, Upgrade Station, Daily Rewards, Event, Leaderboards, Player Plots, Collection Hall | 🟠 | Built: spawn plaza (monument and fountain), Pack Shop, Upgrade Station, central Collect All booth, reserved Grader, player plots. Not built: Trading Plaza, Daily Rewards, Event, Leaderboards, Collection Hall |
| §18.2 | Navigable without menus; signs; interactive stations | 🟡 | Signs on every station and plot; station prompts open the Pack Shop and Upgrades, or collect all. Avenue and paths |
| §18.3 | Plots show owner, displayed cards, income, decorations, prestige; visitors can inspect; quick return to your own plot | 🟠 | Owner sign, displayed cards, Inspect, MY PLOT button and spawn on own plot. No decorations or prestige indicators |

## §19 Selling

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §19.1 | Sell eligible cards for in-game currency, server-valued | ✅ | `Market.sell`. Tests |
| §19.2 | Show name, rarity, grade, variant and estimated value | 🟡 | The detail panel shows everything except grade (no grades exist yet) |
| §19.3 | Confirmation before selling valuable cards | ⬜ | Sells on one click |
| §19.4 | Displayed cards handled safely; locked cards can't be sold during an operation | 🟠 | Displayed and favourite cards are protected (tests). No operation locks exist (needed once grading and trading arrive) |
| §19.5 | Duplicate sale requests prevented | ✅ | All-or-nothing: a repeat finds the card gone and fails. Test |
| §19.6 | Centralised valuation (base, rarity, variant, grade, limited) | 🟠 | `Economy.cardSaleValue` covers base, variant, grade and the sell upgrade. No "limited" factor |
| §19.7 | Favourite protection | ✅ | Test |

## §20 Trading

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §20 | Two-sided accept and confirm; changes invalidate confirmations; ownership re-check; locks; atomic; timeouts; anti-duplication | ⬜ | Not started. The spec says to build it after the core systems are stable. Globally unique instance ids are ready |

## §21 Leaderboards and achievements

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §21.1 | Leaderboards: Total Cash Earned, Income/s, Cards Discovered, Binder Completion, Highest Grade, Rare Cards | 🟠 | Only an in-server `leaderstats.Cash` showing **current** cash. `Stats.CashEarned` is tracked but not shown. No global leaderboards |
| §21.2 | Achievements with one-time rewards | ⬜ | — |

## §22 Limited-time events

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §22 | Config-driven events with server-checked start and end, event packs, cards, variants, currency, quests | ⬜ | — |

## §23 Robux monetization

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §23.1 | Configurable product ids; never invent real ids; placeholders | ✅ | `Config/Monetization`: every `Id = 0` (disabled) |
| §23.2 | Developer products via idempotent `ProcessReceipt` with persisted transaction state | ⬜ | `Purchases.Receipts` is reserved; there's no handler |
| §23.3 | Game Pass ownership verified and benefits applied on the server | ⬜ | — |
| §23.4 | Store UI (icon, name, description, price, benefits, buy, feedback); free vs paid clearly separated | ⬜ | — |
| §23.5 | Compliance for paid random items (odds, regional rules) | ⬜ | No paid random items exist yet |
| §23.6 | Placeholder catalogue follows the suggested products (Cash bundles, boosts, passes) | ❌ | `TreatsSmall` and `TreatsLarge` sell a currency the spec doesn't define. See C9 |

## §24–25 UI, UX and audio

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §24.1 | TOP AREA: cash, income/s, currencies, Pack Shop, Plot, event indicator | ❌ | Cash, income/s and currencies sit on the **left-middle**, following the reference. Pack Shop and stands buttons are at the top. No event indicator. See C12 |
| §24.2 | SIDE NAV: Backpack, Binders, Grader, Upgrades, Boosts, Shop, Quests, Settings | 🟠 | Has Backpack, Binder, Upgrades and Settings. Missing Grader, Boosts, Shop and Quests |
| §24.3 | Contextual modals; one panel at a time | 🟡 | `UI/Windows` (single-window manager) |
| §24.4 | Desktop, mobile, tablet, aspect ratios, mouse, touch, keyboard shortcuts | 🟠 | Viewport scaling, mouse and touch. No keyboard shortcuts. Not verified on devices |
| §24.5 | Settings: music, SFX, reduced effects, reduced screen shake, animation skipping, interface scale | 🟠 | Has music, SFX, reduced motion and notifications. Missing screen shake, animation skip and UI scale |
| §25.1 | Audio and visual feedback for key actions | ⬜ | No sounds. Visual feedback is limited to toasts and the reveal pop-in |
| §25.2 | Configurable audio references with placeholders and a documented setup | ⬜ | No sound system |
| §25.3 | Reduced-effects setting | ✅ | `Settings.ReducedMotion` (validated and persisted; test) |

## §26–29 Architecture, security, persistence, performance

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §26.1 | Modular server, client, shared, config and UI separation | ✅ | Matches the suggested layout under different names (`DataService` = PlayerDataService, `EconomyService` = IncomeService, `Logic/*` = utilities). `ARCHITECTURE.md` |
| §26.2 | No authoritative logic in LocalScripts; clients can't modify server data | ✅ | The client only mirrors data |
| §27.1 | Server controls currency, ownership, rewards, placement, upgrades and selling | ✅ | Each one has a validated, server-side transaction. Tests |
| §27.1 | Server controls grades, collection rewards, daily rewards, boosts, trading and paid rewards | ⬜ | Those systems don't exist yet |
| §27.2 | Validate every remote input: identifiers, quantities, currency, capacity, card availability | ✅ | `Util/Validate` plus the per-transaction checks. Tests: `Util.spec`, `Gameplay.spec` |
| §27.2 | Validate plot ownership, operation state and transaction uniqueness | 🟠 | Plot ownership is enforced by design (no remote takes plot or stand ids; tests for the allocator). No operation states or transaction ids yet |
| §27.3 | Rate limiting on important remotes | ✅ | `Lib/Net` token buckets. Tests: `Util.spec` |
| §27.4 | No arbitrary paths or functions in remotes; safe failures; logging of suspicious requests | 🟡 | Fixed remote set; `warn` on invalid requests; generic client errors |
| §28.1 | Saved data: currency, cards, display, upgrades, discovered cards, binder progress, daily, quests, settings, stats, schema version | ✅ | `ProfileSchema` v1. Tests |
| §28.1 | Saved data: **eligible active boosts, last offline-income timestamp** | 🟠 | `Income.LastOnline` and `Income.Pending` added (additive, filled by `reconcile`; test). Boosts are still missing |
| §28.2 | Protected calls, retries on temporary failures, session locking, UpdateAsync, schema version and migration, safe loading, no duplicate default rewards, never default after a failed load | ✅ | `Lib/SessionStore`. Tests: `SessionStore.spec` (14 cases, mutation-checked). Never run against the real DataStoreService |
| §28.3 | Periodic, leave and shutdown saves | 🟡 | `DataService` (autosave loop, PlayerRemoving, BindToClose). Not verified in Studio |
| §28.4 | Diagnostic logging | 🟡 | `SessionStore` logs retries, contested and expired locks, rejections and repairs |
| §29.1 | Centralised income scheduler (not a loop per card) | ✅ | One `EconomyService` loop |
| §29.2 | Don't rebuild whole interfaces when one value changes | ❌ | The Backpack, Stands and Binder windows rebuild every tile on any change while open. See C11 |
| §29.3 | Limit effects at distance; clean up objects and connections | ⬜ | No world objects yet |
| §29.4 | Usable on lower-end devices | 🟠 | Not measured. The UI scales, but full rebuilds (C11) will hurt large inventories |

## §30–33 Process, testing, balancing, deliverables

| Req | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| §30.1 | Inspect the tools; Rojo workflow; honest about Studio testing | ✅ | `PHASE0_REPORT.md`, `README.md`, `TESTING.md` |
| §30.2 | Phase order: the spec's Phase 2 includes **plot claiming, display stands, 2D illustrations** | ❌ | Our "Phase 2" shipped packs, inventory and UI-only stands, and skipped plots and illustrations. Its Phase 3 items (upgrades, binders, selling) were started early. See C14 |
| §31.1 | Card system tests: valid ids, rarities, pack references, variants | ✅ | `Config.spec`, `CardRegistry.spec` |
| §31.2 | Pack tests: correct deduction, failed purchase charges nothing, exact reward, invalid ids rejected, repeated requests | 🟠 | Buy and open covered separately (`Gameplay.spec`, `Util.spec`). Server-side duplicate-request idempotency is still missing |
| §31.3 | Inventory tests: unique ids, duplicates, capacity, invalid references | ✅ | `Inventory.spec` |
| §31.4 | Plot tests | ✅ | `Plots.spec`: assignment, uniqueness, release, full capacity, non-owner checks, layout, stand states, replace and remove cleanup, duplicate display, income kept on swap, arrangement restored after save and rejoin |
| §31.5 | Income tests: multipliers, no duplication, collection exploit, offline limits | ✅ | `Economy.spec`, `IncomeLedger.spec` (double collect, caps, offline cap, crash double-count) |
| §31.6 | Grading tests | 🟠 | Pure helpers only |
| §31.7 | Upgrade tests | ✅ | `Gameplay.spec`, `Economy.spec` |
| §31.8 | Persistence tests | ✅ | `SessionStore.spec`, `ProfileSchema.spec` |
| §31.9 | Monetization and trading tests | ⬜ | Systems don't exist |
| §31.10 | Development-only test mode or commands, not exploitable in production | ✅ | Studio-only `DevCommand` (remote never created on live servers); fixed command table; tests: `DevCommands.spec`. See `docs/DEVTOOLS.md` |
| §32 | Initial balancing (starting cash $500, starter pack $100, free basic stand, rarity income bands) | ❌ | See [config differences](#configuration-differences) (C5, C10) |
| §33.1 | Deliverables: README, how to run in Studio, changelog, remaining tasks | ✅ | `README.md`, `DEVLOG.md`, this file |
| §33.2 | Guides: card creation, pack config, grading config, monetization config, DataStore testing, new artwork, new cards, new collection sets | 🟠 | DataStore testing is in `TESTING.md`; config conventions are in `ARCHITECTURE.md`. The dedicated guides are missing |

---

## Conflicts with the specification

These are earlier decisions that contradict the specification. Each needs a code or config
change. **No working system was changed during this audit.** The fixes are scheduled in
[ROADMAP.md](ROADMAP.md).

| # | Current behaviour | Spec | Recommended change | Data migration |
| --- | --- | --- | --- | --- |
| C1 | ~~No unopened-pack inventory~~ **Resolved:** packs go to inventory and open on demand (decision Q1) | §3.3 starter **packs**; §13 and §17 grant packs as rewards; §7.5 opening sequence | Add owned packs (`Packs: { [packId]: count }`), an `OpenPack` remote, and starter packs. The shop may keep "buy and open" as a shortcut (Q1) | Additive field. `reconcile` adds it; no version bump |
| C2 | Instant grid reveal | §7.5 pack, blur, animation, open, flip, rarity effects, skip option | A new opening sequence controller, plus a results screen and a skip setting | None (Settings gains `SkipAnimations`, additive) |
| C3 | ~~Stands exist only as a UI list~~ **Resolved (needs Studio verification):** physical plots with 12 stands each, auto-assigned; My Stands stays as a management window over the same data | §8 physical stands on a personal plot, with interaction | `PlotService` (claim and release, per-server plot assignment), physical stand models, ProximityPrompt interaction. Reuse `Logic/Display` and the saved `Display` map unchanged | None: `Display` slot → instance already persists the arrangement |
| C4 | ~~Income auto-credited~~ **Resolved in logic and UI:** stands accumulate; collect per stand or centrally (Q3). Collecting at a physical stand waits for C3 | §10 stands accumulate; the player **collects**; the Auto-Collection upgrade or pass and the Collection Radius upgrade imply manual collection by default | Track uncollected earnings per stand on the server; add a `CollectEarnings` remote (by stand, or all within radius); credit Cash only on collection | Additive (pending earnings) if uncollected earnings must survive a rejoin (Q3) |
| C5 | ~~1,500 Cash plus starter cards~~ **Resolved:** $500 plus 3 starter packs | §3.3 starter currency **and starter packs**; §32 starting cash $500 | Grant $500 plus N starter packs (count to be decided); the tutorial guides opening and placing | Existing profiles keep their grant (`Flags.StarterGranted`). Only testers' data exists |
| C6 | Collection bonus is the only binder reward | §13 one-time claimable rewards (cash, packs, variants, decorations, titles, badges, slots) | Add a `ClaimBinderReward` remote using the reserved `Collections.Claimed`. Keep the income bonus as one reward type | None (field reserved) |
| C7 | Grading by four averaged sub-grades | §11 configurable **per-grade probability table**, with probabilities shown in the UI | Replace with `Config/Grading.GradeWeights[1..10]` (or per-category tables). Sub-grades may stay as cosmetic flavour only if derived from the rolled grade | **None**: no card has ever been graded (`Grade` is nil everywhere) |
| C8 | Treats: a second currency, earned on level-up, with nothing to spend it on | Not defined in the spec. §17 and §22 mention "special event currency" only | Owner decision (Q9): repurpose Treats as the §22 event currency, or remove them | If removed or renamed: version bump with `MIGRATIONS[1]` (drop or move `Currency.Treats`) |
| C9 | Developer-product placeholders sell Treats | §23 suggests Cash bundles and boosts | Replace the placeholders with Cash bundles and temporary boosts | None (placeholders, all disabled) |
| C10 | Income scales by collection tier (Burrow ×1 to Midnight ×12,000; up to 3.6M/s); packs cost 750 to 200M; starting cash 1,500 | §32 rarity income bands (Common $2–10, Uncommon $10–30, Rare $30–100, Epic $100–300, Legendary $300–1,000, Mythic and Secret higher); starting cash $500; starter pack $100 | Re-balance cards to rarity bands and re-price packs, then re-run `scripts/simulate.luau` against §32's "first ten minutes" goal | None (config). Existing testers' balances are unaffected |
| C11 | Backpack, Stands and Binder rebuild every tile on every change | §14.4 no rendering of every card at once; §29 no full rebuilds | Grouped and virtualised grid (one tile per CardId and variant with counts, rendered on demand); incremental updates | None |
| C12 | Currency HUD on the left-middle | §24 TOP AREA holds cash, income/s and currencies | Move the stats cluster to the top bar; add the missing side-nav entries as features land | None |
| C13 | Extra `SellBonus` upgrade; 6 of the 10 spec upgrades missing | §15 initial upgrade list | Add the missing upgrades as their systems land. Owner decision (Q8) on keeping SellBonus | Removing it: refund the cumulative cost and drop `Upgrades.SellBonus` (version bump) |
| C14 | ~~Phase order diverged~~ **Mostly resolved:** the spec Phase 2 items (plots, stands, illustrations, income) now exist; the opening sequence and rebalancing remain | §30 Phase 2 = plots, stands, illustrations, income | Finish the spec's Phase 2 before more Phase 3 or 4 work (ROADMAP Phase A) | — |
| C15 | ~~Pack buy buttons ignore affordability~~ (resolved); still no purchase confirmation | §7.3 | Grey out unaffordable packs; confirm large purchases | None |
| C16 | No server-side request idempotency | §7.4, §27 "transaction uniqueness"; §31 "repeated requests do not grant duplicate rewards" | Optional client request id on purchase and grade remotes, de-duplicated per session on the server | None |

### Earlier assumptions now settled by the specification

The previous assumption register (A1–A40) is superseded:

- **Confirmed by the spec:**
  - A7: the seven rarities.
  - A12 and A34: permanent card ids, separate from instance ids.
  - A18: odds shown to players.
  - A25: protection for favourite and displayed cards.
  - A35–A37: session locking, the Studio mock store and rate limits.
  - A11: configurable placeholder art.
  - A10: a permanent income bonus is an allowed binder reward, but it isn't enough on its
    own (C6).
  - A8, partly: Normal, Gold, Rainbow, Shiny and Holographic are confirmed; the multipliers
    remain ours to balance.
  - A28, partly: four upgrades map to spec upgrades.
- **Contradicted by the spec:**
  - A2 (C3).
  - A13 (C1).
  - A16 and A22 (C5, C10).
  - A20 and A21 (C8).
  - A23: no offline income and no collection (C4, §10).
  - A31 (C7).
  - A33 (C9).
  - A40 (C12).
- **Not addressed by the spec (kept as implementation decisions; owner may veto):**
  - A26: player level and XP gating packs. The spec never mentions player levels. See Q7.
  - A30: Place Best.
  - A6: species as colour morphs. The spec mentions "species, personalities"; see Q5.
  - A5: card names and collections. The spec's names are examples; ours are original and
    allowed.

## Owner decisions (2026-10-19)

The owner answered the four questions that blocked Phase A:

| # | Question | Decision | Implemented |
| --- | --- | --- | --- |
| Q1 | Bought packs: inventory, or open immediately? | **Packs go to the inventory, and the player opens them whenever they want** | ✅ `Packs` field, `BuyPack` / `OpenPack` |
| Q2 | Cards per pack? | **Five** | ✅ `CardsPerOpen = 5` for every pack |
| Q3 | Collect per stand or centrally? | **Both:** each stand accumulates money, and the player can also collect everything centrally | ✅ `IncomeLedger`, `CollectEarnings(slot)` where slot 0 means all; per-stand and HUD buttons |
| Q4 | Plot claiming? | **On joining, the player is automatically given their own free plot** | ⬜ Binding for roadmap A3 (no plots exist yet) |

## Ambiguities (documented, not decided)

These are questions the specification leaves open. Each is listed rather than settled by an
irreversible decision. Q1–Q4 are now decided (above).

| # | Question | Spec evidence | Interim position |
| --- | --- | --- | --- |
| Q14 | **Pack 1 printed values vs the economy.** The art prints incomes (Uncommon 70/s up to Mythic 1,500/s) above the spec's §32 guideline bands (Uncommon $10–30, Rare $30–100, Epic $100–300) and far above the 36 placeholder cards (from 1/s). | §32 calls its bands guidelines; the art is the owner's content | The card config follows the art. Pack 1 is the first and starter pack ($1,500; sale value 2× income, so packs can't be resold at a profit). The placeholder catalog is now economically pointless next to Pack 1: **A8 must re-band or retire it** (owner to decide) |
| Q15 | The pack art's logo reads **"FERRET FRENZY"**, while the spec names the game "Ferret Card Tycoon" | §1, §2 | Art unchanged; owner to confirm the brand name |
| Q5 | What do "species" and "personalities" mean? | §3.5 and the §4 Species field | Species stays a descriptive field. Personality could become a Tag (§4.3) |
| Q6 | Can displayed cards be graded? Can graded cards be re-graded, and if so does a lower result replace the grade? | §11.7 "if the grading rules prohibit…"; the UI shows "current grade, if already graded" | Require removal from the stand; allow re-grading, where the new grade replaces the old (the spec states the risk); make it configurable |
| Q7 | Keep the player level and XP system (not in the spec)? | The spec has no levels; its unlocks are card `UnlockRequirements`, events and progression | Keep it as a pacing gate for now. Don't extend it until the owner decides |
| Q8 | Keep the SellBonus upgrade? | Not in §15 | Keep it for now; it's listed in C13 |
| Q9 | What happens to Treats? | Not defined; "special event currency" in §17 and §22 | Event currency (preferred) or removal |
| Q10 | Plot Capacity vs Card Display Capacity: what's the difference? | §15 lists both | Plot Capacity = plot expansions (space and decorations); Display Capacity = stand count |
| Q11 | "Collection value" per rarity: what does it feed? | §6 | Probably sale value and binder prestige; unused until leaderboards and prestige exist |
| Q12 | Daily-reward reset boundary | §17 says handle time zones consistently | A UTC day boundary, shown as a countdown |
| Q13 | Can trades include currency? | §20 "if the economy design supports it" | Cards only in the first version |

## Configuration differences

These compare our configuration with the spec's examples and guidelines. The spec calls its
§32 and §11 values guidelines or suggestions, so differences become required changes only
where they break a stated goal. The recommended changes are config-only, and **none needs a
data migration**.

| Setting | Spec | Current | Recommendation |
| --- | --- | --- | --- |
| Starting cash | $500 | 500, plus 3 starter packs | ✅ Matches |
| Starter / first pack price | $100 | Burrow Pack 750 | Add a $100 Starter Pack |
| Basic display stand | Free; "a small number" initially | 4 free stands | Owner to confirm the initial count |
| Common income | $2–10/s | 1/s (Burrow) up to 12,000/s (Midnight) | Re-band by rarity (C10) |
| Uncommon income | $10–30/s | 2 to 30,000/s | Re-band |
| Rare income | $30–100/s | 6 to 72,000/s | Re-band |
| Epic income | $100–300/s | 15 to 180,000/s | Re-band |
| Legendary income | $300–1,000/s | 320 to 480,000/s | Re-band |
| Mythic / Secret income | "Higher" / "exceptional" | 200K–1.2M / 3.6M/s | Re-band relative to Legendary |
| Grade multipliers | 0.8 / 0.9 / 1.0 / 1.1 / 1.2 / 1.4 / 1.7 / 2.1 / 2.7 / 3.5 | 0.8 / 0.85 / 0.9 / 0.95 / 1 / 1.1 / 1.2 / 1.5 / 2 / 3 | Adopt the spec's table as the starting point with the grading rework (C7). No migration: nothing is graded |
| Grade probabilities | A configurable per-grade table | Derived from sub-grade weights | Add `GradeWeights` (C7) |
| Upgrade cost formula | `Base × Mult ^ Level` | Identical | Keep |
| Variants | 9 listed | 5 | Add Crystal, Shadow, Prismatic and Limited Edition; rename the Holo display name to "Holographic" (keep the id `Holo`, so no migration) |
| Pack names | Starter, Meadow, Woodland, Ocean, Adventure, Royal, Mythic, Limited Event ("could include") | Burrow, Snack, Knight, Shore, Cosmic, Midnight | Optional; examples only. Renaming pack ids is safe today (packs aren't stored) but not once the pack inventory exists |
| Card names | Examples (Sleepy Ferret, …) | Original names | Optional; examples only. Renaming card ids after release needs a migration |

## Data migrations

**Current schema: v1. This audit made no changes, so no migration runs now.** The roadmap's
changes have this data impact:

| Change | Kind | Action |
| --- | --- | --- |
| Pack inventory (C1) | Additive | Add `Packs = {}` to `defaults()`. `reconcile` fills it on load; no version bump |
| Offline timestamp (§10, §28) | Additive | Add `Income = { LastOnline = 0, Pending = {} }`. On first load, 0 means "no offline award" |
| Uncollected stand earnings (C4) | Additive | Part of the field above |
| Active boosts (§16, §28) | Additive | `Boosts = { [boostId] = expiresAtUnix }` |
| Tutorial progress (§3) | Additive, with initialisation | `Tutorial = { Step = 0, Done = false }`. **Existing profiles** should be marked done (when `Stats.PacksOpened > 0`) inside a v1→v2 migration, so veterans don't see the tutorial |
| Quest claim state (§17) | Shape change of a reserved, always-empty field | Restructure `Quests` in the same v2 migration. Safe, because no data uses it |
| Achievements and leaderboard stats (§21) | Additive | `Achievements = {}`. Track `HighestGrade` in `Stats` |
| Grading rework (C7) | None | No graded cards exist |
| Remove or rename Treats (C8) | **Breaking** | v1→v2 `MIGRATIONS[1]`: move or drop `Currency.Treats` |
| Remove SellBonus (C13) | **Breaking** | v1→v2: refund the cumulative cost to Cash, then drop the key |
| Rebalancing (C10) | None | Config only |

**Recommendation:** batch every breaking and initialising change into **one** v1→v2
migration, written before the first public release, with a unit test for each step in
`ProfileSchema.spec.luau`. No production data exists yet: the game has never been
published, as far as the repository shows.

---

## What exists today (implementation inventory)

For reference, here is what the code contains. The status of each item is given by the
audit above.

- **Shared config:** `Game`, `Economy`, `Rarities`, `Variants`, `Collections`, `Cards` (6
  Pack 1 cards with real art plus 36 placeholders), `Packs` (Pack 1 plus 6 placeholder
  packs), `Grading`, `Upgrades`, `Monetization`, `Assets` (the artwork mapping), `World`
  (layout) and `Visuals` (palette, illustration and rarity effects).
- **Shared logic:** `CardRegistry`, `CardArt`, `Economy`, `IncomeLedger`, `Progression`,
  `Collections`, `PackRoller`, `PackShop`, `Grading` (helpers only), `Wallet`,
  `Inventory`, `Account`, `Display`, `Market`, `UpgradeShop`, `PlotAllocator`,
  `PlotLayout`, `PlotView`, `ConfigCheck`, `ProfileSchema`, and utilities.
- **Server:**
  - Libraries: `SessionStore`, `MockDataStore`, `Net`, `DevCommands`.
  - `World/WorldBuilder`.
  - Services: `DataService`, `SettingsService`, `PackService`, `CardService`,
    `UpgradeService`, `EconomyService`, `WorldService`, `PlotService`, `DevService`
    (Studio only).
- **Client controllers:** Data, Notification, HUD (with MY PLOT), Settings, Packs (with
  reveal), Backpack (including stand-target mode), Display (My Stands), Upgrades, Binder,
  StandVisuals (3D illustrations), Plot (stand prompts), World (station prompts) and Dev
  (Studio only).
- **Assets:**
  - `assets/source/Pack 1` (originals).
  - `assets/processed/pack1` (upload-ready copies).
  - `scripts/assets/process_card_art.py`.
- **Tests:** 179 Lune tests: 16 unit spec files plus the built-place structure check. CI runs
  the full Roblox-std Selene.
- **Tools:** `scripts/check.sh`, `scripts/install-tools.sh`, `scripts/simulate.luau`, and the
  Studio developer commands (`docs/DEVTOOLS.md`).
