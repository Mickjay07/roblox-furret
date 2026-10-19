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

## Writing tests

- Put Roblox-free logic in `src/shared/...` and add `tests/unit/<Name>.spec.luau`, using
  `describe`, `it` and `expect` from `tests/TestKit.luau`. The matchers are `toBe`,
  `toEqual`, `toBeNear`, `toBeNil`, `toBeGreaterThan`, `toBeLessThan` and `toThrow`.
- Inject randomness (`roll` functions) and time (`clock`) so results are deterministic.
- Add new top-level scripts or modules to `tests/build/VerifyPlace.spec.luau`.

## Manual Studio play-test checklist

Tick items only after you have actually run them in Studio, and record the results in
DEVLOG.md.

**Setup**
- [ ] `rojo serve` connects, and the Explorer tree matches `default.project.json`.
- [ ] Press Play. The Output window shows `[Server] Ferret Card Tycoon started` with no
      errors and no `[Config]` warnings.

**Mock store (Studio API access OFF)**
- [ ] Output warns that DataStores are unavailable and that the mock store is in use.
- [ ] A "Studio test mode" toast appears.

**Real DataStore (Game Settings > Security > Enable Studio Access to API Services ON; use
a test place)**
- [ ] First join: a welcome toast appears, and the HUD shows 100 cash and 0 income.
- [ ] Change a setting, stop, and play again: the setting and the cash persist, and the
      starter toast does not appear again.

**Multiplayer (Test > Clients and Servers, 2 players)**
- [ ] Each player has their own data, and there are no errors in any Output window.

**HUD**
- [ ] The cash, treats and level bar display correctly.
- [ ] Unbuilt features show "Coming soon!".
- [ ] The Settings window opens and closes.
- [ ] The Notifications and Reduced Motion toggles work.

**Responsive layout**
- [ ] With the Device emulator set to a phone, the HUD and windows fit on screen.
