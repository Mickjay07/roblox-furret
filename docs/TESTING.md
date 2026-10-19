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

## Part 2: specification features (run when implemented)

### 2.4 Pack opening sequence (§7.5, roadmap A7 remainder)
- [ ] Opening a pack plays the sequence (pack, blur, open, flip, rarity effect), and the
      card is already in the backpack before the reveal ends.
- [ ] Skip-animations works after the first viewing. Multiple packs end on a results
      screen.
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
- [ ] A developer product purchase grants exactly once, even when Roblox retries
      `ProcessReceipt` (simulate by yielding or erroring once).
- [ ] Game Pass benefits apply on join and after an in-game purchase.
- [ ] A client "purchase succeeded" message alone grants nothing.
