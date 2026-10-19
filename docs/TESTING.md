# Testing strategy

Roblox Studio cannot run in CI or in the Linux cloud container, because it only runs on
Windows and macOS. Testing is therefore split into layers. Each layer says **where it
runs**, so any claim that tests passed names the layer it refers to.

| Layer | Tool | Runs in | What it proves |
| --- | --- | --- | --- |
| Format | StyLua | CI, cloud, local | Consistent code style |
| Lint | Selene (`std = "roblox"`) | CI, local. In the cloud: offline approximation (below) | Common Luau and Roblox mistakes |
| Build | `rojo build` | CI, cloud, local | The project maps to a valid place file |
| Type check | luau-lsp 1.70 `analyze`, strict, with Roblox API definitions | CI, cloud, local | Type errors, wrong API usage, `require` resolution |
| Unit tests | Lune (`tests/unit`) | CI, cloud, local | Pure game rules, config validity, persistence safety rules |
| Place structure | Lune `@lune/roblox` (`tests/build`) | CI, cloud, local | The built `.rbxl` has the expected scripts and modules |
| Play tests | Roblox Studio | **Local only** (manual) | Runtime behaviour: DataStores, remotes, UI, multiplayer |

Run all the automated layers with `./scripts/check.sh`. In the cloud, use
`SKIP_SELENE_IF_OFFLINE=1 ./scripts/check.sh`.

## How Roblox-style modules are tested under Lune

Source modules use Roblox requires, for example `require(script.Parent.Foo)` and
`game:GetService("ReplicatedStorage").Shared`. `tests/Loader.luau` emulates exactly that,
following Rojo's file-mapping rules:

- `Foo.luau` maps to a ModuleScript named `Foo`.
- `Foo/init.luau` maps to a ModuleScript named `Foo` whose children are the other files in
  the folder.
- A folder without an `init` file maps to a Folder.

It also injects `Color3` from `@lune/roblox`. Specs load modules by path:

```lua
local Economy = Loader.require("src/shared/Logic/Economy")
```

Only modules that avoid live Roblox services can be loaded this way. That is why the
gameplay rules (`src/shared/Logic`) and the persistence core
(`src/server/Lib/SessionStore.luau`) are written as pure modules. Services are thin wiring
on top of them.

## Persistence safety tests

`tests/unit/SessionStore.spec.luau` runs the real SessionStore against
`server/Lib/MockDataStore.luau`, with two simulated servers and a controllable clock. It
covers:

- Defaults are created only for genuinely new keys.
- A live lock held by another server blocks loading, and nothing is written.
- An expired lock (from a crashed server) can be taken over.
- A server that lost its lock can never overwrite the new owner's data.
- Transient errors are retried, and persistent errors **never** fall back to defaults.
- Data from a newer schema and malformed records are rejected and left untouched.
- The starter-reward flag persists across sessions.

Three key rules were mutation-checked: each one, deliberately broken, makes the tests fail.
These tests do **not** prove behaviour against the real DataStoreService. That still needs
the Studio checks below.

## Cloud limitation: Selene

Selene builds its Roblox std from the API dump on `setup.rbxcdn.com`, which the cloud
network blocks. With `SKIP_SELENE_IF_OFFLINE=1`, `check.sh` falls back to
`scripts/selene-offline/roblox_lite.yml`. That std accepts the Roblox globals but doesn't
check their members, so every other lint still runs. CI on GitHub Actions has full network
access and uses the real std.

## Economy simulation

`lune run scripts/simulate [hours]` plays a simple greedy strategy (save for the best
unlocked pack, Place Best, buy upgrades that pay back within 60 seconds) against the real
Config and Logic modules. It prints when each pack unlocks and how income grows. Use it
after changing prices or curves. It is a pacing aid, not a pass/fail test.

## Writing tests

