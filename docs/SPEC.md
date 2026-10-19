# PROJECT: FERRET CARD TYCOON
## A Roblox Collectible Card Game, Collection Simulator & Tycoon

You are an expert Roblox game developer, gameplay systems engineer, UI/UX designer, economy designer, and technical architect.

Your task is to design and IMPLEMENT a polished, original Roblox game called "Ferret Card Tycoon".

IMPORTANT: Do not just describe how the game could be made. Your goal is to build the actual game, including gameplay systems, UI, data persistence, card collection mechanics, 3D world interactions, animations, monetization, and progression.

Work autonomously. Inspect the existing project, determine the available development tools, establish a practical architecture, and implement the game in well-organized stages.

Do not stop after creating a basic prototype or a few placeholder interfaces. Build a functional MVP first, test it, and then continue implementing additional systems.

If an engine feature, asset, or development tool is unavailable, find a practical alternative and document the limitation. Do not silently omit important functionality.

==================================================
1. GAME CONCEPT
==================================================

Create an original Roblox game inspired by the collectible-card simulator and tycoon genres.

The core concept is simple:

Players purchase card packs, open them, collect adorable illustrated ferrets, display their cards on their personal plots, and earn passive income based on the cards they display.

Players can improve their cards through grading, discover rare variants, complete collections, unlock upgrades, purchase boosts, and expand their collection.

The game should combine the following experiences:

- Collectible card opening.
- Cute illustrated animals.
- Personal plot ownership.
- Passive income generation.
- Card grading and progression.
- Collection completion.
- Tycoon upgrades.
- Trading and social interaction.
- Limited-time events.
- Optional Robux purchases.
- Long-term progression and achievements.

The game should be visually appealing, satisfying to play, easy to understand, and designed to support future content updates.

The primary audience is Roblox players who enjoy collection games, simulator progression, cute animals, and incremental games.

All player-facing text, interface elements, tutorials, descriptions, notifications, and game content must be written in ENGLISH.

Use a consistent English naming convention throughout the codebase.

==================================================
2. ORIGINAL IP AND VISUAL IDENTITY
==================================================

The game must feature FERRETS instead of cats.

Do not directly copy copyrighted character illustrations, card artwork, branding, names, sounds, or other assets from existing games.

Use the supplied screenshots and recordings only as references for general gameplay concepts and interface inspiration.

Create a distinctive visual identity for Ferret Card Tycoon.

Visual direction:

- Cute, expressive, collectible ferret illustrations.
- Colorful but readable environments.
- Warm, playful colors.
- Rounded cards and buttons.
- Bold outlines around important illustrations.
- High-quality gradients and subtle highlights.
- Smooth animations.
- Satisfying card-opening effects.
- Distinct visual identities for different rarities.
- Clear visual hierarchy.
- Polished, game-like UI rather than default Roblox menus.

The game should feel like a combination of a collectible card game, an idle tycoon, and a cozy animal collection simulator.

Avoid making the entire game look like a generic simulator template.

Establish a reusable design system containing:

- Color palette.
- Typography.
- Button styles.
- Card frame styles.
- Rarity colors.
- Modal windows.
- Tooltips.
- Notification styles.
- Progress bars.
- Currency displays.
- Loading states.
- Hover and selection effects.

All UI components should be visually consistent.

Create reusable UI components instead of independently styling every button and panel.

==================================================
3. CORE GAMEPLAY LOOP
==================================================

The main gameplay loop must be:

1. Join the game.
2. Claim a personal plot.
3. Receive starter currency and starter card packs.
4. Open packs to obtain ferret cards.
5. Discover different ferret species, personalities, rarities, and variants.
6. Place cards on display stands on the player's plot.
7. Spawn the corresponding illustrated ferrets in the world.
8. Earn passive income from displayed cards.
9. Collect accumulated earnings.
10. Purchase additional packs and upgrades.
11. Grade cards to improve their performance.
12. Complete collections and unlock rewards.
13. Expand the plot and increase display capacity.
14. Discover increasingly rare and valuable ferrets.
15. Repeat the cycle.

The first few minutes should be particularly engaging.

Players should quickly understand how to open a pack, obtain a ferret, place it on their plot, and begin earning money.

Implement a guided tutorial that introduces these mechanics naturally.

The tutorial should track completed objectives and allow players to resume if they leave the game before finishing.

==================================================
4. CARD SYSTEM
==================================================

Cards are the central collectible objects in the game.

Every card must have a unique identifier for the individual copy and a separate identifier for its card definition.

Implement a data-driven card system.

Each card definition should support fields such as:

- CardId.
- DisplayName.
- Description.
- Species.
- Rarity.
- BaseIncomePerSecond.
- BaseSellValue.
- PackPool.
- ArtworkAssetId.
- DisplayModel or display configuration.
- UnlockRequirements.
- CollectionId.
- IsLimited.
- VariantDefinitions.
- AvailableGrades.
- Tags.

Individual owned cards should additionally track:

- UniqueInstanceId.
- CardId.
- Variant.
- Grade.
- Favorite status.
- Acquisition timestamp.
- Whether the card is displayed.
- Display slot.
- Optional serial number for special collectibles.

Do not hardcode all card information inside UI scripts.

Use a centralized card registry that makes it easy to introduce new cards without rewriting gameplay systems.

The card inventory must support:

- Viewing all owned cards.
- Searching by name.
- Filtering by rarity.
- Sorting by income.
- Sorting by grade.
- Sorting by acquisition date.
- Viewing card details.
- Favoriting cards.
- Selecting cards.
- Displaying duplicate quantities.
- Selecting a card for grading.
- Selecting a card for display.
- Viewing variant information.
- Selling eligible cards.
- Inspecting cards before making decisions.

Clearly distinguish between an individual card and the number of copies owned.

When the player owns multiple copies of the same card, the inventory may group identical copies together, but it must preserve the unique data of each individual card.

