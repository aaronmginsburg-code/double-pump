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

# Roadmap

Ordered. Steps marked **(owner)** need Aaron's action or explicit approval; Codex
prepares them but does not do them alone. Status as of 2026-10-21.

## 0. Consolidate the repository

- [ ] Merge PR #2 (`claude/full-game-build-3jb3hx`) into `main` once reviewed **(owner)**.
- [ ] Decide how the shotgun asset is kept **(owner)**: merge PR #1 as is (170 MB plain
      git), move the large binaries to Git LFS first, or keep PR #1's branch as an
      archive and only commit the imported `.rbxm` files to `main`. Never delete the
      branch until one of these is done.
- [ ] Decide public vs private repository **(owner)**.
- [ ] Add CI (GitHub Actions): `rokit install`, `lune run tests/run.luau`, `selene src`,
      `stylua --check`, `rojo build`, and a type check that fails on errors.

## 1. Get the game running in Studio

- [ ] Import the shotgun (FP, TP, spent shell) and commit the three `.rbxm` files
      (`ASSET_PIPELINE.md` step 1, `ASSET_UPLOAD_MANIFEST.md` §1–2) **(owner, Studio)**.
- [ ] Solo play check in Studio; fix anything broken.
- [ ] First private publish and Studio API access **(owner)**.
- [ ] Upload 29 sounds and 3 map images, fill `AssetIds.luau` **(owner approval)**.
      Fix the decal-ID fallback in `tools/upload_assets.py` first if using the script.

## 2. Playtest and fix

- [ ] Work through `PLAYTEST.md` in Studio (solo, then Clients and Servers with 2–4).
- [ ] Private live test with real players and devices (PC, phone, controller).
- [ ] Collect F2 performance numbers; measure map build time on a live server.
- [ ] Tune weapon timing, damage and falloff from feedback (config only).

## 3. Confirm open design decisions **(owner)**

- [ ] Shield (100 HP + 100 shield) or HP only.
- [ ] Swap/equip timing: keep 0.15 s swap / 0.4 s interval / 1.0 s cooldown, or return
      to the earlier easy baseline.
- [ ] Movement: bring back sprint/slide/prone from the prototype, or stay minimal.
- [ ] Round length and score target; shield pickups.

## 4. Release prep

- [ ] Icon (512×512), gameplay thumbnails, description, logo for `AssetIds.Images.Logo`.
- [ ] Experience Questionnaire, max players 10, R15 **(owner)**.
- [ ] All `GameConfig.Debug` flags false.
- [ ] Optional Robux coin packs (`PUBLISHING.md` step 3) **(owner, real money)**.
- [ ] Go public **(owner)**.

## Later (planned, not implemented)

- More weapon types (launch is shotguns only by decision).
- Bots / backfill for low-population servers.
- Weekly or seasonal leaderboards.
- Model-based skins (current skins are colour tints).
- More maps; revisit `StreamingEnabled` if maps grow.

## Mobile private update — 2026-10-21

Version 5 is privately published; Studio and 168 automated tests pass. Next: actual
phone/tablet multitouch, rejoin persistence, live PvP/map-cycle and performance.
Stable version 2 and separate backups remain recoverable. See ../MOBILE_CONTROLS_UPDATE.md.