- Put Roblox-free logic in `src/shared/...` and add `tests/unit/<Name>.spec.luau`, using
  `describe`, `it` and `expect` from `tests/TestKit.luau`. The matchers are `toBe`,
  `toEqual`, `toBeNear`, `toBeNil`, `toBeGreaterThan`, `toBeLessThan` and `toThrow`.
- Inject randomness (`roll` functions) and time (`clock`) so results are deterministic.
- Add new top-level scripts or modules to `tests/build/VerifyPlace.spec.luau`.

## Roblox Studio test checklist

**No item below has been run yet.** Studio is unavailable in the cloud environment.

- Tick an item only after you have actually run it in Studio.
- Record the date, Studio version and results in DEVLOG.md.
- Requirement ids (§n) refer to [SPEC.md](SPEC.md); conflict ids (C#) refer to
  [STATUS.md](STATUS.md).

The checklist has two parts:

- **Part 1** tests what exists today.
- **Part 2** is written ahead of time for features on the [roadmap](ROADMAP.md). Run each
  block when its feature lands, and keep it as a regression test afterwards.

### How to run Studio tests

1. Run `rojo serve`, open a place in Studio, and connect the Rojo plugin.
2. **Test place for saving:** use a separate, unpublished-to-players place. Turn on *Game
   Settings → Security → Enable Studio Access to API Services*. Never point tests at a
   production place.
3. **Single-player:** press **Play** (F5).
4. **Multiplayer:** choose *Test → Clients and Servers*, with 2 players. Each client and the
   server get their own Output window.
5. **Client command bar** (for exploit probes): in a client window, open *View → Command
   Bar*. Code typed there runs as that client, which is exactly what an exploiter can do.
6. **Device emulation:** *Test → Device* (phone, tablet).

## Part 1: what exists today

### 1.1 Setup and startup
- [ ] `rojo serve` connects, and the Explorer shows `ServerScriptService.Server`,
      `ReplicatedStorage.Shared` and `StarterPlayerScripts.Client` as in
      `default.project.json`.
- [ ] Play: the Output shows `[Server] Ferret Card Tycoon started (N services)` with **no**
      `[Config]` warnings and no errors.
- [ ] The Studio "Baseplate" template's floor and SpawnLocation are removed at runtime, and
      the generated world appears (`Workspace.World`, `Workspace.Plots`).
- [ ] `ReplicatedStorage.Remotes` contains every name listed in `Shared/Remotes.luau`.

### 1.2 Persistence: mock store (API access OFF)
- [ ] Output warns that DataStores are unavailable and the in-memory store is in use, and a
      "Studio test mode" toast appears.
- [ ] Stop and Play again: progress resets. This is expected, and proves the mock store
      never touches real data.

### 1.3 Persistence: real DataStore (API access ON, test place)
- [ ] First join: welcome toast; 500 cash; 3 Pack 1 packs owned (PACKS window shows
      "OPEN (3)"); no cards yet; HUD shows +0 CASH/S and NOTHING TO COLLECT; you spawn on
      your own plot.
- [ ] Open a pack, buy a pack (keep it unopened), place a card, let a stand accumulate,
      buy an upgrade, change a setting, then Stop. Play again: cards, unopened packs,
      stands, uncollected stand earnings, upgrade levels, cash, settings and level all
      persist, and **no**
      second welcome toast or starter grant appears.
- [ ] Leave and rejoin within a few seconds (Clients and Servers: close a client, then add
      a player): the data loads. The Output may show "locked by another server, retrying"
      before it succeeds.
- [ ] Shutdown save: make a change, wait less than 90 s (before the autosave), then press
      Stop. On the next Play the change is still there (saved by BindToClose).
- [ ] Simulated failure (optional): temporarily set `Config.Game.Data.StoreName` to an
      invalid name, or turn API access off mid-session. A failed load must **kick** the
      player with a message, never start them with empty data.

### 1.4 Security probes (client command bar, Clients and Servers)

Paste these into a **client** command bar. Every probe must fail safely: `ok == false`,
nothing changes, and the server Output shows at most a `[Net]` warning.

```lua
local R = game.ReplicatedStorage.Remotes
local function try(name, ...) local r = R[name]:InvokeServer(...) print(name, r.ok, r.error) end
try("BuyPack", "midnight_pack", 1)          -- locked pack: refused with a reason
try("OpenPack", "snack_pack", 1)           -- a pack you don't own: refused
try("OpenPack", "burrow_pack", 99)         -- more than you own / over the limit: refused
try("CollectEarnings", 0)                   -- legitimate: collects whatever is pending
try("CollectEarnings", 0)                   -- immediately again: collected = 0 (no double payout)
try("CollectEarnings", -1)                  -- invalid slot
try("BuyPack", "burrow_pack", 0)            -- invalid amount
try("BuyPack", "burrow_pack", 1/0)          -- infinity rejected
try("BuyPack", "burrow_pack", 1, "extra")   -- extra argument rejected
try("BuyPack", "does_not_exist", 1)         -- unknown pack
try("SellCards", { "999999-1" })            -- card you don't own
try("SellCards", {})                        -- empty selection
try("PlaceCard", "1-1", 99)                 -- locked stand or not owned
try("SetFavorite", "../../x", true)         -- malformed id
try("UpdateSetting", "Admin", true)         -- unknown setting
try("BuyUpgrade", "InfiniteMoney")          -- unknown upgrade
R.DataChanged:FireServer("Currency", { Cash = 1e12 })  -- server ignores client-fired events
for i = 1, 20 do local r = R.BuyPack:InvokeServer("burrow_pack", 1) if r.error == "Slow down!" then print("rate limited at", i) break end end
```

- [ ] All of the above behave as commented, and cash only changes for legitimate purchases.

### 1.5 HUD and windows
- [ ] Cash, treats, cash/s and the level bar show correctly and update live.
- [ ] Every navigation button opens its window; only one window is open at a time; X closes
      it.
- [ ] Settings: volume steps, Notifications toggle (non-error toasts stop) and Reduced
      Motion persist across rejoin.

### 1.6 Core loop through menus (My Stands stays as a management window)
- [ ] PACKS: OPEN on a starter pack reveals **5** cards with "1 IN X" and NEW! badges, and
      the owned count drops by one. Tapping closes the reveal.
- [ ] BUY adds packs to the owned count without opening them (toast "Bought …"), and cash
      drops by exactly the price. Unaffordable or locked buy buttons are grey and charge
      nothing.
- [ ] Opening with a ×N quantity opens min(N, owned) packs (5 cards each).
- [ ] My Stands: Place Best fills the stands; cash/s in the HUD matches the window.
- [ ] **Stand earnings (Q3):** cash does **not** rise by itself. Each stand shows
      "COLLECT $X", growing every second. Collecting one stand adds exactly that amount;
      the HUD COLLECT and COLLECT ALL buttons take everything at once, and a second click
      gives nothing.
- [ ] A stand stops growing at its cap (2 hours of its income).
- [ ] **Offline earnings:** with real DataStores, place cards, collect, stop, wait a few
      minutes, then play again. A toast reports offline earnings roughly equal to cash/s ×
      the minutes away, and the stands show them ready to collect. After more than 2 hours
      away, the toast mentions the cap.
- [ ] Backpack: sorting; place on and remove from a stand; favourite; sell. Favourite and
      on-stand cards cannot be sold, and the reason is shown.
- [ ] Upgrades: costs rise per level; MAXED at the cap; Display Stands adds a slot.
- [ ] Binder: counts match; unknown cards show "?"; a completed collection shows its
      bonus.
- [ ] Spam-click Buy: no duplicate charge beyond what the clicks request.

### 1.7 Responsive layout
- [ ] On phone and tablet emulation, the HUD, windows and reveal fit on screen, and buttons
      can be tapped.

### 1.8 World (§18, roadmap A2)
- [ ] The plaza (monument and fountain), avenue, four stations with readable signs, lamps,
      trees and warm lighting all appear; nothing floats or z-fights.
- [ ] Station prompts: Pack Shop opens PACKS; Upgrades opens UPGRADES; Collect All collects
      every stand; Grader says it's coming soon.
- [ ] The frame rate stays acceptable on phone emulation.

### 1.9 Plots and stands (§8, roadmap A3–A4; run with 2 players in Clients and Servers)
- [ ] Each player is given a different plot automatically, spawns on it, and the entrance
      sign shows their name. Free plots are grey and read "FREE PLOT".
- [ ] When a player leaves, their plot returns to FREE PLOT, and all illustrations and
      prompts on it disappear.
- [ ] Full server: set *Max Players* above 8 (or block plots with test players). The 9th
      player gets the "All plots on this server are taken" toast and can still play
      through the menus; no errors.
- [ ] Own stand: the prompt "Place card" opens the backpack titled "PICK FOR STAND #N"; PLACE
      ON STAND #N puts the card there. "Change card" swaps it, and the old card returns to
      the backpack. A card already on another stand moves.
- [ ] Locked stands (5–12 before upgrades) look greyed out; their prompt opens Upgrades.
      Buying Display Stands unlocks the next stand physically.
- [ ] Another player's stand only offers "Inspect". From player B's client command bar,
      `PlaceCard` and `CollectEarnings` only ever affect player B's own plot (probes in
      1.4).