==================================================
5. FERRET ARTWORK AND CARD DESIGN
==================================================

Create a diverse collection of original ferret characters.

Examples of possible card names:

COMMON:
- Sleepy Ferret
- Curious Ferret
- Little Bandit
- Snack Thief
- Tiny Explorer
- Blanket Ferret
- Sleepy Noodle
- Playful Ferret

UNCOMMON:
- Cinnamon Ferret
- Snowball Ferret
- Chocolate Ferret
- Garden Explorer
- Bubble Bath Ferret
- Strawberry Ferret

RARE:
- Astronaut Ferret
- Wizard Ferret
- Pirate Ferret
- Crystal Ferret
- Moonlight Ferret
- Rainbow Ferret

EPIC:
- Phoenix Ferret
- Galaxy Ferret
- Royal Ferret
- Shadow Ferret
- Dreamweaver Ferret

LEGENDARY:
- Celestial Ferret
- Golden Guardian Ferret
- Ancient Dragon Ferret
- Aurora Ferret

MYTHIC:
- Cosmic Emperor Ferret
- Eternal Star Ferret
- Dimension Hopper Ferret

These are initial examples, not the complete collection.

Create enough initial card definitions to make the first playable version feel varied.

Aim for at least 30 original card definitions in the initial content set, provided suitable artwork and implementation tools are available.

Do not use the same card image for every character.

Each character should have its own visual identity.

CARD ARTWORK REQUIREMENTS:

- Cute, expressive, readable silhouettes.
- Consistent illustration style.
- Transparent backgrounds where appropriate.
- Distinctive colors and accessories.
- Attractive card frames.
- Clear card names.
- Clearly visible rarity labels.
- Readable income values.
- Optional flavor text.
- Special visual treatments for rare variants.

Card artwork must remain readable at small sizes.

Use a practical asset pipeline.

If image generation or external image tools are available, create original artwork for the cards.

Otherwise, create clean placeholder illustrations using available Roblox assets, generated vector-style graphics, or simple custom geometry.

Do not pretend that final artwork exists if it has not actually been created.

Keep artwork asset references configurable so that placeholder artwork can later be replaced without changing gameplay code.

==================================================
6. RARITY SYSTEM
==================================================

Implement a rarity system with the following initial tiers:

1. Common
2. Uncommon
3. Rare
4. Epic
5. Legendary
6. Mythic
7. Secret

Each rarity should have its own:

- Color.
- Card border.
- Background treatment.
- Opening animation intensity.
- Sound effect.
- Visual particles.
- Collection value.
- Appropriate pack probabilities.

Suggested rarity colors:

Common: gray.
Uncommon: green.
Rare: blue.
Epic: purple.
Legendary: gold.
Mythic: red or magenta.
Secret: dark, luminous, and visually distinctive.

These colors should be configurable.

Card probabilities must be defined per pack, not scattered throughout scripts.

Each pack should have its own drop table.

The drop system must:

- Validate probabilities.
- Handle missing card definitions safely.
- Support weighted random selection.
- Support limited card pools.
- Support special events.
- Support variants.
- Support guaranteed rewards when explicitly configured.
- Produce deterministic results for a given random seed where practical for testing.
- Log acquisition events for debugging.

Do not make Secret cards impossible to obtain accidentally because of an incorrectly configured probability.

Add development tools that allow the developer to test pack probabilities.

Never allow the client to determine the actual card reward.

All rewards must be generated and validated on the server.

==================================================
7. CARD PACK SHOP
==================================================

Create a dedicated pack shop.

Players should be able to purchase packs using in-game currency.

Initial pack categories could include:

- Starter Pack.
- Meadow Pack.
- Woodland Pack.
- Ocean Pack.
- Adventure Pack.
- Royal Pack.
- Mythic Pack.
- Limited Event Pack.

Each pack should have:

- Name.
- Description.
- Price.
- Currency type.
- Artwork.
- Card pool.
- Rarity probabilities.
- Optional pity or guarantee mechanics.
- Stock or availability configuration.
- Limited-time availability when applicable.

The pack shop should support:

- Buying one pack.
- Buying multiple packs.
- Quantity selection.
- Purchase confirmation where appropriate.
- Inventory capacity validation.
- Clear affordability indicators.
- Purchase success notifications.
- Insufficient currency notifications.
- Restock timers where relevant.
- Limited-time packs.
- Event packs.
- Pack previews.
- Displaying possible rewards.
- Displaying reward odds.

Do not charge the player if the purchase cannot be completed.

Do not grant a pack twice because a purchase request was repeated.

Use server-side purchase validation and transaction-safe reward handling.

PACK OPENING ANIMATION:

Create a satisfying card-opening sequence.

Suggested sequence:

1. The selected pack appears in the center of the screen.
2. The background becomes softly blurred.
3. The pack performs a short animation.
4. The pack opens with particles and a sound effect.
5. The card appears.
6. The card flips to reveal its identity.
7. Rarity-specific effects play.
8. The card's name and income are revealed.
9. The player can continue opening packs.
10. The player can inspect the card or return to the shop.

For high-rarity cards, use stronger visual effects without making the interface unreadable.

Support opening multiple packs in succession.

If the player obtains several cards, provide a clean results screen showing all rewards.

Include an option to reduce or skip repeated opening animations after the player has seen them.

The reward must be granted securely by the server before the client displays the final result.

==================================================
8. PERSONAL PLOTS AND CARD DISPLAY STANDS
==================================================

Each player must have a personal plot in the shared game world.

The plot is a physical area where players can display their collected cards.

Plot requirements:

- Unique plot ownership.
- Claiming and releasing plots.
- Ownership indicators.
- Customizable decoration.
- Multiple display stands.
- Expandable capacity.
- Persistent display arrangements.
- Safe placement validation.
- A clear distinction between owned and unowned plots.
- Other players can visit and inspect plots.
- Players cannot modify another player's plot without explicit permission.

