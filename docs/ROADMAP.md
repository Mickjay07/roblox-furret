# Implementation roadmap

Last updated: 2026-10-19.

This roadmap is derived from the requirement audit in [STATUS.md](STATUS.md) and the master
specification ([SPEC.md](SPEC.md)). It follows the specification's phase order (§30:
Foundation → Core gameplay → Progression → Retention → Social → Monetization → Polish) and
the real dependencies between systems.

- Items marked **C#** fix a conflict with the specification.
- Items marked **Q#** depend on an owner decision listed under ambiguities in STATUS.md.

**Rules for every phase:**
- Pure rules go in `src/shared/Logic` with Lune tests.
- Services stay thin and server-authoritative.
- Saved-data changes go through `ProfileSchema`. Breaking changes are batched into one
  v1→v2 migration before the first public release.
- Every phase adds manual checks to [TESTING.md](TESTING.md).
- A phase is "done" only after its Studio checklist has actually been run.

---

## Gate 0: before Phase A (owner input and first smoke test)

| Item | Why it blocks | Effort |
| --- | --- | --- |
| ~~Owner answers Q1–Q4~~ ✅ **Done 2026-10-19:** packs go to inventory; 5 cards per pack; per-stand and central collection; plot auto-assigned on join | — | — |
| First Studio smoke test of the current build (TESTING.md "Setup", "Persistence" and "Security" sections) | Nothing has run in Studio yet. Persistence and remote wiring must be proven before the world is built on top of them | 1 session |

## Phase A: finish the spec's core loop on a physical plot (spec Phase 2)

Goal: the §3 loop works end to end in the 3D world. Claim a plot, open starter packs, place
cards on physical stands, see illustrated ferrets float above them, collect earnings, and
earn offline income.

| # | Work | Spec | Depends on | Notes |
| --- | --- | --- | --- | --- |
| A1 | ✅ **Done (2026-10-19):** Studio-only developer commands (`docs/DEVTOOLS.md`): cash, packs, test cards, level, accrue, simulated offline time, distribution rolls, stand/income/data/plot diagnostics, save, home, reset. The remote is never created on live servers | §6.11, §31.10, §32 | — | Tested (`DevCommands.spec`) |
| A2 | ✅ **Done:** generated world: spawn plaza with monument, avenue, Pack Shop, Upgrades, Collect All, reserved Grader, light decor, lighting (`World/WorldBuilder`, `Config/World`, `Config/Visuals`) | §18 | — | Needs a Studio look-and-feel pass |
| A3 | ✅ **Done:** `PlotService` with automatic assignment after a safe load (Q4), unique ownership, release on leave, full-server message, owner signs, spawn on own plot, MY PLOT teleport; no remote takes plot ids | §8.1–8.2, §27 | A2 | Tested (`Plots.spec`) |
| A4 | ✅ **Done:** 12 physical stands per plot mirroring `Display` (`PlotView`); locked-stand visuals; stand prompts open the backpack for that stand; placement through the existing `PlaceCard` | §8.4–8.7 (C3) | A3 | |
| A5 | ✅ **Done:** floating card illustrations (`StandVisualsController`) with aspect ratio kept, shared float loop, rarity effects near the camera, culling, cleanup; placeholder until art is uploaded | §9 | A4 | **The Pack 1 art must be uploaded to Roblox** (assets/README.md) |
| A6 | 🟠 **Mostly done:** accumulation, per-stand (stand prompt) and central (booth, HUD, My Stands) collection, offline earnings, "$X" stand labels. **Remaining:** collection animation, full inspect panel with bonus breakdown, collection radius (upgrade, Phase B) | §10 (C4), §28 | A4 | Additive fields `Income.LastOnline` and `Income.Pending` |
| A7 | 🟠 **Partly done:** pack inventory, `OpenPack`, starter packs, 5 cards per pack. **Remaining:** the §7.5 opening sequence and the skip setting. Original scope — **Pack inventory and opening sequence:** owned packs, `OpenPack`, starter packs in the starter grant, shop "buy" (plus optional "buy and open"), the §7.5 sequence (centred pack, blur, open, flip, rarity effects), a results screen, and a skip-animations setting | §3.3, §7.5 (C1, C2, C5) | Q1, Q2 | Additive `Packs` field; `Settings.SkipAnimations` |
| A8 | 🟠 **Partly done:** $500 starting cash; affordability greying; Pack 1 priced so it can't be resold at a profit. **Remaining (now urgent, Q14):** decide whether to re-band or retire the placeholder catalog around Pack 1's printed values; re-price; first-10-minutes targets in `scripts/simulate.luau`; purchase confirmation; optional request ids | §32 (C10), §7.3 (C15), §7.4 (C16) | Q14 | Config only, plus a small `Net` change |
| A9 | **HUD alignment:** cash, income/s and currencies in the top area; Pack Shop and Plot at the top; side nav ready for Grader, Boosts, Shop and Quests | §24 (C12) | — | Small |

**Exit criteria:**
- The Studio checklist sections "Plots", "Stands and illustrations", "Income and offline"
  and "Packs" pass with two players.
- New unit tests cover the plot allocator, the income ledger (collection exploits,
  offline caps) and owned-pack opening.

## Phase B: progression (spec Phase 3)

