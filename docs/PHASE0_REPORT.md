# Phase 0 report: inspection and setup

Date: 2026-10-19. Environment: Claude Code cloud session (Ubuntu 24.04, x86_64).

## 1. Repository inspection

| Item | Finding |
| --- | --- |
| Local clone | Empty: no files and no commits. The branch `claude/ferret-card-tycoon-setup-8vqo00` was checked out with no history. |
| Remote `Mickjay07/roblox-furret` | Empty: no branches or refs, confirmed with `git ls-remote` and the GitHub API. |
| Game specification | **Not found** in the repository or anywhere in the container (searched the filesystem for `ferret`, `furret` and `reference-screenshots`). |
| Reference screenshots | **Not reachable.** `~/Downloads/Ferret frenzy/reference-screenshots/` is on the developer's local machine, and `~/Downloads` does not exist in the cloud container. |

Nothing existed, so no files were overwritten.

## 2. Development environment

| Tool | Status in the cloud container |
| --- | --- |
| Git 2.43 | Pre-installed |
| Roblox Studio | **Not available.** Studio runs only on Windows and macOS. No Studio test has been run. |
| Rojo 7.4.4 | Installed from GitHub releases. `rojo build` and `rojo sourcemap` work. |
| StyLua 0.20.0 | Installed. Works. |
| Selene 0.27.1 | Installed, but **its Roblox std cannot be generated here**: `setup.rbxcdn.com` and `clientsettings.roblox.com` are blocked by the network policy (403). Works in CI and locally. |
| Lune 0.8.9 | Installed. Runs the unit tests and reads `.rbxl` files through `@lune/roblox`. |
| luau-lsp 1.32.1 | Installed, along with the Roblox type definitions from GitHub. Strict type checking works. |
| Luau CLI 0.650 | Downloaded, but not used by the scripts (luau-lsp replaces `luau-analyze` because it understands Roblox types). |
| Node 22, Python 3.13, Rust 1.97, Docker | Pre-installed; not needed by the project. |

Network: downloads from `github.com` releases and `raw.githubusercontent.com` work.
`api.github.com` (unauthenticated) and all `roblox.com` / `rbxcdn.com` hosts are blocked. As
a result, Rokit (which uses the GitHub API) is replaced in the cloud and in CI by
`scripts/install-tools.sh`, which downloads the same pinned versions directly.

## 3. Is Rojo a good fit?

**Yes.** Rojo is the standard for keeping a Roblox project in source control:

- Scripts are plain `.luau` files, so diffs, reviews, CI and cloud editing all work.
- `rojo serve` gives live sync into Studio for play testing.
- `rojo build` produces a `.rbxl` without Studio, which lets CI build and structurally test
  the place.

There is one caveat: hand-built 3D geometry. See
[ARCHITECTURE.md → World geometry](ARCHITECTURE.md#world-geometry).

## 4. What was set up

- A Rojo project (`default.project.json`) with server, client and shared roots.
- Server and client bootstraps with an Init/Start lifecycle for Services and Controllers.
- `Shared/Config`, `Shared/Remotes` and `Shared/Util/WeightedRandom` (a tested building
  block for pack and rarity rolls, with no gameplay values).
- Tool pins (`rokit.toml`), StyLua, Selene and `.luaurc` (strict mode) configuration, and
  `.gitignore`.
- `scripts/install-tools.sh` and `scripts/check.sh`.
- A Lune test harness with unit tests and a check of the built place's structure.
- GitHub Actions CI, which also uploads the built `.rbxl` as an artifact.
- A `.claude/settings.json` SessionStart hook that installs the toolchain in future cloud
  sessions.
- Documentation: README, DEVLOG, ARCHITECTURE, TESTING, a SPEC placeholder, and a
  placeholder folder for the reference screenshots.

## 5. Verification actually performed

- `SKIP_SELENE_IF_OFFLINE=1 ./scripts/check.sh` in the cloud container:
  - StyLua passed.
  - Selene **skipped** (network).
  - Rojo build passed.
  - luau-lsp found no errors.
  - Lune: **12 passed, 0 failed**.
- The tests were mutation-checked: an off-by-one deliberately introduced in
  `WeightedRandom` made the boundary test fail, and the tests passed again once it was
  reverted.
- **Not performed:** any Roblox Studio play test, and a Selene lint run.

## 6. Next phase: what is needed and what to build

**Blockers that need the project owner:**

1. Add the game specification to `docs/SPEC.md`.
2. Copy the reference screenshots into `docs/reference-screenshots/`.
3. On a local machine, run the Studio checks in the [TESTING.md](TESTING.md) checklist once,
   to confirm the Rojo → Studio loop works.

**Phase 1 recommendation: core loop skeleton.** Confirm each item against the spec first:

1. Derive the card catalogue, rarities and economy constants from the spec, and put them in
   `Shared/Config`.
2. `DataService`: player profiles (ProfileStore), a versioned schema and a default profile.
3. `RemoteService`: create the remotes declared in `Shared/Remotes`.
4. The smallest playable loop, for example earning currency, buying or opening one pack,
   and receiving a card, all server-authoritative, with a minimal HUD controller.
5. Unit-test the pure logic (rolls and economy maths) and add a manual Studio checklist for
   the loop.

Keep each phase small enough to verify fully before starting the next.