Initially, give each player a small number of display stands.

Players should unlock additional stands through progression and upgrades.

Every stand represents a displayed card.

A player should be able to:

1. Approach a stand.
2. Interact with it.
3. Select an owned card.
4. Place the card.
5. See the card displayed physically.
6. Remove or replace the card.
7. Collect income generated by the card.

Provide a clean interface for selecting cards from the inventory.

Prevent the same individual card from being displayed on multiple stands simultaneously unless a deliberate game mechanic allows it.

Validate all placement requests on the server.

Save which card is displayed on each stand.

When a player rejoins, restore their plot and display arrangement.

==================================================
9. 2D FERRET ILLUSTRATIONS IN THE 3D WORLD
==================================================

This is one of the most important features.

When a player places a card on a stand, the corresponding ferret illustration should appear above or near that stand.

The ferret should be represented by its 2D artwork inside the 3D Roblox world.

The desired visual effect is similar to a collectible illustration floating above a physical display stand.

The card itself remains a collectible object, while the illustrated ferret becomes a visible character-like decoration.

Possible implementation approaches:

- BillboardGui with an ImageLabel.
- SurfaceGui attached to a suitable display object.
- A world-space card display using a BillboardGui.
- A flat image plane with a suitable transparent texture.
- A combination of a physical card and a floating illustration.

Choose the approach that gives the best combination of visual quality, performance, and ease of maintenance.

The illustration should:

- Face the viewer where appropriate.
- Preserve its aspect ratio.
- Have a transparent background where supported.
- Display the correct ferret artwork.
- Be readable from a reasonable distance.
- Remain associated with the correct stand.
- Animate subtly.
- Respond to interactions.
- Disappear correctly when the card is removed.

ANIMATION REQUIREMENTS:

Create subtle idle animations for displayed ferrets.

Examples:

- Gentle floating.
- Small vertical bounces.
- Occasional blinking if suitable animated artwork is available.
- Slight rotation or swaying.
- Small sparkle effects for rare cards.
- Unique effects for exceptional cards.

Do not use excessive particles on every card.

The world should remain visually clear when many players have full plots.

Higher-rarity cards can receive additional effects.

For example:

Common:
A gentle idle animation.

Rare:
Subtle blue particles.

Epic:
A soft purple glow.

Legendary:
Golden sparkles.

Mythic:
A distinctive aura.

Secret:
A unique but performance-conscious visual effect.

Keep animations lightweight and configurable.

The displayed illustration must update correctly when the player changes the card assigned to a stand.

==================================================
10. PASSIVE INCOME SYSTEM
==================================================

Displayed cards generate passive income.

Every card has a base income per second.

Example:

Sleepy Ferret:
$5 per second.

Cinnamon Ferret:
$20 per second.

Crystal Ferret:
$150 per second.

Galaxy Ferret:
$1,000 per second.

These values are examples only and must be configurable.

Income depends on several factors:

- Card definition.
- Card variant.
- Card grade.
- Upgrade bonuses.
- Temporary boosts.
- Game Pass bonuses.
- Event bonuses, if applicable.

Use a centralized formula to calculate the effective income of each displayed card.

For example:

EffectiveIncome =
BaseIncome
× VariantMultiplier
× GradeMultiplier
× UpgradeMultiplier
× ApplicableBoostMultipliers

Avoid accidentally applying the same multiplier twice.

Do not calculate income independently in multiple scripts.

The server is the source of truth for currency and income.

Players should have an understandable way to collect their earnings.

Possible interaction:

Each display stand accumulates money, and the player can collect the accumulated amount by interacting with the stand.

Alternatively, provide a central collection area or a combination of both.

Choose the approach that works best for the game and implement it consistently.

Show useful information when inspecting a displayed card:

- Card name.
- Rarity.
- Grade.
- Base income.
- Effective income.
- Accumulated earnings.
- Relevant bonuses.

Add satisfying collection animations and floating currency indicators.

ECONOMY REQUIREMENTS:

- Prevent negative balances.
- Prevent duplicated payouts.
- Prevent clients from awarding themselves currency.
- Validate every transaction on the server.
- Use appropriate numeric handling.
- Avoid unnecessarily frequent DataStore writes.
- Do not award currency based on a client-reported elapsed time.
- Prevent players from collecting the same accumulated earnings twice.

Support offline earnings.

When a player returns, calculate eligible offline earnings using the saved timestamp and configured limits.

Offline income should be capped to prevent excessive inflation.

If the game supports a Game Pass that increases offline earning duration, apply it on the server.

Clearly communicate offline earning limits to the player.

==================================================
11. CARD GRADER STATION
==================================================

Implement a physical Grader Station in the game world.

The Grader is a major progression mechanic.

Players can submit an eligible card and pay an in-game currency fee.

The grading process randomly assigns a grade.

Possible grades:

Grade 1
Grade 2
Grade 3
Grade 4
Grade 5
Grade 6
Grade 7
Grade 8
Grade 9
Grade 10

Higher grades increase the card's effective income and collectible value.

The station should have an attractive interface.

The interface should display:

- Selected card.
- Current grade, if already graded.
- Grading cost.
- Possible grades.
- Grade probabilities.
- Estimated income at each grade.
- Current card value.
- Expected result information.
- A Roll or Grade button.
- A button to inspect or change the selected card.
- A visible grading animation.

The player should understand the risk before confirming the operation.

GRADING MECHANICS:

The grading result should be determined by the server.

The client may display the animation, but it must never decide the final grade.

Use configurable probability tables.

For example, a grading system may make high grades progressively harder to obtain.

The exact probabilities should be defined in configuration files.

Support different grading rules for different card categories if necessary.

The system should allow future additions such as:

- Better grading machines.
- Reduced grading fees.
- Special grading events.
- Lucky grading boosts.
- Grade protection.
- Special cosmetic grading labels.

