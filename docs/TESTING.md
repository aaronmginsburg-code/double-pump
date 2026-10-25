> 2026-10-25: **private development v63 published and cloud-source verified**, implementation `80a1dca` on `feat/development-training-bots`. Five-category console plus approved bottom mobile DEV launcher.463tests pass. Public publishedv10 unchanged. New-schema cloud persistence and physical-device acceptance remain pending. See [publication report](DEVELOPER_CONSOLE_PUBLISH_REPORT.md).

## Development aim assist checkpoint — 2026-10-24

**Private developmentv39 published and verified**, implementation commit `665d307` on `feat/development-aim-assist`: development-only aim assist and the authorized F6 tuning console. Production remains publishedv10. The owner subsequently confirmed Save→rejoin→Load persistence in the published development build. This is owner-reported verification; Studio DataStore access remained disabled. Real phone/controller aiming and multitouch feel remain pending. The newer private cloudv29 source was reconciled: local private source now includes the feedback modules and GameFlow, with118 permanent scripts in the aim-assist candidate. Earlier warnings below about the89-script private tree are historical. Preserve full-scene cloud geometry; do not deploy the stand-alone Rojo source build over it.

Read [aim-assist test/release report](AIM_ASSIST_TEST_REPORT.md) for actual publication status, source checkpoints,398 passing tests, Studio observations, screenshots and remaining hardware/cloud-persistence verification. Architecture and parameters are in AIM_ASSIST_IMPLEMENTATION.md and AIM_ASSIST_CONFIGURATION.md. This does not update the public game or promote any tuning configuration.

---

## Private quieter-footstep release — 2026-10-24

Approved .65 -> .13 footstep gains are now **published privately asv29**, based on newer cloudv26 and preserving its feedback system (111scripts).377 existing local tests passed; fresh Studio verified four gains and actual movement/rolloff. Public game unchanged. **Local development-copy/source lacks the newer cloud feedback additions**; use the archivedv29 cloud place/source snapshot as deployment authority until reconciled. Do not overwrite it with the older89-script Rojo build. See [publication report](../audio-production/footstep-level-review-20261024/publication/PRIVATE_RELEASE_REPORT.md) for exact delta, backups, test boundaries and known pre-existing Landing suppression.

---
## Private development audio — 2026-10-24

Private universe10772492892/place139437092998076 is now **publishedv24**, adding the five owner-selected surface-footstep/landing cues (51 total configured audio cues). New presentation-only movement audio replaces default Running/Landing without layering; movement/combat configuration, controls, profiles and public game are unchanged. Current authority is development-copy/source, branch feat/mobile-controls @ b90e77a plus preserved uncommitted private changes. **377 tests pass**,89 scripts match clean Studio candidate; two-client Studio surface/jump/idle/respawn/queue/return checks completed. LSP/Selene dependencies remain blocked; full formatting has pre-existing differences. Live-device listening remains owner acceptance. [Release report](../development-copy/audio-batch07-20261024/AUDIO_RELEASE_REPORT.md) contains IDs, implementation, exact limitations, backups and rollbackv22. Older privatev9/blank-audio notes below are historical. Batch08 variations await owner review and must not be described as implemented.

---
## Private development shotgun build — 2026-10-22

The original Blender shotgun is now imported **only in the separate private development experience**, universe10772492892 / place139437092998076, publishedv9. Both FP slots and TP use the recovered rig and all ten original baked animation clips. All16 skins are unlocked through exact-development-ID guarded overrides. Public production is not updated. See [development release report](../development-copy/DEVELOPMENT_RELEASE_REPORT.md) for source snapshot, imported assets, backups,306 passing tests, Studio evidence, owner Player confirmation and remaining limits. Earlier local-preparation notes below describe the prior checkpoint and are superseded for development deployment.

---
## Blender shotgun preparation — 2026-10-22

Uncommitted candidate based on HEAD b90e77a3f2dc5238d4fc5d91b99eb35cbaa6018a. 301/301 assertions pass using `lune run docs/cosmetic-audit-20261022/tools/run-existing-compat.luau`; 56 new imported-model tests use stable synthetic Instances plus actual model/animation/catalog modules. Native Lune 0.8.9 runner has 15 path-resolution load failures; no assertions were weakened. StyLua and Rojo pass. LSP is blocked by missing globalTypes.d.luau; Selene by API standard-library collection. Blender FBX round-trip and texture validation pass. No replacement Studio, live-player, multiplayer or hardware tests claimed. Exact commands/logs and required runtime matrix: [integration report](BLENDER_SHOTGUN_INTEGRATION.md).

---

## Release transition — 2026-10-22

Implementation4505edef:245 automated tests and21/21 staged three-client Studio assertions pass; LSP/Selene/StyLua/Rojo clean.81scripts match saved Studio source. Published privately as version10; existing icon/five thumbnails preserved. No gameplay, balance, asset uploads or Public change. See RELEASE_RECORD.md for fresh evidence and unverified live/device boundaries. Earlier entries are historical.

## 2026-10-21 - Permanent firing-range lobby and voluntary queue

Implemented a server-owned physical FIFO queue (2-10 players, 15 seconds), selected-roster map voting, nonlethal range PvP using the existing pellet damage pipeline, and full-health/ammo return to the lobby. Healthy transfers retain the prepared avatar; real deaths retain normal respawns. Base a487de38 with existing mobile/camera changes preserved; no commit/push. 245 tests pass; staged three-client Studio cycles verified all three arenas, real match PvP and return/requeue, plus an actual fourth late join. See `LOBBY_AND_MATCHMAKING_UPDATE.md` and `docs/lobby-matchmaking-evidence/` for exact evidence, initial failed probes and limitations. Private publication is tracked in the report. Weapon balance, control implementations and arena source files remain unchanged.

