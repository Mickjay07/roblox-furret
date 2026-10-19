# Ferret Card Tycoon

A Roblox collectible card tycoon game. The source code lives in this repository as plain
Luau files and is synced into Roblox Studio with [Rojo](https://rojo.space).

> **Status:** The core loop runs in a generated 3D world.
>
> - **Packs:** bought into an inventory and opened for 5 cards each.
> - **Plots:** each player is automatically given a physical plot with 12 display stands.
> - **Ferrets in the world:** floating ferret card illustrations with rarity effects.
> - **Income:** stand earnings, collected per stand or centrally, plus offline earnings.
> - **Also:** upgrades, the binder, session-locked persistence, and Studio-only developer
>   tools.
>
> The master specification is [docs/SPEC.md](docs/SPEC.md);
> [docs/STATUS.md](docs/STATUS.md) audits every requirement, and
> [docs/ROADMAP.md](docs/ROADMAP.md) has the next steps.
>
> **Nothing has been play-tested in Roblox Studio yet.** The Pack 1 artwork still has to be
> uploaded to Roblox; see [assets/README.md](assets/README.md). Until then, the game shows
> placeholder cards.

## Prerequisites

| Tool | Version | Purpose |
| --- | --- | --- |
| [Roblox Studio](https://create.roblox.com) | latest | Running and testing the game |
| [Rokit](https://github.com/rojo-rbx/rokit) | latest | Installs the pinned CLI tools listed in `rokit.toml` |
| Rojo Studio plugin | 7.4.x | Syncs files into Studio (install it with `rojo plugin install`) |
| Git | any | Version control |

Pinned CLI tools (from `rokit.toml`): Rojo 7.4.4, StyLua 0.20.0, Selene 0.27.1, Lune 0.8.9, luau-lsp 1.70.1.
`scripts/install-tools.sh` installs the same versions into `~/.local/bin`, plus the Roblox type
definitions that luau-lsp needs. It detects the platform: macOS on Apple Silicon or Intel, and
Linux on x86_64 or arm64. It checks every binary's format and architecture, and runs it, before
installing, and replaces tools built for a different platform. Where a tool has no prebuilt
release (Selene on Intel Macs; Rojo and Selene on Linux arm64), it builds it with `cargo` if
Rust is installed. `./scripts/install-tools.sh --dry-run` shows which files it would download.

## Setup

```bash
git clone https://github.com/Mickjay07/roblox-furret.git
cd roblox-furret
rokit install            # or: ./scripts/install-tools.sh (macOS and Linux)
./scripts/check.sh       # format, lint, build, type check, tests
rojo plugin install      # installs the Rojo plugin into Roblox Studio
```

## World, plots and art in Studio

- **World:** the world is generated when the game starts. Press **Play** to see it; Studio's
  edit view only shows the template. Start from a *Baseplate*: its floor and SpawnLocation
  are removed automatically at runtime.
- **Plots:** there are 8. Set *Game Settings → Places → Max Players* to **8** so every
  player gets one.
- **Card art:** upload the images in `assets/processed/pack1/` once, and paste the asset ids
  into `src/shared/Config/Assets.luau`. Step-by-step instructions are in
  [assets/README.md](assets/README.md).
- **Developer tools:** in Studio, click the pink **DEV** button. The commands are listed in
  [docs/DEVTOOLS.md](docs/DEVTOOLS.md).

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
scripts/               install-tools.sh, check.sh, simulate.luau, selene-offline/, assets/process_card_art.py
docs/                  Architecture, status, roadmap, testing, dev tools, spec, reference screenshots
assets/                Art: source originals, processed upload-ready copies, README (mapping + upload steps)
```

## Git workflow

- Each phase or feature is developed on its own branch, and changes reach `main` through
  pull requests.
- CI (`.github/workflows/ci.yml`) must be green before a merge.
- Every phase adds an entry to [DEVLOG.md](DEVLOG.md).