These features must not make the initial implementation unnecessarily complicated.

GRADE EFFECTS:

A higher grade should increase:

- Passive income.
- Estimated collectible value.
- Card prestige.
- Potential trading desirability.

Use a centralized grade multiplier table.

For example:

Grade 1: 0.8x
Grade 2: 0.9x
Grade 3: 1.0x
Grade 4: 1.1x
Grade 5: 1.2x
Grade 6: 1.4x
Grade 7: 1.7x
Grade 8: 2.1x
Grade 9: 2.7x
Grade 10: 3.5x

These are initial balance suggestions, not mandatory final values.

The economy must be tested and adjusted so that grading remains useful without making normal progression irrelevant.

IMPORTANT:

A grading operation must be atomic from the perspective of the player.

If the player cannot afford the fee, the operation must not proceed.

If the card is not owned by the player, the operation must not proceed.

If the card is currently displayed and the grading rules prohibit grading displayed cards, require the player to remove it first.

Prevent duplicate grading requests from charging the player multiple times or granting multiple results.

Persist the resulting grade.

Do not allow a player to reroll a grade for free by leaving and rejoining.

==================================================
12. CARD VARIANTS
==================================================

Support special variants of individual cards.

Possible variants:

- Normal.
- Gold.
- Rainbow.
- Shiny.
- Holographic.
- Crystal.
- Shadow.
- Prismatic.
- Limited Edition.

Not every card needs every variant.

Variants should affect appearance and may affect income or collectible value.

For example:

Normal:
Standard artwork.

Gold:
Gold frame and subtle shine.

Rainbow:
Animated rainbow accents.

Holographic:
A shifting holographic overlay.

Crystal:
Crystalline highlights.

Shadow:
Darkened artwork with a distinctive aura.

Variants should be implemented through data-driven configuration.

Avoid creating an entirely separate card definition for every combination of card and variant unless there is a strong technical reason.

Keep the number of combinations manageable.

Make it possible to add new variants without rewriting the inventory, display, or grading systems.

==================================================
13. BINDERS AND COLLECTION COMPLETION
==================================================

Implement a Binder system for themed collections.

A Binder represents a collection of related cards.

Example binders:

- Woodland Friends.
- Tiny Explorers.
- Royal Ferrets.
- Cosmic Companions.
- Sweet Treats.
- Ocean Adventures.
- Legendary Legends.
- Seasonal Wonders.

Each Binder contains a list of required card definitions.

The Binder interface should display:

- Binder name.
- Binder artwork.
- Completion percentage.
- Number of discovered cards.
- Total required cards.
- Missing cards.
- Completed cards.
- Rewards.
- Collection bonuses.

Players should be rewarded for discovering new cards and completing collections.

Possible rewards:

- Cash.
- Exclusive card packs.
- Special card variants.
- Cosmetic plot decorations.
- Titles.
- Badges.
- Permanent income bonuses.
- Additional display slots.

Collection rewards must be granted only once unless the design explicitly supports repeatable rewards.

The server must validate completion.

Persist collection progress.

Provide a global collection interface and individual Binder pages.

Add filters for:

- Completed collections.
- Incomplete collections.
- Recently discovered cards.
- Rare collections.

When a player obtains a new card, update the relevant Binder progress and show a notification if appropriate.

==================================================
14. PLAYER INVENTORY AND BACKPACK
==================================================

Create a polished Backpack interface.

The interface should include:

- Search bar.
- Card grid.
- Card previews.
- Rarity indicators.
- Card counts.
- Income values.
- Grade indicators.
- Variant indicators.
- Sorting controls.
- Filtering controls.
- Favorite functionality.
- Card inspection panel.

Support keyboard, mouse, and touch interaction.

The inventory must work at different screen resolutions.

Do not create an interface that only works at one fixed desktop resolution.

Use responsive UI constraints and appropriate scaling.

Large collections must not require loading every card into the interface simultaneously.

Use efficient rendering and pagination or scrolling.

The interface should distinguish between:

- Owned cards.
- Displayed cards.
- Favorite cards.
- Cards that can be graded.
- Cards that can be sold.
- Cards needed for a collection.

If a card cannot be sold or modified for a specific reason, explain why.

==================================================
15. UPGRADES
==================================================

Create an upgrade system.

Players spend in-game currency to permanently improve their progression.

Initial upgrades:

1. Cash Multiplier.
2. Plot Capacity.
3. Offline Earnings.
4. Card Display Capacity.
5. Grading Discount.
6. Pack Luck.
7. Income Collection Radius.
8. Inventory Capacity.
9. Automatic Collection.
10. Pack Opening Speed.

Each upgrade should have:

- Unique ID.
- Display name.
- Description.
- Current level.
- Maximum level where applicable.
- Base cost.
- Cost scaling formula.
- Effect per level.
- Purchase validation.
- UI representation.

Use configurable formulas for upgrade costs.

For example:

NextCost = BaseCost × CostMultiplier ^ CurrentLevel

The formula must be centralized and tested.

Prevent players from purchasing an upgrade beyond its maximum level.

Do not allow negative upgrade levels.

The client should request an upgrade purchase, but the server must validate the price and apply the result.

Persist upgrade levels.

Make upgrade progression satisfying without allowing one upgrade to trivialize the entire game.

==================================================
16. BOOSTS AND TEMPORARY POWER-UPS
==================================================

Create a Boosts interface.

Initial boosts:

- Luck Boost.
- Super Luck Boost.
- Cash Boost.
- Shiny Boost.
- Grading Boost.
- Speed Boost.

Each boost should have:

- Duration.
- Effect.
- Source.
- Activation requirements.
- Optional stacking rules.
- Remaining time.

Boosts may be obtained through:

- Gameplay.
- Daily rewards.
- Quests.
- Events.
- Special packs.
- Eligible purchases.

The UI should show active boosts and their remaining durations.