## Marketing asset delivery � 2026-10-21

Owner reports the latest mobile camera/independent-hand revision works properly.
Created marketing-only assets: three icon concepts, six thumbnail concepts, one
refined 512-square icon and three refined 1920x1080 thumbnails, with Studio captures,
editable SVG typography, generated masters and source prompts. Files are under
marketing/. No gameplay code, combat settings, maps, cloud version, access or
monetization was changed; no promotional art was uploaded. 197 tests pass and all
78 local scripts still match the previously verified candidate. See
[marketing report](../marketing/MARKETING_ASSET_REPORT.md) for provenance, capture
limitations, final files and upload instructions. Earlier sections are historical.

## Camera and independent weapon hand revision — 2026-10-21

Owner tested version 5 on iPhone 17 Pro Max with no technical issues. On
feat/mobile-controls (base a487de38a96261dbeac74e701e69ce31762123f9, uncommitted),
LOOK was removed and original displacement-based touch aiming restored. All other
mobile bounds and swipe/held-fire behavior remain unchanged. Control Layout and
Weapon Hand are independent canonical right/left preferences; profile v3 preserves
old coupled layout/weapon selections. Datastore name unchanged.

197 tests pass; type analysis, StyLua, Selene and Rojo pass. Local build and Studio
snapshot match all 78 script containers. Actual Studio checks include all four
combinations, drag axes/gesture separation, server-saved left UI/right weapon,
respawn continuity and desktop mouse/Q/R. Physical revised multitouch and live
rejoin/map-cycle testing remain pending. Privately published version 8 to the
existing experience; Dashboard confirms owner/collaborator-only access. Independently
reopened cloud copy matches all 78 tested sources. Version 5 remains recoverable.

See [MOBILE_CAMERA_AND_HANDEDNESS_UPDATE.md](../MOBILE_CAMERA_AND_HANDEDNESS_UPDATE.md)
for files, migration, screenshots, exact test scope, backup and publication state.
Earlier sections below are historical.

## Mobile private update — 2026-10-21

Implemented on `feat/mobile-controls`, based on
`a487de38a96261dbeac74e701e69ce31762123f9`; changes remain uncommitted.
**168 tests pass** (124 existing + 44 mobile); type analysis, StyLua, Selene and
Rojo build pass. Studio Practice, LOOK/release, fire taps, valid/invalid swipes,
both layouts/viewmodels, reload, server preference save, respawn and desktop
fire/Q/R were observed. Instrumented server-accepted alternate shots measured
0.439 / 0.630 seconds; simulated intent, not physical multitouch.

Published **version 5** to existing universe **10772275012**, start place
**82505574993280**, still restricted to owner/collaborators. Independently reopened
cloud source matches all **76** containers without probes. Stable version 2, local
backups and source history remain recoverable. No balance, maps, desktop bindings,
public access, products or assets changed. Original prototype untouched.

Real phone/tablet multitouch, live rejoin persistence, device performance and this
update's full multiplayer/map cycle remain unverified. See
[MOBILE_CONTROLS_UPDATE.md](../MOBILE_CONTROLS_UPDATE.md) for exact evidence,
configuration, screenshots, backups and checklist. Earlier sections below describe
historical stable builds and are retained for continuity.

## Owner live-client confirmation — 2026-10-21

Aaron opened the private experience on another computer and reported that he has
been testing it and it looks good. Basic normal-client launch/playability is now
owner-confirmed. Detailed live multiplayer, map-cycle and performance checks remain
outstanding; this does not change the automated Player verification limitations
recorded below. No further source, settings or publication changes were made.

## Published private test — 2026-10-21

Current source checkpoint: `a487de38a96261dbeac74e701e69ce31762123f9` on
`release/private-playtest`; previous verified checkpoint `137a9ebe` remains intact.
Published **privately** as Double Pump [Private Test], universe **10772275012**,
start place **82505574993280**, published version **2**. No public/friends release,
monetization, asset upload, merge or push. Server limit saved as 10; genre Shooter.

[Open owner playtest](https://www.roblox.com/games/82505574993280/Double-Pump).
See [private release report](../PRIVATE_RELEASE_REPORT.md) and
[manual guide](../PRIVATE_PLAYTEST_GUIDE.md) for verified scope and limitations.
All 124 automated tests pass; type analysis, Windows-aware StyLua, Selene source
lint and Rojo build pass. Studio solo/two-client checks confirm counter 1/1 after
respawn and camera direction dot 1.0 through team respawn and practice/match changes.
The downloaded cloud place matches all 72 tested script containers. Actual regular
Roblox Player gameplay remains unverified; owner manual launch is pending.
Original prototype untouched; all 52 original backup checksums match. Separate
verified/release places, source archives and Git bundles are retained in
`../verified-before-private-release-2026-10-21/` beside the isolated checkout.
The sections below are historical preparation/audit records, superseded by this
publication status where they say not published or repairs uncommitted.
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


## Training bot verification — 2026-10-24

See [TRAINING_BOTS_UPDATE.md](TRAINING_BOTS_UPDATE.md) for the development-only source/deployment record, exact results and limitations. 424 tests pass, including26 bot regressions. This does not change the public release record above.

## Training range death reset — October 24, 2026

Commit b32ed9f:426 tests passed; compile/changed-file StyLua/Rojo passed. Actual Studio bot elimination, normal owner respawn, eight seconds of passive100HP safety and fresh-hit reprovocation passed. Selene API dump and LSP definitions remain blocked. See TRAINING_BOTS_PASSIVE_RESET.md. No new hardware or full-map-cycle certification.