| # | Work | Spec | Depends on |
| --- | --- | --- | --- |
| B1 | **Grader Station:** a physical station; `GradingService` with a per-grade probability table `GradeWeights` (C7) and the spec's suggested multipliers; fee; displayed-card rule (Q6); operation lock on the card; idempotent requests; persisted result; UI with probabilities, income per grade and risk; grading animation | §11 | A2, A8 |
| B2 | **Variants:** add Crystal, Shadow, Prismatic and Limited Edition; a variant-treatment table driving card frames and world billboards (gold frame, rainbow, holo overlay, …) | §12, §5.5 | A5 |
| B3 | **Binder rewards:** claimable one-time rewards (`Collections.Claimed`) (C6); percentage, artwork, reward list; filters; "binder progressed" notifications | §13 | A7 (pack rewards) |
| B4 | **Inventory at scale:** grouped tiles (CardId and variant with counts) and virtualised rendering (C11); search, rarity filter, sort by grade; gradeable and collection-needed indicators; sell confirmation for valuable cards; reasons shown before an action | §4.5, §14, §19 | B1 (grades) |
| B5 | **Upgrades to spec:** Offline Earnings, Grading Discount, Income Collection Radius, Automatic Collection, Pack Opening Speed, Plot Capacity; decide SellBonus (C13, Q8) | §15 | A6, A7, B1 |
| B6 | **Schema v2:** one migration batching the tutorial initialisation, Quests reshape, and any Treats or SellBonus change (C8, C13), with tests | §28 | B5 |

## Phase C: retention (spec Phase 4, plus the §3 tutorial)

| # | Work | Spec | Depends on |
| --- | --- | --- | --- |
| C1 | **Server gameplay event bus** (pack opened, card discovered, card displayed, earnings collected, card graded, binder completed, upgrade bought) | §17, §21 | Phases A and B |
| C2 | **Quests:** id, objective, progress, reward, claim, expiry; driven only by server events | §17 | C1 |
| C3 | **Daily rewards:** configurable sequence; server UTC day boundary (Q12); duplicate-claim protection | §17 | — |
| C4 | **Boosts:** Luck, Super Luck, Cash, Shiny, Grading and Speed; server timestamps; additive-within-category stacking rules; plugs into `Economy` and `PackRoller` | §16 | A6, B1 |
| C5 | **Achievements and leaderboards:** one-time rewards; OrderedDataStore boards for total cash earned, income/s, cards discovered, binder completion, highest grade and rare cards | §21 | C1 |
| C6 | **Events framework:** config-driven start and end times, event packs, cards and variants; Treats repurposed as event currency (Q9) | §22 | A7, B2 |
| C7 | **Guided tutorial:** claim plot → open pack → place card → collect; resumable progress in saved data | §3 | Phase A, B6 |

## Phase D: social (spec Phase 5)

| # | Work | Spec |
| --- | --- | --- |
| D1 | Visiting plots: read-only inspection of other players' cards and stands; prestige indicators | §8.8, §18.3 |
| D2 | Plot customisation and decorations (cosmetic) | §8.3 |
| D3 | **Trading:** a two-sided offer, accept, then final confirm; any change invalidates confirmations; card locks; atomic swap with both profiles re-validated; timeouts and cancellation; duplication tests | §20 |

## Phase E: monetization (spec Phase 6)

| # | Work | Spec |
| --- | --- | --- |
| E1 | `MonetizationService`: idempotent `ProcessReceipt` using `Purchases.Receipts`; Game Pass ownership checks; server-applied benefits (income, offline duration, capacity, auto-collect) | §23 |
| E2 | Store UI separating free and paid items; catalogue aligned with the spec's suggestions (Cash bundles, boosts, passes) (C9); odds disclosure and regional compliance for any paid random item | §23 |

## Phase F: polish (spec Phase 7)

| # | Work | Spec |
| --- | --- | --- |
| F1 | Sound system with configurable asset ids and placeholders; feedback for every key action | §25 |
| F2 | Visual effects pass; reduced-effects, screen-shake and UI-scale settings; keyboard shortcuts | §2, §24 |
| F3 | Performance: streaming, effect budgets for distant plots, connection cleanup, mobile profiling | §29 |
| F4 | Final security review (exploit attempts from the client), persistence soak test, and the §33 guides (cards, packs, grading, monetization, artwork, collections, DataStore testing) | §27, §33 |
| F5 | Real artwork pipeline: replace placeholder art per card (configurable asset ids already exist) | §5 |

---

## Recommended next step (after Phase A1–A5, 2026-10-19)

**1. Gate 1: Studio verification and art upload.** These are owner actions; they unblock
everything that is 🟡:
- Run TESTING.md Part 1 in Studio, especially 1.3 (persistence), 1.4 (security probes),
  1.9 (plots and stands), 1.10 (illustrations) and 1.12 (developer tools).
- Upload the seven processed Pack 1 images and paste the asset ids into
  `Config/Assets.luau` (assets/README.md).
- Answer Q14 (placeholder catalog: re-band or retire?) and Q15 (brand name).

**2. Then finish Phase A:**
- **A8, the rebalance:** first, because Pack 1's printed values make the placeholder
  economy meaningless.
- **A7's §7.5 opening sequence:** the pack-front art now exists, so the sequence can show
  the real pack.
- **A9:** the HUD top-bar alignment.

**Why:** these complete the spec's Phase 2 (§30) and fix the remaining core-loop conflicts
(C2, C10, C12). Phase B (the Grader Station, already reserved in the world) builds on a
balanced economy, so it should wait for A8.