Use server-authoritative timing.

A client must not be able to extend a boost by changing its local clock.

Define how boosts interact with permanent upgrades and other boosts.

Avoid accidental multiplicative stacking that makes the economy explode.

When a boost expires, immediately stop applying its effect.

Persist boost state only when appropriate.

==================================================
17. DAILY REWARDS AND QUESTS
==================================================

Create a Daily Rewards system.

Players should be encouraged to return without being forced to play for excessive periods.

Possible daily rewards:

- Cash.
- Free packs.
- Boosts.
- Special event currency.
- Cosmetic items.
- Exclusive cards.

Support a configurable reward sequence.

Prevent duplicate claims.

Use server-validated claim timestamps.

Handle players in different time zones consistently.

Create a Quest system with objectives such as:

- Open 5 packs.
- Discover 3 new cards.
- Display 4 cards.
- Collect $10,000.
- Grade a card.
- Complete a Binder.
- Purchase an upgrade.
- Collect earnings from displayed cards.

Quests should have:

- Quest ID.
- Description.
- Objective.
- Progress.
- Reward.
- Completion state.
- Claim state.
- Optional expiration.

Quest progress must be updated by trusted server-side gameplay events.

Do not rely on a client telling the server that a quest is complete.

Add notifications when quests are completed.

==================================================
18. GAME WORLD AND SOCIAL HUB
==================================================

Create a colorful, welcoming game world.

The world should contain recognizable areas.

Suggested locations:

- Spawn Plaza.
- Pack Shop.
- Grader Station.
- Trading Plaza.
- Upgrade Station.
- Daily Rewards Area.
- Event Area.
- Leaderboard Area.
- Player Plots.
- Collection Hall.

Use clear signs and recognizable visual landmarks.

Players should be able to navigate without constantly opening menus.

Add interactive NPCs or stations where useful.

The world should feel alive, but avoid unnecessary complexity in the first playable version.

Provide an attractive spawn area where new players can immediately understand the game's purpose.

PLOTS:

Plots should be arranged so players can visit one another.

Each plot should show:

- Owner name.
- Displayed cards.
- Income indicators where appropriate.
- Plot decorations.
- Collection or prestige indicators.

Players may inspect another player's cards.

However, visiting another plot must never allow unauthorized modifications.

Add a way to return quickly to the player's own plot.

==================================================
19. SELLING CARDS
==================================================

Implement an optional card-selling system.

Players may sell eligible cards in exchange for in-game currency.

The selling interface should display:

- Card name.
- Rarity.
- Grade.
- Variant.
- Estimated sale value.
- Confirmation before selling valuable cards.

Cards currently displayed should be handled safely.

Cards that are required for an active operation must not be deleted while the operation is in progress.

Prevent duplicate sale requests.

Do not let the client determine the sale value.

Use a centralized card valuation function.

The value may depend on:

- Base value.
- Rarity.
- Variant.
- Grade.
- Limited status.
- Other explicitly configured factors.

Make it possible to protect favorite cards from accidental sale.

Bulk selling may be implemented later.

The first version should prioritize safety and clarity.

==================================================
20. TRADING SYSTEM
==================================================

Trading is an important potential social feature.

Implement it after the core collection, persistence, and economy systems are stable.

Players should be able to initiate trades with other players.

A trade may include eligible cards and, if the economy design supports it, in-game currency.

The trade interface should show both players' proposed items.

Required safeguards:

- Both players must explicitly accept.
- Both players must confirm the final trade.
- Any change to the offer invalidates previous confirmations.
- Both players must still own the offered items.
- Cards cannot be traded if already locked by another operation.
- The server must validate every item.
- The exchange must be atomic.
- A failed trade must not destroy items or currency.
- A player cannot accept a modified trade without seeing the changes.

Add trade request cancellation and timeout handling.

Prevent duplicated trades and item duplication exploits.

Trading must not be implemented by trusting client-reported inventories.

If a fully secure trading system would delay the first playable version, implement the architecture and UI later rather than rushing an insecure version.

==================================================
21. LEADERBOARDS AND ACHIEVEMENTS
==================================================

Create leaderboards for:

- Total Cash Earned.
- Current Income Per Second.
- Cards Discovered.
- Binder Completion.
- Highest Card Grade.
- Rare Cards Collected.

Use Roblox's appropriate leaderboard and persistence services where suitable.

Do not trust client-reported leaderboard values.

Add achievements for meaningful milestones.

Examples:

- First Pack Opened.
- First Ferret Displayed.
- First Rare Card.
- First Grade 10.
- First Completed Binder.
- 100 Cards Collected.
- Millionaire.
- Collector Extraordinaire.

Achievements may grant cash, cosmetics, titles, or other rewards.

Avoid granting the same reward repeatedly because of duplicate events.

==================================================
22. LIMITED-TIME EVENTS
==================================================

Design the game so that seasonal content can be added easily.

Examples:

- Autumn Ferrets.
- Winter Wonderland.
- Spring Garden.
- Summer Adventure.
- Halloween Shadows.
- Lunar Festival.

Each event may introduce:

- Event packs.
- Exclusive cards.
- Special variants.
- Event currency.
- Limited quests.
- Event decorations.
- Temporary boosts.
- Collection rewards.

Use configurable start and end times.

The server must determine whether an event is active.

Limited-time cards should have clear acquisition rules.

Do not delete previously earned cards when an event ends.

Design the event system so new content can be added through configuration rather than extensive code changes.

==================================================
23. ROBUX MONETIZATION
==================================================

Create a professional in-game store where players can spend Robux.

Monetization should be optional.

The free progression path must remain playable and enjoyable.

Do not create a system that makes spending Robux mandatory.

Potential GAME PASSES:

- VIP Membership.
- Extra Plot Slots.
- Increased AFK Earnings.
- Additional Inventory Capacity.
- Faster Pack Opening.
- Extra Display Capacity.
- Convenient Auto-Collection.
- Exclusive Plot Decorations.

