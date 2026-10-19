# Architecture

These are the recommended conventions for Ferret Card Tycoon. Gameplay-specific systems
must be checked against the game specification (`docs/SPEC.md`) before they are built.

## Principles

1. **The server is authoritative.** All currency, cards, pack rolls, upgrades and income
   are calculated on the server. Clients send *intents* (for example "open pack X"), and
   the server validates every one of them. The client never sends values the server should
   trust, such as prices, rolls or rewards.
2. **Data-driven design.** Card definitions, rarities, drop weights, prices and upgrade
   curves live in `src/shared/Config`, so balancing never requires changes to logic.
3. **Pure logic, thin Roblox glue.** Rules that can be expressed without the Roblox API
   (rolls, economy maths, progression) go in pure modules under `src/shared`. Those modules
   are unit-tested under Lune. Services and controllers wire them to Roblox APIs.
4. **No framework dependencies yet.** A small lifecycle convention (below) covers the
   current needs. A dependency is added (through Wally) only when it clearly earns its
   place.

## Runtime layout

| Source | Studio location | Role |
| --- | --- | --- |
| `src/server/init.server.luau` | `ServerScriptService.Server` (Script) | Loads `Services/*` |
| `src/server/Services/*.luau` | `…Server.Services` | One ModuleScript per server system |
| `src/client/init.client.luau` | `StarterPlayerScripts.Client` (LocalScript) | Loads `Controllers/*` |
| `src/client/Controllers/*.luau` | `…Client.Controllers` | One ModuleScript per client system (UI, effects) |
| `src/shared/Config` | `ReplicatedStorage.Shared.Config` | Game-design data |
| `src/shared/Remotes.luau` | `ReplicatedStorage.Shared.Remotes` | Names of all remotes |
| `src/shared/Util/*` | `ReplicatedStorage.Shared.Util` | Pure helpers (for example `WeightedRandom`) |

### Service / controller lifecycle

Each module returns a table with optional `Init` and `Start` methods:

```lua
local MyService = {}

function MyService:Init()  -- synchronous setup; must not yield; no calls to other services
end

function MyService:Start() -- runs in its own thread after every Init has finished
end

return MyService
```

The bootstrap calls `Init` on every module first, and then `Start` on every module. A
failure in one module is logged and does not stop the others from loading.

### Networking

- All remotes are declared by name in `Shared/Remotes.luau`.
- A server service creates them in a `ReplicatedStorage.Remotes` folder at startup.
- Clients look remotes up only by the declared names.
- Every remote handler on the server validates the argument types and the player's state,
  and rate-limits calls where that makes sense.

## Expected systems (to be confirmed against the spec)

These are typical for a card tycoon. Build only what the spec calls for.

- **DataService:** loads and saves player profiles with session locking and retries.
  Recommended approach: [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore),
  vendored or installed through Wally.
- **EconomyService:** currencies and passive income ticks.
- **CardService / PackService:** card catalogue and pack opening (uses `WeightedRandom`).
- **TycoonService:** plot assignment, purchasable buttons and droppers or display stands.
- **UI controllers:** HUD, inventory or collection book, and the pack-opening animation.

## World geometry

Rojo syncs scripts well, but it is a poor fit for hand-built 3D layouts. The recommended
approach:

- Build tycoon plot templates in Studio.
- Export each template as a model file (`.rbxm`) to `assets/models/` and map it in
  `default.project.json`, so models are versioned in Git as binary files.
- Alternatively, generate simple plot geometry from code at runtime.

Decide this in the phase that builds the first tycoon plot.

## Persistence safety

- Never write to DataStores from the client.
- Use Studio's **Enable Studio Access to API Services** setting only in test places.
- Version the profile schema from the first release, and write a migration whenever the
  schema changes.
