# Game specification

## Status: the master specification has NOT been recovered

The original specification ("the complete game specification … source of truth for the
game's design, mechanics, requirements, and long-term goals", per the Phase 0 brief) has
never been available to development. This file does **not** contain it, and nothing here
should be read as the original design.

Searched on 2026-10-19:

| Location | Result |
| --- | --- |
| This repository, all branches (`main`, `claude/ferret-card-tycoon-setup-8vqo00`) | Not present. `main` holds only the reference screenshots |
| GitHub issues and pull requests for `Mickjay07/roblox-furret` | None exist |
| The cloud development container's filesystem | No spec-like document |
| `~/Downloads/Ferret frenzy/` (the developer's local machine) | Not reachable from the cloud environment |
| The development conversation | Only the phase briefs were provided, never the specification text |

**To resolve this:** paste the full specification below, replacing this status section, or
commit the original file and link it here. Then re-review the assumption register in
[STATUS.md](STATUS.md#assumption-register).

---

## Requirements on record (from the phase briefs, not the master specification)

These are the only written requirements that development has received. They come from the
project owner's phase instructions, are binding, and the implementation follows them. They
are **not** a substitute for the master specification and may be incomplete.

### Product (Phase 0 brief)

- **R-0.1** The game is "Ferret Card Tycoon", a "complete, polished collectible card
  tycoon game" on Roblox.
- **R-0.2** Build it progressively, in verified stages.
- **R-0.3** Reference screenshots exist and set a design direction (see R-1.6.2).

### Foundation (Phase 1 brief)

**R-1.1 Configuration:** centralised configuration for game settings, economy, rarities,
card definitions, card packs, grading, upgrades and monetization placeholders. Gameplay
values must be configurable, not scattered through the code.

**R-1.2 Card registry:**
- Each card definition has: a unique CardId, a display name, a description, a species, a
  rarity, base income, base sale value, an artwork reference, a collection reference,
  variants, and unlock requirements.
- Every individual owned card has a unique instance id.
- Aim for at least 30 original cards, using configurable artwork placeholders where final
  art is not available.

**R-1.3 Player data:** fields for currency, owned card instances, discovered cards,
display arrangements, upgrades, collection progress, quest progress, daily rewards,
settings, progression statistics and a schema version.

**R-1.4 Persistence:** DataStoreService with:
- protected calls and retries;
- periodic saving;
- saving when a player leaves and when the server shuts down;
- schema versioning and safe migration;
- session safety;
- protection against duplicate starter rewards.

Data must never be replaced with empty defaults after a failed load.

**R-1.5 Networking:**
- Validated RemoteEvents and RemoteFunctions.
- The server is authoritative over data, currency, card ownership and progression.
- The server validates identifiers, quantities, ownership and request frequency.

**R-1.6 HUD:**
- **R-1.6.1** Shows cash, the relevant currency values, current income (when available),
  basic navigation and notifications.
- **R-1.6.2** Follows the design direction of the reference screenshots.

**R-1.7 Testing:** tests for important pure logic and configuration. Live DataStore
behaviour must not be claimed as verified without a Studio test.

### Phase 2 brief

**R-2.1** "Continue to Phase 2" after the foundation. **No scope was specified.** The
Phase 2 content (the core loop) was proposed by development, not by the owner.

### Reference screenshots

`docs/reference-screenshots/` contains 17 images of a **different, existing game**. They set
visual and structural direction only (R-1.6.2). They are not a specification, and their
names, content and numbers must not be copied.

---

## Missing requirements

Everything below is undefined because the master specification is missing. Each item is
currently filled by an assumption. The [assumption register](STATUS.md#assumption-register)
shows the current behaviour and its classification.

### Core concept and scope

1. **Core loop.** What does the player do moment to moment, and what is the long-term goal?
   Is there an end state, prestige or rebirth?
2. **Tycoon layer.** Is there a physical, per-player plot? What is built on it, and how
   does it expand?
3. **Multiplayer interaction.** Are there trading, gifting, leaderboards, visiting other
   players' plots, or competitive features?
4. **Session length and pacing targets.** For example: time to the first upgrade, the first
   new pack, and to "complete" the game.
5. **Target platforms and priority.** Mobile, PC, console.

### Cards and collections

6. **Card list.** The intended number of cards, collections (sets), themes and names, and
   whether any original card content exists.
7. **Species.** What "species" means in a ferret game (colour morphs? real mustelid
   species?) and whether it affects gameplay.
8. **Rarity tiers.** The names, how many, and their visual treatment.
9. **Variants.** Which variants exist, how they are obtained, and their effects.
10. **Unlock requirements.** Which cards are gated, and by what (level, collection,
    events)?
11. **Collections.** What completing a collection gives. Do "master" versions exist (for
    example, every variant)?
12. **Artwork pipeline.** Who produces the art, in what style, and to what asset
    specification.

### Packs

13. **Pack list.** Which packs exist, what they contain, their prices, the currency used,
    the cards per pack, and the drop rates.
14. **Opening.** Do packs open on purchase, or are they stored as inventory items and
    opened later?
15. **Stock and restocking.** Are there limited stock, restock timers, limited or event
    packs?
16. **Odds disclosure.** How odds are shown (also relevant to Roblox policy on paid random
    items).

### Economy and progression

17. **Currencies.** How many, what they are called, how each is earned and **what each is
    spent on**.
18. **Income model.** Where income comes from (displayed cards? other sources?), whether
    it accrues offline or while AFK, and any caps.
19. **Selling.** The sale values, any restrictions, and bulk selling.
20. **Player level and XP.** Does a level system exist? What gives XP, and what do levels
    reward?
21. **Starter experience.** The starting resources, the tutorial and onboarding flow.

### Systems in the Phase 1 brief whose design is unspecified

22. **Grading.** The sub-grades, how a grade is computed, the effects, the cost and
    currency, whether re-grading is allowed, and any best-grade history.
23. **Upgrades.** The list, effects, costs, caps and currency.
24. **Quests and goals.** Their structure, rewards and reset cadence.
25. **Daily rewards.** The schedule, streak rules and rewards.
26. **Boosts.** Whether they exist (the reference shows Luck, Cash and Shiny boosts).
27. **Monetization.** The actual game passes and developer products, with their effects and
    prices.

### Presentation

28. **Visual identity.** The game's own art direction beyond the reference screenshots:
    logo, fonts, colours.
29. **Audio.** Music and sound design.
30. **World stations.** Which interactive stations exist in the world (the reference shows
    Packs, Sell, Grader, Boosts and others).