- [ ] My Stands, the physical stands and the `stands` dev command always agree.
- [ ] Rejoin (real DataStores): the same cards are back on the same stands, with
      uncollected earnings intact.

### 1.10 Ferret illustrations (§9, roadmap A5)
- [ ] **Before the art is uploaded** (`AssetId = 0`): each occupied stand shows a floating
      placeholder card (rarity colour, name, income), and nothing errors.
- [ ] **After the upload** (assets/README.md): the six Pack 1 cards show their real art above
      the stands, in the backpack, in the reveal and in the pack shop (pack front). The art
      isn't stretched, and there's no see-through tint or checkerboard.
- [ ] The illustration floats gently and faces the camera; Reduced Motion stops the float.
- [ ] Use `card pack1_sky`, `card pack1_kingston`, `card pack1_aurora` (or `pack1_frost`) and
      `card pack1_boba` on stands: Epic glows purple; Legendary has gold sparkles plus glow;
      Mythic has a pink aura; Rare has light blue sparkles. Effects stop beyond about 70
      studs, and illustrations disappear beyond about 160.
- [ ] Removing a card or leaving the game leaves no stray billboards or particles under
      `Workspace.Plots` (check the Explorer on the client).

### 1.11 Stand income in the world (§10)
- [ ] Own stands with earnings show a green "$X" label and a "Collect $X" prompt (key F).
      Collecting pays exactly that once.
