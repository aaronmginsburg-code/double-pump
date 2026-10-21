## Private release preparation — 2026-10-21

Verified Studio checkpoint: `137a9ebe68341432ea256de1cb7281b0da613a47`.
Current branch: `release/private-playtest`. Original prototype and verified backup
remain untouched. A separate recoverable source/history/place backup is at
`../verified-before-private-release-2026-10-21/`.

- Corrected the real respawn pellet-seed mismatch: WeaponState.reset now resets the
  server shotCounter, matching the client's fresh weapon state. Studio measured
  client 1/server 1 on the first post-respawn shot, in solo and local multiplayer.
- CharacterService replicates the final SpawnCFrame after preparation. GameFlow
  waits for that readiness marker and aligns the camera once per character. Both
  team camera direction dots measured 1.0, including after respawn and transitions
  between match and practice. Closing menus preserves the player's existing aim.
- 124 tests pass (all original 123 plus one counter regression); type analysis,
  source Selene, StyLua and Rojo build pass. No weapon timing, damage, movement,
  map or monetization changes. Parts-based guns/embedded animations remain usable;
  unuploaded audio and map thumbnails remain cosmetic limitations.
- Publication and normal Roblox Player verification are in progress; the final
  PRIVATE_RELEASE_REPORT.md will record confirmed IDs, access and live results.
# Testing

What tests exist, how to run them, what they last showed, and what has never been run.
Only results with evidence are listed as passing. Latest run: 2026-10-21, Windows,
`fix/studio-gameplay-blockers`, uncommitted repairs based on
`14848886bfec43bd5277564ffce89c938f46f629`. The command notes below retain the
historical Claude audit where explicitly dated. Current Studio coverage is in
[STUDIO_PLAYTEST_REPORT.md](STUDIO_PLAYTEST_REPORT.md).

## Summary