Potential DEVELOPER PRODUCTS:

- Small Cash Bundle.
- Medium Cash Bundle.
- Large Cash Bundle.
- Temporary Luck Boost.
- Temporary Cash Boost.
- Special Cosmetic Bundle.
- Other appropriately designed consumable purchases.

These are possible features, not a requirement to implement every item immediately.

Use configurable product IDs.

Never invent real product IDs.

Use placeholders until actual Roblox Marketplace IDs are configured.

Implement purchases using Roblox's supported MarketplaceService APIs.

DEVELOPER PRODUCTS:

Process purchases through ProcessReceipt.

Grant each purchase safely and idempotently.

Do not grant the same purchase repeatedly if Roblox retries the receipt.

Persist sufficient transaction state to prevent duplicate rewards.

Do not treat a client-side purchase success message as proof of payment.

GAME PASSES:

Use the supported ownership verification APIs.

Apply benefits on the server.

Make it possible to configure benefits without rewriting the entire game.

STORE UI:

Include:

- Product icon.
- Product name.
- Description.
- Price.
- Benefits.
- Purchase button.
- Purchase confirmation or appropriate feedback.
- Successful purchase notification.
- Error handling.

Clearly separate free rewards from paid purchases.

For paid randomized rewards, follow current Roblox policies, including applicable odds disclosure and regional restrictions.

Do not sell randomized rewards through an implementation that violates Roblox's current rules.

If a mechanic is restricted, replace it with a compliant alternative.

Do not promise that a player will receive a specific randomized reward unless the product explicitly guarantees it.

==================================================
24. UI AND USER EXPERIENCE
==================================================

Create a polished, cohesive interface.

The primary interface should include:

TOP AREA:
- Cash display.
- Current income per second.
- Relevant currencies.
- Pack Shop.
- Plot.
- Optional event indicator.

SIDE NAVIGATION:
- Backpack.
- Binders.
- Grader.
- Upgrades.
- Boosts.
- Shop.
- Quests.
- Settings.

CONTEXTUAL UI:
- Card selection.
- Pack opening.
- Plot placement.
- Card inspection.
- Grading.
- Collection rewards.
- Trading.
- Purchase confirmation.

Do not display every panel simultaneously.

Use contextual navigation and well-organized modal windows.

The UI should support:

- Desktop.
- Mobile.
- Tablet.
- Different aspect ratios.
- Mouse interaction.
- Touch interaction.
- Appropriate keyboard shortcuts.

Use Roblox's standard responsive UI tools.

Important design principles:

- Large, readable buttons.
- Clear feedback.
- Smooth transitions.
- Short animations.
- Consistent spacing.
- Appropriate contrast.
- Accessible text sizes.
- Clear error messages.
- Minimal unnecessary clicking.

Add a settings panel with options such as:

- Music volume.
- Sound effects volume.
- Reduced visual effects.
- Reduced screen shake.
- Animation skipping.
- Interface scale where appropriate.

Avoid excessive blur and particles that could make the game uncomfortable or reduce performance.

==================================================
25. AUDIO AND VISUAL FEEDBACK
==================================================

Add audio and visual feedback for important actions.

Examples:

- Opening a pack.
- Revealing a card.
- Obtaining a rare card.
- Collecting income.
- Buying an upgrade.
- Completing a collection.
- Grading a card.
- Receiving a reward.
- Completing a quest.

Use original or appropriately licensed assets.

Keep audio references configurable.

Do not invent asset IDs or assume that an arbitrary Roblox asset is available.

If audio assets are unavailable, implement the sound system with placeholders and document how to configure it.

Provide reduced-effects settings.

==================================================
26. TECHNICAL ARCHITECTURE
==================================================

Implement the game using Roblox Studio and Luau.

Use clean, modular, maintainable code.

Separate server logic, client logic, shared modules, configuration, and UI.

Suggested architecture:

ReplicatedStorage
    Shared
        Config
            GameConfig
            EconomyConfig
            RarityConfig
            PackConfig
            GradingConfig
            UpgradeConfig
            MonetizationConfig
        Modules
            CardDefinitions
            CardUtils
            IncomeCalculator
            GradeUtils
            PackUtils
            CollectionUtils
        Remotes
            RemoteEvents and RemoteFunctions as required

ServerScriptService
    Services
        PlayerDataService
        InventoryService
        PlotService
        PackService
        IncomeService
        GradingService
        UpgradeService
        CollectionService
        QuestService
        DailyRewardService
        BoostService
        TradingService
        MonetizationService
        LeaderboardService
    Main.server.lua

StarterPlayer
    StarterPlayerScripts
        Controllers
            UIController
            InventoryController
            PackOpeningController
            PlotController
            GraderController
            NotificationController

StarterGui
    MainUI
        HUD
        Inventory
        PackShop
        CardDetails
        Grader
        Binders
        Upgrades
        Boosts
        Quests
        DailyRewards
        Store
        Settings

Workspace
    Plots
    Stations
    SpawnArea
    WorldObjects

This structure is a recommendation, not a reason to create empty folders that are never used.

Adapt the architecture to the available project and development workflow.

Use ModuleScripts for reusable logic.

Keep shared configuration separate from sensitive server-only logic.

Do not place authoritative economy logic inside LocalScripts.

Do not allow clients to directly modify server-owned data.

==================================================
27. SERVER AUTHORITY AND SECURITY
==================================================

Security is mandatory.

The server must control:

- Player currency.
- Card ownership.
- Pack rewards.
- Card grades.
- Card variants.
- Income generation.
- Display placement.
- Upgrade purchases.
- Collection rewards.
- Daily rewards.
- Boost activation.
- Selling.
- Trading.
- Paid purchase rewards.
- Persistent progression.

The client may request actions, but the server must validate them.

Validate all RemoteEvent and RemoteFunction inputs.

