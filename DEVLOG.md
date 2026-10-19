# Development log

Newest entries first. Each entry records what changed, how it was verified, and where that
verification ran (CI, cloud, or a local Studio session).

## 2026-10-19: Phase 0: inspection and project setup

**Changed**
- Inspected the repository: both the local clone and the GitHub remote were empty. The game
  specification and the reference screenshots were not available. See
  [docs/PHASE0_REPORT.md](docs/PHASE0_REPORT.md).
- Set up the Rojo project structure, the server and client bootstraps (Init/Start
  lifecycle), and the shared Config, Remotes and `Util/WeightedRandom` modules.
- Added tool pins, format, lint and type-check configs, `scripts/install-tools.sh`,
  `scripts/check.sh`, the Lune test harness, GitHub Actions CI and a SessionStart hook for
  cloud sessions.
- Wrote the README, ARCHITECTURE, TESTING and SPEC placeholder documents.

**Verified (cloud container)**
- StyLua ✅, Rojo build ✅, luau-lsp strict type check ✅, Lune tests 12/12 ✅.
- Selene ⚠️ skipped: the Roblox API dump host is blocked by the cloud network. It will run
  in CI.

**Not verified**
- Any Roblox Studio play test. Studio is not available in the cloud environment.

**Open items**
- Spec document missing (`docs/SPEC.md`).
- Reference screenshots missing (`docs/reference-screenshots/`).
- First local Studio smoke test still to be run (checklist in docs/TESTING.md).
