# Ferret Card Tycoon

A Roblox collectible card tycoon game. The source code lives in this repository as plain
Luau files and is synced into Roblox Studio with [Rojo](https://rojo.space).

> **Status:** Phases 1 and 2 are implemented.
>
> - **Phase 1 (foundation):** configuration, card registry, player data, session-locked
>   persistence, validated remotes and the HUD.
> - **Phase 2 (core loop):** buy and open packs, card reveal, backpack, display stands with
>   passive income, selling, upgrades and the binder.
>
> Nothing has been play-tested in Roblox Studio yet.
>
> **The master game specification has not been recovered.** [docs/SPEC.md](docs/SPEC.md)
> lists the requirements on record and the missing ones.
> [docs/STATUS.md](docs/STATUS.md#assumption-register) classifies every design assumption.
> See also [DEVLOG.md](DEVLOG.md).

## Prerequisites

| Tool | Version | Purpose |
| --- | --- | --- |
| [Roblox Studio](https://create.roblox.com) | latest | Running and testing the game |
| [Rokit](https://github.com/rojo-rbx/rokit) | latest | Installs the pinned CLI tools listed in `rokit.toml` |
| Rojo Studio plugin | 7.4.x | Syncs files into Studio (install it with `rojo plugin install`) |
| Git | any | Version control |

Pinned CLI tools (from `rokit.toml`): Rojo 7.4.4, StyLua 0.20.0, Selene 0.27.1, Lune 0.8.9.
`scripts/install-tools.sh` also installs luau-lsp 1.70.1 (type checking) and its matching Roblox type definitions.

## Setup

```bash
git clone https://github.com/Mickjay07/roblox-furret.git
cd roblox-furret
rokit install            # or, on Linux/CI: ./scripts/install-tools.sh
rojo plugin install      # installs the Rojo plugin into Roblox Studio
```

## Saving data in Studio

By default, Studio cannot reach DataStores. The game then uses an in-memory store: it warns
in the Output window, shows a toast, and saves **nothing**. To test real saving, use a
**test place** and turn on *Game Settings → Security → Enable Studio Access to API
Services*.

## Working in Roblox Studio

**Live sync (day-to-day work):**

1. Run `rojo serve` in the repository root.
2. Open Roblox Studio and start from a Baseplate (or any place).
3. In the Studio toolbar, open **Plugins → Rojo** and click **Connect**. Studio now
   updates every time you save a file.
4. Press **Play** (F5) to test. For multiplayer behaviour, use **Test → Clients and
   Servers**.

**Building a place file:**

```bash
rojo build -o build/FerretCardTycoon.rbxl
```

Open `build/FerretCardTycoon.rbxl` in Studio. CI also uploads this file as an artifact on
every push.

> Files are the source of truth. Edits made to scripts directly in Studio are **not**
> saved back to the repository. Change the `.luau` files instead. Parts and other world
> geometry built in Studio need a deliberate workflow; see
> [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#world-geometry).

## Checks

```bash
./scripts/check.sh
```

The script runs, in order:

1. StyLua format check
2. Selene lint (in the cloud, set `SKIP_SELENE_IF_OFFLINE=1` to use an offline
   approximation)
3. `rojo build`
4. luau-lsp strict type check against the Roblox API definitions
5. Lune tests: unit tests, plus a check of the built place's structure

Run `stylua src tests` to auto-format. Run `lune run scripts/simulate 3` to simulate three
hours of economy pacing. Details are in [docs/TESTING.md](docs/TESTING.md).

## Project layout

```
default.project.json   Rojo mapping from files to the Roblox instance tree
src/server/            → ServerScriptService.Server   (bootstrap, Lib/, Services/)
src/client/            → StarterPlayerScripts.Client  (bootstrap, Lib/, UI/, Controllers/)
src/shared/            → ReplicatedStorage.Shared     (Config/, Logic/, Data/, Util/, Remotes, Types)
tests/                 Lune runner, Roblox-require Loader, unit and place-structure specs
scripts/               install-tools.sh, check.sh, selene-offline/
docs/                  Architecture, status, testing, spec, reference screenshots, Phase 0 report
```

## Git workflow

- Each phase or feature is developed on its own branch, and changes reach `main` through
  pull requests.
- CI (`.github/workflows/ci.yml`) must be green before a merge.
- Every phase adds an entry to [DEVLOG.md](DEVLOG.md).