Check:

- Player ownership.
- Valid identifiers.
- Valid quantities.
- Available currency.
- Inventory capacity.
- Plot ownership.
- Card availability.
- Operation state.
- Request frequency.
- Transaction uniqueness.

Implement rate limiting for important remote operations.

Avoid expensive server work on every client request.

Never trust client-provided prices, grades, card definitions, or income values.

Do not expose server secrets or sensitive internal state to the client.

Avoid remote interfaces that allow arbitrary instance paths or arbitrary function execution.

All player-facing actions should fail safely.

Log important errors and suspicious requests in a way that helps development without unnecessarily flooding the output.

==================================================
28. DATA PERSISTENCE
==================================================

Implement persistent player data using Roblox DataStoreService.

Player data should include:

- Currency.
- Owned card instances.
- Display arrangements.
- Plot upgrades.
- Other upgrades.
- Binder progress.
- Discovered cards.
- Daily reward state.
- Quest progress.
- Eligible active boosts.
- Settings.
- Relevant progression statistics.
- Last eligible offline-income timestamp.
- Data schema version.

Persist data carefully.

Requirements:

- Use protected calls.
- Handle temporary DataStore failures.
- Avoid excessive requests.
- Use appropriate update patterns.
- Support session-safe saving.
- Save periodically.
- Save when the player leaves.
- Handle server shutdown.
- Prevent concurrent sessions from overwriting newer data where practical.
- Use a schema version.
- Support data migration.
- Provide a safe loading state.
- Avoid granting default rewards multiple times.

Do not overwrite existing player data with an empty default profile because a load operation failed.

If player data cannot be loaded safely, prevent the player from entering a state where their progress could be overwritten.

Use a session-locking approach appropriate to the implementation.

Use UpdateAsync or another appropriate pattern for critical persistence operations.

Do not assume that PlayerRemoving or BindToClose alone guarantees that every save succeeds.

Add useful diagnostic logging.

==================================================
29. PERFORMANCE AND SCALABILITY
==================================================

The game should support multiple players in one server.

Optimize:

- Displayed card illustrations.
- Particle effects.
- UI updates.
- Income calculations.
- DataStore usage.
- Remote communication.
- World object creation.
- Inventory rendering.

Do not run an independent high-frequency loop for every card if a centralized scheduler would work better.

Use sensible update intervals.

Avoid repeatedly rebuilding entire interfaces when only one value changes.

Use events and cached values where appropriate.

Limit visual effects for distant plots.

Clean up temporary objects when players leave or cards are removed.

Avoid memory leaks caused by unremoved event connections.

Consider streaming and world organization where useful.

The game should remain usable on lower-end devices.

==================================================
30. DEVELOPMENT AND TESTING
==================================================

Before implementation, inspect the existing repository and available tools.

Determine how the project connects to Roblox Studio.

Possible workflows may involve:

- Roblox Studio.
- Rojo.
- Luau source files.
- Git.
- Available Roblox development tools.

Do not assume that a tool is installed.

If Rojo is available, configure a suitable project structure and mapping.

If direct Roblox Studio integration is available, use it appropriately.

If a tool is unavailable, explain the limitation and choose a practical alternative.

Do not claim that a feature has been tested inside Roblox Studio unless it actually has been.

Create a clear development workflow.

Implement the game in phases.

PHASE 1: FOUNDATION

- Project inspection.
- Folder structure.
- Game configuration.
- Card definitions.
- Player data model.
- Server-client communication.
- Basic HUD.
- Starter rewards.

PHASE 2: CORE GAMEPLAY

- Card pack purchasing.
- Pack opening.
- Card rewards.
- Inventory.
- Plot claiming.
- Card display stands.
- 2D ferret illustrations.
- Passive income.

PHASE 3: PROGRESSION

- Grader station.
- Grades.
- Variants.
- Upgrades.
- Binders.
- Collection rewards.
- Card selling.

PHASE 4: RETENTION

- Daily rewards.
- Quests.
- Boosts.
- Achievements.
- Leaderboards.
- Limited-time events.

PHASE 5: SOCIAL FEATURES

- Visiting plots.
- Plot customization.
- Trading.
- Social collection features.

PHASE 6: MONETIZATION

- Game Passes.
- Developer Products.
- Store UI.
- Receipt processing.
- Purchase validation.

PHASE 7: POLISH

- Visual effects.
- Audio.
- Responsive UI.
- Tutorials.
- Performance optimization.
- Exploit prevention.
- Final testing.

The phases may overlap when appropriate, but preserve the dependency order.

Do not attempt to implement all features in one enormous script.

Build complete, testable systems.

==================================================
31. TESTING REQUIREMENTS
==================================================

Create tests for important gameplay logic wherever the available environment permits.

At minimum, test:

CARD SYSTEM:
- Every configured card has a valid identifier.
- Every configured card references valid rarity data.
- Every pack references valid cards.
- Every variant has valid configuration.

PACK SYSTEM:
- Purchasing a pack deducts the correct currency.
- A failed purchase does not deduct currency.
- The server grants exactly the intended reward.
- Invalid pack IDs are rejected.
- Repeated requests do not grant duplicate rewards.

INVENTORY:
- Cards receive unique instance IDs.
- Duplicate cards are handled correctly.
- Inventory capacity is enforced.
- Invalid card references are rejected.

PLOTS:
- A player cannot modify another player's plot.
- A card cannot be displayed twice unintentionally.
- Removing a card updates the display.
- Plot arrangements can be restored after rejoining.

INCOME:
- Income calculations use the correct multipliers.
- Income is not accidentally duplicated.
- Collection cannot be exploited.
- Offline income respects configured limits.

GRADING:
- Fees are correct.
- Insufficient funds prevent grading.
- Grades are generated on the server.
- Invalid cards are rejected.
- Results persist correctly.

