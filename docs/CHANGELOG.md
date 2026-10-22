## Release transition — 2026-10-22

Implementation4505edef:245 automated tests and21/21 staged three-client Studio assertions pass; LSP/Selene/StyLua/Rojo clean.81scripts match saved Studio source. Published privately as version10; existing icon/five thumbnails preserved. No gameplay, balance, asset uploads or Public change. See RELEASE_RECORD.md for fresh evidence and unverified live/device boundaries. Earlier entries are historical.

## 2026-10-21 - Permanent firing-range lobby and voluntary queue

Implemented a server-owned physical FIFO queue (2-10 players, 15 seconds), selected-roster map voting, nonlethal range PvP using the existing pellet damage pipeline, and full-health/ammo return to the lobby. Healthy transfers retain the prepared avatar; real deaths retain normal respawns. Base a487de38 with existing mobile/camera changes preserved; no commit/push. 245 tests pass; staged three-client Studio cycles verified all three arenas, real match PvP and return/requeue, plus an actual fourth late join. See `LOBBY_AND_MATCHMAKING_UPDATE.md` and `docs/lobby-matchmaking-evidence/` for exact evidence, initial failed probes and limitations. Private publication is tracked in the report. Weapon balance, control implementations and arena source files remain unchanged.

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
# Changelog

## Unreleased — Studio gameplay blockers (2026-10-21)

Base: PR #2 `14848886bfec43bd5277564ffce89c938f46f629`.
Local branch: `fix/studio-gameplay-blockers`. Uncommitted; no merge or push.

- Restore existing firing, switching and reload eligibility by assigning
  `WeaponController.active` from GameFlow's existing combat-input state. Menus,
  death, postgame and practice use the same lifecycle as camera/input controls.
  File: `src/client/Controllers/GameFlow.luau`.
- Place and initialize characters after `LoadCharacterAsync` completes, rather than
  in the earlier `CharacterAdded` callback where engine spawn placement overwrote
  the chosen team CFrame. Verify humanoid/root/current character before preparing;
  emit Spawned after placement and retain the existing three-stud lift/protection.
  File: `src/server/Services/CharacterService.luau`.
- Remove the protected runtime Workspace destroy-height assignment which prevented
  range construction; serialize the identical -120 value in the place build.
  Files: `src/server/Services/MapService.luau`, `default.project.json`.
- Add three regression tests in `tests/studio_blockers.spec.luau`. Original 120
  tests and all three regressions pass. Direct type analysis, Rojo build, source
  lint and StyLua pass. Extended lint retains one pre-existing test warning.
- Update AI_HANDOFF, PROJECT_STATUS, TESTING and STUDIO_PLAYTEST_REPORT.

Corrected build: `build/DoublePump_STUDIO_BLOCKER_FIXES.rbxl`. Once the owner cleared
the window limit, Studio tests confirmed range startup/targets, mouse fire/Q swap/R
reload, target damage, two-player team initial/respawn placement and staged PvP
damage/elimination. A controlled probe measured accepted alternating intervals of
0.550/0.783/0.484 s and a 1.116 s single-gun control; the server rejected a premature
request, and reload interruption preserved inserted shells. Human latency/device
validation remains incomplete. The original report/screenshots remain pre-fix evidence.
All three arenas loaded through normal round flow; initial team coordinates matched
their markers. Warehouse/Rooftops respawns were measured. Spawn-facing camera views
need follow-up; no extra orientation/map fix was introduced during verification.

Weapon configuration, double-pump state rules, damage, movement, recoil, animation,
team rules, maps and assets are unchanged. Original prototype and all 52 backup
files remain intact. The separate post-respawn shot-counter issue is now reproduced
in Studio (predicted 1 vs server 7) and remains unfixed for a separately scoped review.
