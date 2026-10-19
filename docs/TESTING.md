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
- [ ] `ReplicatedStorage.Remotes` contains every name listed in `Shared/Remotes.luau`.

### 1.2 Persistence: mock store (API access OFF)
- [ ] Output warns that DataStores are unavailable and the in-memory store is in use, and a
      "Studio test mode" toast appears.
- [ ] Stop and Play again: progress resets. This is expected, and proves the mock store
      never touches real data.

### 1.3 Persistence: real DataStore (API access ON, test place)
- [ ] First join: welcome toast; 1,500 cash; two starter cards already on stands; HUD shows
      +2 CASH/S. (These values conflict with the spec: C5 and C10.)
- [ ] Buy a pack, place a card, buy an upgrade, change a setting, then Stop. Play again:
      cards, stands, upgrade levels, cash, settings and level all persist, and **no**
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

### 1.6 Current core loop (UI-only stands, an interim design: C3 and C4)
- [ ] Buy a Burrow Pack: cash drops by exactly the price; the reveal shows 3 cards with
      "1 IN X" and NEW! badges; tapping closes it.
- [ ] Buying ×10 charges 10 × the price and reveals 30 cards. Buying with too little cash
      shows an error and charges nothing.
- [ ] My Stands: Place Best fills the stands; cash/s in the HUD matches the window; cash
      rises every second.
- [ ] Backpack: sorting; place on and remove from a stand; favourite; sell. Favourite and
      on-stand cards cannot be sold, and the reason is shown.
- [ ] Upgrades: costs rise per level; MAXED at the cap; Display Stands adds a slot.
- [ ] Binder: counts match; unknown cards show "?"; a completed collection shows its
      bonus.
- [ ] Spam-click Buy: no duplicate charge beyond what the clicks request.

### 1.7 Responsive layout
- [ ] On phone and tablet emulation, the HUD, windows and reveal fit on screen, and buttons
      can be tapped.

## Part 2: specification features (run when implemented)

### 2.1 Plots (§8, roadmap A3)
- [ ] On join, the player can claim an unowned plot; the owner's name appears on it; owned
      and unowned plots look different.
- [ ] Two players can't claim the same plot. Leaving releases the plot.
- [ ] From player B's client command bar, a placement or collection request targeting
      player A's plot or stand is refused (§8.8, §31).
- [ ] "Return to my plot" works from anywhere.

### 2.2 Stands and 2D ferret illustrations (§8–9, roadmap A4–A5)
- [ ] Approach a stand: a prompt appears; selecting a card places it; the ferret
      illustration appears above the stand, faces the camera and keeps its aspect ratio.
- [ ] Replacing the card updates the illustration; removing it makes the illustration
      disappear, with no leftover objects in the Explorer.
- [ ] The same card can't be on two stands (a placement request for an already-displayed
      card moves it).
- [ ] Rejoin: the arrangement and illustrations are restored exactly.
- [ ] Rarity effects match §9 (Rare blue particles, Epic purple glow, Legendary gold
      sparkles, …), and Reduced Effects tones them down.
- [ ] With 2 players and full plots, effects on distant plots are reduced, and the frame
      rate stays acceptable on phone emulation.

### 2.3 Income, collection and offline earnings (§10, roadmap A6)
- [ ] Stands accumulate earnings; collecting adds exactly the shown amount; collecting
      twice quickly pays once.
- [ ] Spamming the collect remote from the command bar never pays more than was
      accumulated.
- [ ] Changing the local clock has no effect on earnings.
- [ ] Offline: leave, use the developer tool to fast-forward time (or wait), rejoin. The
      offline payout is shown, matches displayed income × time, and is capped at the
      configured limit.

### 2.4 Pack inventory and opening (§7, roadmap A7)
- [ ] A new player receives the starter currency and starter packs once only (rejoin to
      confirm).
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