- [ ] The Collect All booth, the HUD COLLECT button and COLLECT ALL in My Stands all
      collect everything once.
- [ ] Swapping the card on a stand keeps the stand's uncollected earnings.

### 1.12 Developer tools (docs/DEVTOOLS.md)
- [ ] In Studio, the Output shows `[Dev] Developer commands enabled`, and the DEV button
      opens the panel. Every quick button returns a result.
- [ ] `roll pack1 20000`: rolled rarities match the expected percentages within about 1%.
- [ ] **Live-server check** (published test experience, not Studio): there is no DEV button,
      and `game.ReplicatedStorage.Remotes:FindFirstChild("DevCommand")` returns nil in the
      client console.

### 1.13 Pack opening: manual reveal (§7.5, roadmap A7)
Use `packs pack1 10` in the DEV panel, then the Pack Shop.
- [ ] Mode strip shows `1 PACK` (selected), `UNLOCK 3x  R$<price>` (purple) and
      `6x - NEEDS 3x` (grey, not clickable).
- [ ] `OPEN (10)` consumes exactly **one** pack: the count drops to 9.
- [ ] The world blurs, the pack front appears, shakes and bursts; then the **shared card
      back** (the uploaded image, not a drawn "?") is shown.
- [ ] Nothing happens on its own: the card stays face down until CLICK TO REVEAL (or a
      click on the card). Wait 30 s to confirm there is no timer.
