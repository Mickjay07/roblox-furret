# Reference screenshots

The project owner uploaded 18 screenshots to `main` on 2026-10-19. They were moved here in
Phase 1. `reference-12.webp` was byte-identical to `reference-11.webp` and was dropped.

The screenshots show an existing Roblox cat-card collecting game, and they are used **only
as design direction**: layout, visual style and the general shape of the core loop. All
names, card content, text and art in Ferret Card Tycoon must be original. Never copy cat
names, set names, logos or artwork from these images.

## What each screenshot shows

| File | Content | What we take from it |
| --- | --- | --- |
| 01 | Player plot: card display stands with "1 IN X" labels, goal panel, best-card prompt, binder progress | Display stands earn income; odds shown on cards; goal/quest panel top-left |
| 02 | Grader window: four sub-grades (Corners, Centering, Surface, Edges), score, next-grade multiplier, Roll/Auto | Grading model in `Config/Grading` (sub-grades, score, multiplier) |
| 03 | Hub world: Sell, Packs, Traits, Grader, Boosts, Towers stations | Physical stations to visit (later world-building phase) |
| 04 | Pack shop: pack rows with rarity, stock, price, restock timer, quantity stepper | Pack shop window (Phase 2); stock/restock is a later option |
| 05 | Single card reveal with "+X/S", rarity, "1 IN 4" | Reveal screen shows income and odds |
| 06 | Unopened pack "TAP OR SWIPE TO OPEN" | Pack-opening moment |
| 07 | Five-card reveal row with NEW! badges | Multi-card reveal with new-discovery badges |
| 08–10 | Backpack: card grid, filters (All/Packs/Cards/Favs), sort (Recent/Name/Rarity/Best/Favorite), capacity 45/425, empty state | Backpack window, capacity limit, favourites, sorting |
| 11 | Binders: per-set progress, luck bonus, normal/master binder | Collections with completion bonuses |
| 13 | Boosts: Luck, Super Luck, Cash x2, Shiny; free daily | Future boost system; daily rewards |
| 14 | Plot overview with large showcase card and binder | Plot presentation |
| 15–16 | Grader with grade history; "Pick a card" picker with ON STAND tags and variant tags (Holo, Gold, Rainbow) | Variants; cards on stands are flagged |
| 17 | Store: limited pack with chase card and Robux prices | Monetization (placeholders only) |
| 18 | Store: VIP pass, 2x AFK time, x3 open | Game pass ideas (placeholders in `Config/Monetization`) |

## Design direction (applied in `src/client/UI/Theme.luau`)

- **Typography:** chunky rounded font (FredokaOne), white text with a thick dark outline.
- **Buttons:** saturated pill buttons (green = primary/buy, blue = secondary, orange,
  purple), each with a darker border and a light top-to-bottom gradient.
- **Panels:** dark rounded windows with a thick black border, a title in a coloured header,
  and a red square close (X) button that overlaps the top-right corner.
- **HUD layout:**
  - Cash (large green number with an icon), "+X CASH/S" and the level bar sit on the
    left, vertically centred.
  - The primary actions are at the top centre.
  - A feature rail (Shop/Binder/Upgrades/More) runs down the right side.
  - Toast notifications stack in the bottom-right corner.
- **Rarity colours:** grey Common, green Uncommon, blue Rare, purple Epic, gold Legendary,
  plus higher tiers.