| Area | State |
|---|---|
| Automated logic tests (Lune) | **123 / 123 pass**: original 120 plus three lifecycle regressions |
| Strict type check (luau-lsp) | **0 errors**, re-run 2026-10-21 |
| Format (StyLua) | **clean**, re-run 2026-10-21 |
| Place build (Rojo) | **builds** (212 KB `.rbxl`), re-run 2026-10-21 |
| Lint (Selene) | `selene src`: **0 errors, 0 warnings, 0 parse errors**, exit 0. Extended tests/tools scan: 0 errors, 1 existing warning at validation.spec.luau:41, exit 1 |
| Shotgun asset (Blender headless) | 38 / 38 checks pass (2026-10-20, `VALIDATION.md` on PR #1 branch) |
| Roblox Studio solo play | Corrected build: range + 10 targets, HP100, mouse fire, Q switch, R reload and server-confirmed target damage observed |
| Studio multiplayer (Clients and Servers) | Corrected two-client placement/respawn and staged PvP damage/elimination pass; controlled cadence/reload probes recorded. Remaining coverage in Studio report |
| Live server / 10 players | **never run** |
| Phone, tablet, controller | **never run** |
| DataStores against real Roblox | **never run** (only an in-memory fake) |
| Developer product purchase | **never run** (products are off) |
| `tools/upload_assets.py` against Open Cloud | **never run** (dry-run only) |

## Automated suites

All commands run from the repo root. Tools come from `rokit.toml` (`rokit install`).

### 1. Lune unit tests: `lune run tests/run.luau [filter]`

Runs every `tests/*.spec.luau` in Lune 0.11.0 with a fake Roblox require tree
(`tests/runner/Loader.luau` maps the Rojo project so shared/server modules load outside
Roblox). Exit code 1 on any failure.

| Spec | Tests | Covers |
|---|---|---|
| `damage.spec.luau` | 14 | Pellet damage, multipliers, falloff, max shot damage |
| `weapon_state.spec.luau` | 20 | Per-gun state machine: cooldown, 0.4 s rule, swap, reload interrupt |
| `validation.spec.luau` | 11 | Server shot validation (origin, direction, timing) |
| `match.spec.luau` | 21 | Match rules, scoring, team balance, spawn scoring, vote tally |
| `progression.spec.luau` | 23 | XP, levels, mastery, challenges, anti-idle |
| `data.spec.luau` | 9 | Profile store: session lock, repair, retries (fake DataStore) |
| `monetization.spec.luau` | 4 | Receipt handling (disabled/unknown products stay pending) |
| `maps.spec.luau` | 18 | Every map: 7 spawns/team, spawn ground + headroom, no spawn-to-spawn sightline, symmetry, sightline budget |
| `studio_blockers.spec.luau` | 3 | Real GameFlow activation across play/menu/death/respawn/results/practice; character final placement before Spawned on initial spawn and respawn; MapService startup under protected-property restriction and serialized destroy height |

Latest run: **2026-10-21, Windows, local fix branch: 123 passed, 0 failed.**
All three new regressions failed against the original coordinators before fixes.
Boundary mocks model Roblox loading/protected properties; they do not prove physics,
real input, networking, animations, target damage or actual shot cadence.
Output: `playtest-evidence/blocker-fixes/automated-tests.log`.
The two `[Monetization] receipt for unknown or disabled product` warnings in the output
are expected (the tests feed bad receipts on purpose).

Does **not** cover: networking/remotes, UI, physics, camera, input, real DataStores,
anything needing a Roblox server.

### 2. Map layout report: `lune run tools/map_report.luau`

Not a pass/fail test; prints part counts, spawns, sightline percentiles and symmetry.
2026-10-21 output: Warehouse 812 parts p50/p75/p95 15/35/70 studs; Dust Town 595 parts
14/31/75; Rooftops 497 parts 17/34/68; all 14 spawns and 100% symmetry.

### 3. Type check: `tools/typecheck.sh`

Builds `sourcemap.json` with Rojo and runs `luau-lsp analyze` (strict) over `src/`,
skipping the generated `ShotgunAnimData.luau`. Needs the Roblox definitions at
`~/tools/globalTypes.d.luau` or `ROBLOX_DEFS=<path>`; download from
`https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau`.
Bash script; on Windows run it from Git Bash or WSL.

Last run: 2026-10-21, this audit (luau-lsp 1.70.1, current `globalTypes.d.luau`):
**no type errors printed.** Caveat: the script always exits 0 (`|| true`), so read its
output; no output means clean. With a wrong definitions path it prints hundreds of
"Unknown global" errors, so a misconfiguration is visible, but CI can't use the exit code.

### 4. Format: `stylua --check src tests tools/*.luau`

Last run: 2026-10-21, this audit: clean (exit 0).

### 5. Lint: `selene src`

Selene 0.31.0, config `selene.toml` (`std = "roblox"`). The Roblox std file
(`roblox.yml`, gitignored) is generated on first run by downloading the Roblox API dump.
That download fails inside Claude's cloud containers, so: the build thread used a
patched Selene reading a local API dump and reported **0 errors, 0 warnings on
2026-10-21**; this audit could not regenerate `roblox.yml` and did **not** re-run it.
On a normal machine with internet, stock `selene src` should work. Treat lint as
"reported clean, unverified" until Codex runs it.

### 6. Place build: `rojo build -o build/DoublePump.rbxl`

Last run: 2026-10-21, this audit: builds. `build/` is gitignored. Never pass an output path
under an empty `$TMPDIR` (it resolves to `/`).

### 7. Shotgun asset validation (PR #1 branch)

`DoublePump/Weapons/PumpShotgun/scripts/08_validate.py`, run by `scripts/run_all.sh`
with the pip `bpy` module (Blender 5.x, Python 3.13). 38 checks: object/bone names,
actions, triangle budgets, UVs, textures, scale, part clearance, FBX/GLB reimport.
Last run 2026-10-20: **38/38 PASS** (`VALIDATION.md`, `exports/validation.json`). Did
not test Roblox Studio import.

## Studio coverage still required

The full checklist is [PLAYTEST.md](PLAYTEST.md). Consult the separate Studio report
for observed original-build results and current retest status; no unchecked behavior
should be inferred passing from the automated tests. Keep solo override false.

| Test | Needs | Notes |
|---|---|---|
| Shotgun import and look (`ASSET_PIPELINE.md` step 1) | Roblox Studio | Confirms bone names, scale, muzzle direction, pump/shell animation |
| Solo play: practice range, firing, swap, reload, HUD, menus, tutorial | Studio | Play button |
| 2–4 player match: intermission → countdown → combat → results → vote → next map | Studio **Test > Clients and Servers** | Multiplayer simulation on one PC; FPS/ping meaningless |
| Solo match flow | Studio + `GameConfig.Debug.AllowSoloMatchInStudio = true` | Revert flag afterwards |
| Saving, leaderboards, coin shop persistence | Studio after first private publish + API access, or live server | Real DataStores |
| Hit registration under latency, 10-player match, auto-balance | Live private server with real players | Cloud (Roblox servers) |
| Phone/tablet touch layout, controller | Real devices | Private publish |
| Performance (FPS, memory, map build time) | Studio + real devices, F2 overlay | No numbers exist |
| Audio after upload, moderation | Studio after uploads | |
| Developer product purchase (only if enabled) | Studio test purchase | Owner decision |
| `upload_assets.py` real run | Open Cloud API key | Owner approval; may hit audio quota |

## What Codex can run without Studio

`lune run tests/run.luau`, `tools/typecheck.sh`, `stylua --check ...`, `selene src`,
`rojo build`, `lune run tools/map_report.luau`, `python tools/upload_assets.py --user-id 1 --dry-run`.
Run all of them after every change and record new results here with the date and commit.