- [ ] After the flip: the card art, name, rarity colour, income (`+71.4/S` for a Shiny
      Sandy), and `SHINY +2%` / `NEW!` / `1 IN N`. Effects grow with rarity.
- [ ] NEXT CARD is required for every card; after card 5 the button reads SEE ALL CARDS.
- [ ] Summary: `5 CARDS UNLOCKED!` with all five tiles (Shiny tiles show "+2%"); CLAIM ALL
      closes it and removes the blur.
- [ ] Rapid clicks on OPEN, CLICK TO REVEAL and NEXT CARD never open a second pack or skip
      a card. SKIP TO SUMMARY works at any point.
- [ ] Stop the test mid-reveal and rejoin: all five cards are in the backpack.
- [ ] Full backpack: OPEN shows an error toast and no pack is consumed.

### 1.14 Multi Opening game passes (3x / 6x)
The place must be **published** (the passes belong to the experience). In Studio, game pass
purchases are test purchases (no Robux charged). Note that in Studio
`UserOwnsGamePassAsync` reflects your real account: if you already own a pass, it shows as
owned.
- [ ] Server Output at start: `[Monetization] 3x Multi Opening (game pass 2038324873)
      "...": for sale, 100 Robux` and the same line for 6x with **its configured price**.
      A warning `NOT for sale`, `could not be read` or `design says 100` must be fixed on
      the Roblox website; an off-sale pass shows `UNAVAILABLE`.
- [ ] While the server is still asking Roblox, the buttons read `3x - CHECKING...`, never
      `UNLOCK` for a pass you own.
- [ ] Click `UNLOCK 3x  R$100`: the Roblox game pass prompt appears. Buy (test purchase):
      toast `3x Multi Opening activated!`, the strip shows `3 PACKS`, `6x` becomes
      `UNLOCK 6x  R$<price>`.
- [ ] Rejoin: 3x is owned again without buying (checked with Roblox on join).
- [ ] Cancel a purchase prompt: nothing changes.
- [ ] Before owning 3x, the 6x button reads `6x - NEEDS 3x` and can't prompt; from the
      client command bar,
      `game.ReplicatedStorage.Remotes.PromptMultiOpen:InvokeServer("MultiOpen6")` returns
      `Unlock 3x Multi Opening first`.
- [ ] 6x bought without 3x (e.g. from the experience page on the website), then join: the
      toast says the 6x pass is owned and activates once you also own 3x; 6x stays locked;
      after buying 3x, 6x works without buying it again.
- [ ] Opening 3x without the pass is refused by the server:
      `...Remotes.OpenPack:InvokeServer("pack1", "probe-1", 3)` returns an error, no packs
      consumed.

### 1.15 Simultaneous 3x / 6x opening
- [ ] Select `3 PACKS`, OPEN: three packs are consumed (count drops by 3), three packs
      appear side by side and shake/burst together, then three card backs.
- [ ] Each CLICK TO REVEAL flips **three** cards at once (card 1 of each pack), NEXT CARD
      turns all three face down for card 2. Five clicks reveal all 15 cards.
- [ ] Summary `15 CARDS UNLOCKED!` scrolls and shows all 15 with name, rarity, income,
      variant bonus.
- [ ] With 6x unlocked: six columns, six cards per click, `30 CARDS UNLOCKED!`.
- [ ] With fewer packs than the mode (e.g. 2 packs in 3x mode) OPEN reads `NEED 3 PACKS`
      and is disabled.