UPGRADES:
- Costs scale correctly.
- Maximum levels are enforced.
- Purchases deduct currency exactly once.

PERSISTENCE:
- Player data loads correctly.
- Saving preserves card instances.
- Temporary DataStore failures are handled.
- Existing data is not replaced with empty defaults after a failed load.

MONETIZATION:
- Invalid purchase requests grant nothing.
- Developer Product receipts are processed idempotently.
- Product benefits are applied on the server.

TRADING:
- Players cannot trade cards they do not own.
- Changed offers invalidate old confirmations.
- A failed trade does not destroy items.

Create a development-only testing mode with useful commands or utilities where practical.

Development tools must not be exploitable in production.

==================================================
32. INITIAL BALANCING
==================================================

Create a coherent initial economy.

Example starting values:

Starting Cash: $500.

Starter Pack: $100.

Basic display stand: Free.

Additional display stand: Progression-based cost.

Common card income: Approximately $2–$10 per second.

Uncommon card income: Approximately $10–$30 per second.

Rare card income: Approximately $30–$100 per second.

Epic card income: Approximately $100–$300 per second.

Legendary card income: Approximately $300–$1,000 per second.

Mythic card income: Higher, according to rarity and balance.

Secret card income: Exceptional, but configurable.

These values are initial guidelines, not rigid requirements.

Balance the economy around:

- Pack prices.
- Card probabilities.
- Income generation.
- Number of display stands.
- Upgrade costs.
- Offline earnings.
- Selling values.
- Grading costs.
- Variant multipliers.
- Progression speed.

Avoid an economy where the player immediately becomes rich after opening one ordinary pack.

Also avoid an economy where progress becomes so slow that the game feels broken.

The first ten minutes should offer frequent, satisfying progression.

Later progression should require meaningful decisions and collection improvements.

Add developer-only balance tools so values can be adjusted without rewriting core gameplay logic.

==================================================
33. REQUIRED DELIVERABLES
==================================================

By the end of the implementation, provide:

1. A working project structure.
2. Core Luau scripts.
3. Reusable shared modules.
4. Configuration files.
5. Player data persistence.
6. A functional card pack system.
7. A functional card inventory.
8. Personal plots and display stands.
9. 2D ferret illustrations displayed in the world.
10. Passive income generation.
11. A functional Grader Station.
12. Card grades and variants.
13. Binder collections.
14. Upgrade systems.
15. Basic quests and daily rewards.
16. A configurable monetization framework.
17. Tests for important game mechanics.
18. A README with setup instructions.
19. An explanation of how to run the game in Roblox Studio.
20. A list of remaining tasks and known limitations.

Also include:

- A card creation guide.
- A pack configuration guide.
- A grading configuration guide.
- A monetization configuration guide.
- A DataStore testing guide.
- Instructions for adding new artwork.
- Instructions for adding new cards.
- Instructions for adding new collection sets.

Create a development changelog.

Document completed features and important architectural decisions.

Do not mark unfinished features as complete.

==================================================
34. IMPLEMENTATION WORKFLOW
==================================================

Follow this workflow.

STEP 1:
Inspect the current project and determine what already exists.

STEP 2:
Identify the available Roblox development tools and execution environment.

STEP 3:
Create an implementation plan with dependencies and priorities.

STEP 4:
Establish the project architecture and shared configuration.

STEP 5:
Implement the minimum complete gameplay loop.

STEP 6:
Test the core loop and fix discovered issues.

STEP 7:
Implement grading, upgrades, collections, and additional progression.

STEP 8:
Implement retention systems and monetization.

STEP 9:
Polish the UI and visual presentation.

STEP 10:
Perform a final review of security, persistence, performance, and documentation.

Work autonomously through these steps.

Do not stop after presenting the plan.

Do not repeatedly ask me to approve minor implementation details.

Make sensible decisions when information is missing.

If an essential dependency blocks progress, explain the issue and continue with any independent tasks that can be completed.

If you encounter a bug, investigate and fix it rather than merely describing it.

If you cannot execute the game directly, use all available static checks and tests, and clearly explain what still requires verification in Roblox Studio.

After completing each major phase:

- Summarize what was implemented.
- List important files changed.
- Report tests performed.
- Identify remaining limitations.
- Continue to the next phase where possible.

==================================================
35. IMPORTANT DESIGN PRINCIPLES
==================================================

Keep these principles in mind throughout development.

1. GAMEPLAY FIRST

The core loop must work before the game receives elaborate visual polish.

2. DATA-DRIVEN DESIGN

Cards, packs, rarities, grades, variants, and upgrades must be configurable.

3. SERVER AUTHORITY

The server controls rewards, currency, card ownership, grades, and progression.

4. POLISHED PRESENTATION

The game should feel intentional, colorful, and satisfying.

5. ORIGINALITY

Create original ferret characters and an identity distinct from existing games.

6. PERFORMANCE

The game must remain responsive with multiple players and many displayed cards.

7. EXTENSIBILITY

Future updates should not require rewriting core systems.

8. FAIR PROGRESSION

Free players must have a meaningful progression path.

9. CLEAR FEEDBACK

Players must understand what happened after every important action.

10. ACTUAL IMPLEMENTATION

Do not substitute documentation for implementation when implementation is possible.

==================================================
36. FINAL OBJECTIVE
==================================================

Build a polished, extensible Roblox game where players collect adorable ferrets on cards, open packs, display their cards on personal plots, watch illustrated ferrets animate in the 3D world, generate passive income, grade cards, complete collections, unlock upgrades, and optionally purchase convenience or cosmetic features using Robux.

The experience should be immediately understandable to new players while providing enough depth for long-term collectors.

The most important feature is the combination of collectible card artwork, visible 2D ferret illustrations in the world, passive income, and the exciting possibility of obtaining and grading rare cards.

Start by inspecting the project and preparing the implementation plan.

Then begin building the actual game.

Do not finish with only a plan or a conceptual prototype.
