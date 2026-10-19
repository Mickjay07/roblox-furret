# Ferret Card Tycoon

A Roblox collectible card tycoon game. The source code lives in this repository as plain
Luau files and is synced into Roblox Studio with [Rojo](https://rojo.space).

> **Status:** Phase 0 (project setup) is done. No gameplay has been built yet. See
> [DEVLOG.md](DEVLOG.md) for progress and [docs/PHASE0_REPORT.md](docs/PHASE0_REPORT.md)
> for the setup report and the plan for the next phase.

## Prerequisites

| Tool | Version | Purpose |
| --- | --- | --- |
| [Roblox Studio](https://create.roblox.com) | latest | Running and testing the game |
| [Rokit](https://github.com/rojo-rbx/rokit) | latest | Installs the pinned CLI tools listed in `rokit.toml` |
| Rojo Studio plugin | 7.4.x | Syncs files into Studio (install it with `rojo plugin install`) |
| Git | any | Version control |

Pinned CLI tools (from `rokit.toml`): Rojo 7.4.4, StyLua 0.20.0, Selene 0.27.1, Lune 0.8.9.
`scripts/install-tools.sh` also installs luau-lsp 1.32.1, which is used for type checking.

## Setup

```bash
git clone https://github.com/Mickjay07/roblox-furret.git
cd roblox-furret
rokit install            # or, on Linux/CI: ./scripts/install-tools.sh
rojo plugin install      # installs the Rojo plugin into Roblox Studio
```

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
2. Selene lint
3. `rojo build`
4. luau-lsp strict type check against the Roblox API definitions
5. Lune tests: unit tests, plus a check of the built place's structure

Run `stylua src tests` to auto-format. Details are in [docs/TESTING.md](docs/TESTING.md).

## Project layout

```
default.project.json   Rojo mapping from files to the Roblox instance tree
src/server/            → ServerScriptService.Server   (server Script + Services/)
src/client/            → StarterPlayerScripts.Client  (LocalScript + Controllers/)
src/shared/            → ReplicatedStorage.Shared     (Config, Remotes, Util)
tests/                 Lune test runner and specs
scripts/               install-tools.sh, check.sh
docs/                  Architecture, testing, Phase 0 report, spec, reference screenshots
```

## Git workflow

- Each phase or feature is developed on its own branch, and changes reach `main` through
  pull requests.
- CI (`.github/workflows/ci.yml`) must be green before a merge.
- Every phase adds an entry to [DEVLOG.md](DEVLOG.md).