- [ ] Phone layout (Device emulator, e.g. iPhone SE): six columns and their text stay
      readable; the summary scrolls.

### 1.16 Image loading (evidence for performance)
- [ ] Client Output after joining: `[Art] preload startup: <n>/<n> images in X.XXs` plus
      one line per image with its time. Note the numbers (first join vs rejoin).
- [ ] When opening a pack: `[Art] preload pack opening: ...` appears during the pack
      animation; the flipped art shows immediately (no blank card).
- [ ] Open the backpack after opening packs: it re-renders once per change (no visible
      double rebuild).

### 1.17 Custom HUD artwork (Ferret Frenzy GUI pack)
- [ ] Client Output after joining: `[Art] Config.Assets ...` lists `ui.icon.settings`,
      `ui.icon.binder`, `ui.icon.backpack`, `ui.icon.upgrades` and `ui.currency_bar` with
      their `rbxassetid://` ids; `[Art] preload startup` reports no failures; there is no
      `[Art] HUD: ... failed to load` warning.
- [ ] Right rail shows the four custom icons (bag, binder, upgrades, settings), not text
      buttons; none looks stretched or squashed. Each opens its window (Backpack, Binder,
      Upgrades, Settings), including when clicking on the caption under it.
- [ ] Currency bar (left): the art is not distorted; the money value sits **centred on the
      empty green area**. If it is off, adjust `Config.Visuals.Hud.CurrencyBar`
      (`Aspect` = image width / height; `TextInset*` = fractions of the bar) and replay.
- [ ] Large values stay inside the green area and readable: DEV `setcash 999` →
      `999`; `setcash 1234567` → `1,234,567`; `setcash 999999999` → `999,999,999`;
      `setcash 1e12` → `1T`; `setcash 1e15` → short form.
- [ ] Desktop (1920×1080) and mobile (Device emulator, e.g. iPhone SE / iPad): the bar
      and icons scale with the screen, don't overlap the top buttons or the Collect
      button, and stay tappable.

### 1.18 GUI redesign (every window) - check on desktop, phone portrait and landscape
Use Studio's Device emulator (e.g. 1920×1080, iPhone 14 portrait/landscape, iPad).
- [ ] **Shared frame** (Pack Shop, Backpack, Binder, Upgrades, Settings, My Stands):
      forest-green body with a gold rim, gold ribbon header with the window's custom icon
      and title, round red X, faint paw prints; the world behind is dimmed. Clicking the
      dimmed area or X closes the window; only one window is open at a time.
- [ ] No window extends past the screen edge or into the notch area in any orientation
      (rotate the emulator while a window is open: it re-fits).
- [ ] **Backpack:** search filters by name/rarity/variant as you type; RECENT / RARITY /
      BEST highlight the active sort; the capacity chip shows `cards/capacity`. Selecting
      a card shows name, rarity chip, `SHINY +2%` chip for Shiny copies, income, sell value,
      copies owned and status. Place/Remove, Favourite and Sell work (Sell reads `ON STAND`
      / `FAVOURITE` and does nothing when the server would refuse). With no cards: `NO CARDS
      YET` + OPEN SHOP (opens the Pack Shop); a search with no results says `NO MATCHES`.
      From a physical stand the chip reads `STAND #n` and the main action places the card.
- [ ] **Binder:** bookmarks per collection with progress bars; the page shows the
      collection name, progress bar with %, the real completion bonus and the overall total;
      discovered cards show art and `xN` copies; undiscovered show the card back with
      `#00N`.
- [ ] **Pack Shop:** balance and `MY PACKS` chips; each pack has large art with a glow,
      chase line, BUY (green) or `NEED $X` (grey) when you can't afford it, the stepper,
      OPEN (gold) and the 1/3/6 mode strip (selected mode gold; locked passes purple
      `UNLOCK 3x  R$100`, `6x - NEEDS 3x` grey). Locked packs are covered by a LOCKED
      overlay that can't be clicked through. Purchases only show success after the server
      confirms.
