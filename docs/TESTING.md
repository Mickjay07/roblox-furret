# Testing strategy

Roblox Studio cannot run in CI or in the Linux cloud container (it runs only on Windows and
macOS). Testing is therefore split into layers. Each layer is labelled with **where it
runs**, so a claim that tests passed always says which layer it means.

| Layer | Tool | Runs in | What it proves |
| --- | --- | --- | --- |
| Format | StyLua | CI, cloud, local | Code style is consistent |
| Lint | Selene (`std = "roblox"`) | CI, local (*skipped in the cloud, see below*) | Common Luau and Roblox API mistakes |
| Build | `rojo build` | CI, cloud, local | The project maps to a valid place file |
| Type check | `luau-lsp analyze` with the Roblox API definitions | CI, cloud, local | Strict-mode type errors, wrong API usage, `require` resolution |
| Unit tests | Lune (`tests/unit`) | CI, cloud, local | Pure game logic (rolls, economy maths, etc.) |
| Place structure | Lune `@lune/roblox` (`tests/build`) | CI, cloud, local | The built `.rbxl` contains the expected instances and classes |
| Play tests | Roblox Studio | **Local only** (manual) | Real runtime behaviour: remotes, UI, DataStores, physics |

Run every automated layer with `./scripts/check.sh`.

## Cloud limitation: Selene

Selene builds its Roblox standard library from Roblox's API dump, which it downloads from
`setup.rbxcdn.com`. The cloud network policy blocks that host. In the cloud, run:

```bash
SKIP_SELENE_IF_OFFLINE=1 ./scripts/check.sh
```

This prints a clear `selene SKIPPED` warning and continues. CI on GitHub Actions has full
network access and runs Selene normally. luau-lsp still provides type checking in the
cloud, because its type definitions are fetched from GitHub.

## Writing tests

- Put Roblox-free logic in `src/shared/...` modules and add `tests/unit/<Name>.spec.luau`.
  The test files use `describe`, `it` and `expect` from `tests/TestKit.luau`.
- When code that depends on Roblox can't be unit-tested, keep it thin and add a manual
  play-test checklist item for it (below).
- When adding a new top-level script or folder, add it to `tests/build/VerifyPlace.spec.luau`.

## Manual Studio play-test checklist

Copy this checklist into each phase's DEVLOG entry and tick items only after you have
actually run them in Studio:

- [ ] `rojo serve` connects, and the Explorer tree matches `default.project.json`
- [ ] Play (F5): the Output window shows `[Server] Ferret Card Tycoon started` with no errors
- [ ] Test → Clients and Servers (2 players): no errors on the server or on either client
- [ ] Phase-specific checks (listed in the DEVLOG entry)
