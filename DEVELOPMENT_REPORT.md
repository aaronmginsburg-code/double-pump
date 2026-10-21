# Double Pump: development report

Branch `claude/full-game-build-3jb3hx`, built milestone by milestone with a commit per
milestone. This report says what was built, how it was checked, what wasn't checked, and
what's left for you to do.

## The short version

The whole game is written: two-shotgun combat with server authority, team deathmatch
with overtime, three maps plus a practice range, the full UI, progression and saving, a
cosmetic shop, leaderboards, and keyboard, controller and touch controls.

It has **not been played in Roblox yet**. The build environment has no Roblox Studio, so
nothing has been run in a real Roblox server: no human playtest, no multiplayer session, no
frame-rate measurement. What *was* checked is listed under "How it was checked". Before
publishing you need to do three Studio jobs (import the shotgun, upload sounds and map
art, turn on API access) and a playtest; see "What you need to do".

## Milestones

| | Milestone | Status |
|---|---|---|
| M1 | Two-shotgun combat: per-gun state, pellets, damage, hit validation, viewmodel, practice range | Done |
| M2 | Match flow: teams, spawns, respawn and protection, TDM rules, overtime, auto-balance | Done |
| M3 | UI: main menu, HUD, scoreboard, kill feed, death screen, results and MVP, map vote, settings, tutorial | Done |
| M4 | Maps: Warehouse, Dust Town, Rooftops, with automated layout checks and renders | Done |
| M5 | Original audio (29 synthesised sounds) and VFX (muzzle flash, tracers, impacts, shells, hit effects) | Done; sounds need uploading |
| M6 | Saving, XP, levels, mastery, challenges, stats, shop, leaderboards, receipts | Done; Robux packs off |
| M7 | Mobile controls and layout editor, controller support, F2 debug overlay | Done; not tried on devices |
| M8 | Docs, tests, playtest checklist | Done; playtest not run |

## How it was checked

All of these pass on the latest commit:

| Check | Command | What it covers |
|---|---|---|
| Unit tests | `lune run tests/run.luau` | 120 tests: damage and falloff (14), each gun's state machine (20), shot validation (11), match rules and scoring (21), progression and challenges (23), save data and session locks (9), receipts (4), map layouts (18) |
| Map layout checks | part of the tests; numbers from `lune run tools/map_report.luau` | 7 spawns per team on every map, spawns on solid ground with headroom, no spawn sees an enemy spawn, 100% point symmetry, sightline lengths (below) |
| Lint | `selene src` | 0 errors, 0 warnings |
| Types | `tools/typecheck.sh` (luau-lsp, strict) | 0 type errors |
| Format | `stylua --check src tests tools/*.luau` | clean |
| Place builds | `rojo build -o build/DoublePump.rbxl` | the Rojo project builds |

Map sightlines measured by the layout tool (studs, from every walkable spot in eight
directions, clipped to the play area). These are geometry measurements, not gameplay
data:

| Map | Parts | Median | 75th percentile | 95th percentile |
|---|---|---|---|---|
| Warehouse | 812 | 15 | 35 | 70 |
| Dust Town | 595 | 14 | 31 | 75 |
| Rooftops | 497 | 17 | 34 | 68 |

The tests run the shared game logic in Lune (a standalone Luau runtime) with a small fake
of the Roblox API. They don't cover networking, UI, physics or anything that needs a real
Roblox server.

## Not checked

- **No playtest of any kind.** Nobody has fired the gun in Roblox. Feel, balance and
  timing (the 0.4 s double pump, falloff, spread) are design values, not tuned.
- **No multiplayer test**, so nothing about a full ten-player match, hit registration
  under real latency, or auto-balance with real players has been observed.
- **No performance numbers.** There are no frame-rate, memory or network measurements.
  The F2 overlay is there so you can collect them.
- **No device test** for phones, tablets or controllers. The layouts were built for them
  but haven't been seen on one.
- **`tools/upload_assets.py`** follows Roblox's Open Cloud documentation but has never
  been run against the live API (no key in the build environment). The Studio Asset
  Manager route in `docs/ASSET_PIPELINE.md` doesn't depend on it.
- **DataStores** were tested against an in-memory fake, not the real service.

## What you need to do

1. **Import the shotgun** into `assets/roblox/` (Studio, about 15 minutes):
   `docs/ASSET_PIPELINE.md` step 1. Until then the game uses a labelled parts stand-in
   and prints a warning.
2. **Upload the sounds and map art** and fill `src/shared/Config/AssetIds.luau`:
   step 2 of the same doc. Until then most sounds are silent (a few fall back to built-in
   Roblox sounds) and vote cards are plain.
3. **Publish privately once and enable Studio API access** so saving and leaderboards work
   in Studio: step 3.
4. **Playtest** with `docs/PLAYTEST.md` and record what you actually saw.
5. **Only if and when you choose:** set up Robux coin packs (`docs/PUBLISHING.md` step 3)
   and make the game public (step 4). Neither has been done.

## Known limitations

- Matches need 2+ players; there are no bots. A lone player gets the practice range,
  whose dummies don't shoot back. `GameConfig.Debug.AllowSoloMatchInStudio` lets you
  start a match alone in Studio.
- Maps are built from parts in code at the start of each round. That keeps them in
  version control, but build time on a real server hasn't been measured.
- Skins are colour schemes applied to the shotgun's textures, not new models.
- Leaderboards are all-time only (no weekly boards) and update at most once a minute per
  player.
- The "Logo" image slot in `AssetIds.luau` is empty; there's no logo art yet.
- `StreamingEnabled` is off because maps are small and built at runtime. Revisit if maps
  get much bigger.
- Map preview images are Blender renders of the map geometry, not screenshots from the
  game.

## Decisions made along the way

Where the brief left room, these are the choices made; all are in config and easy to
change.

- Swap takes 0.15 s; the 0.4 s minimum between any two shots is what limits a double pump.
- Shell-by-shell reload (0.3 s + 0.5 s per shell), interruptible, keeping loaded shells.
- Fixed pellet pattern (no random spread), rotated a little each shot.
- Score target scales down for small lobbies (15 minimum) so a 1v1 doesn't need 40 kills.
- Overtime is 60 s of sudden death; a tie after that is a draw.
- Respawn 2.5 s; spawn protection 2 s, ended by firing.
- Mouse-wheel switching is on by default and can be turned off.
- Anti-idle: under 35% active time earns no completion or win reward.
- Robux coin packs exist in code but are switched off with no product IDs.

## Where things are

| Path | What |
|---|---|
| `src/server/Services/` | Server services, started in order by `src/server/init.server.luau` |
| `src/server/Maps/` | Map builders (`MapKit` helpers) |
| `src/server/Data/` | Session-locked profile store and receipt handling |
| `src/client/Controllers/` | Input, camera, movement, weapon prediction, viewmodel, effects, audio |
| `src/client/UI/` | All UI, built in code |
| `src/shared/Config/` | Every tuning number, asset IDs and product setup |
| `src/shared/Weapons/` | Gun state machine, damage, pellets, shotgun model and animation data |
| `src/shared/Progression/` | Levels, challenges, cosmetics, profile schema |
| `tests/` | Lune test runner and specs |
| `tools/` | Map report, map export and render, audio generator, asset uploader, type check |
| `docs/` | Asset pipeline, publishing, playtest checklist, asset sources |