- [ ] **Upgrades:** five upgrades only; each shows level bar, `NOW: ... → NEXT: ...`,
      and the button as `$price` (green), `NEED $X` (grey) or `MAXED` (gold).
- [ ] **Settings:** toggles switch with a sliding knob and a `... saved` toast after the
      server accepts; volume meters move in 10 steps (audio isn't in the game yet; the
      setting is saved).
- [ ] **My Stands:** each stand shows a `#n` chip; empty stands show `+` / `EMPTY STAND -
      TAP TO PLACE`; a LOCKED slot leads to Upgrades; COLLECT ALL and PLACE BEST work.
- [ ] **Pack opening:** forest backdrop with paw/leaf decoration; gold CLICK TO REVEAL,
      green NEXT CARD, gold CLAIM ALL; Shiny cards get a light sweep and a `SHINY +2%`
      ribbon; the summary sits in a gold-trimmed panel. 1 / 3 / 6 packs still give 5 / 15 /
      30 cards with manual reveals.
- [ ] **Notifications:** forest card with gold trim and a coloured round badge (i / ✓ / ! /
      ✕) that pops in.
- [ ] **HUD alignment:** the currency bar starts close to the left edge (10 px inside the
      safe area) with no empty gap before the art; the money text sits inside the green
      field and stays readable from `0` to `1T`. Client Output shows `[Art] measured
      ui.currency_bar: ...` (or a warning that measuring isn't allowed - then tune
      `Config.Visuals.Hud.CurrencyBar`). The four right-rail icons look the same size
      (backpack no longer smaller), line up in one column and all open their windows;
      `Config.Visuals.Hud.IconScale` can fine-tune one icon.

## Part 2: specification features (run when implemented)

### 2.4 Pack shop extras (§7.3–7.4, roadmap A8)
- [ ] Unaffordable packs are greyed out; a large purchase asks for confirmation.

### 2.5 Grader (§11, roadmap B1)
- [ ] The station's UI shows the cost, grade probabilities and income per grade; Roll
      charges once and shows the server's result; the grade persists across rejoin.
- [ ] Insufficient funds, unowned card, displayed card (if prohibited) and double-click are
      all refused without charging.
- [ ] Leaving mid-animation and rejoining doesn't give a free reroll.

### 2.6 Variants, binders, inventory (§12–14, roadmap B2–B4)
- [ ] Each variant has a visible treatment on cards and in the world.
- [ ] A binder reward can be claimed exactly once (spam the claim remote to check).
- [ ] With 500+ cards, the backpack opens quickly and scrolls smoothly; search, filters and
      sorting (including by grade) work; duplicates show counts.

### 2.7 Retention (§16–17, §21, roadmap Phase C)
- [ ] A daily reward can be claimed once per UTC day; changing the local clock doesn't
      allow extra claims.
- [ ] Quest progress advances only from real actions, and each reward is claimed once.
- [ ] Boost timers run on the server, expire on time and survive rejoin when configured to.
- [ ] Achievements grant once; leaderboards show server values.

### 2.8 Trading (§20, roadmap D3)
- [ ] Changing an offer clears both confirmations.
- [ ] Removing or selling an offered card cancels the trade.
- [ ] Simultaneous trades of the same card can't both succeed.
- [ ] A failed trade leaves both inventories unchanged.

### 2.9 Monetization (§23, roadmap Phase E; needs real product ids in a test experience)
- [ ] (When Developer Products are added) a purchase grants exactly once, even when Roblox
      retries `ProcessReceipt` (simulate by yielding or erroring once).
- [ ] Game Pass benefits apply on join and after an in-game purchase.
- [ ] A client "purchase succeeded" message alone grants nothing.
