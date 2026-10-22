# Double Pump private release report

Date: 2026-10-21. Status: **Published privately; owner confirms successful normal-client gameplay.**

## Cloud identity and access

| Field | Verified value |
|---|---|
| Experience | Double Pump [Private Test] |
| Owner | supersnapstudios (11808586604) |
| Universe ID | **10772275012** |
| Start Place ID | **82505574993280** |
| Experience URL | https://www.roblox.com/games/82505574993280/Double-Pump |
| Published place version | **2**, verified using the published-only history filter |
| Access / audience reach | **Private / Private** in Creator Dashboard |
| Server size | **10**, saved in place Access settings and displayed on Roblox |
| Genre | **Shooter**; no subgenre selected |
| Description | Exact owner-supplied private development description |
| Paid products | Products.Enabled=false, all product IDs nil; none created |
| Public/friends release | Neither enabled; no testers invited |

A new experience was created after confirming no Double Pump entry existed in the
account's dashboard. No unrelated experience was overwritten. Studio's successful
publication and Creator Dashboard independently show private availability. The
standard public-release flow, paid access and publishing-fee options were not used.
Studio API access and Mesh/Image API permissions remain disabled/unchanged.

## Source, checkpoint and rollback

Authoritative project:
`C:\Users\aaron\Documents\double-pump-backups\2026-10-21-prototype-uncommitted\complete-game-studio`.
Authoritative base is PR #2, `14848886bfec43bd5277564ffce89c938f46f629`.
The scaffold main branch and original prototype were not used.

- Previous verified build checkpoint: **137a9ebe68341432ea256de1cb7281b0da613a47**,
  branch `fix/studio-gameplay-blockers`.
- Release source checkpoint: **a487de38a96261dbeac74e701e69ce31762123f9**,
  current branch `release/private-playtest`.
- Tested/published input: `build/DoublePump_PRIVATE_TEST.rbxl`, SHA-256
  `c81b54d171a8b63eeccce8810ec138789581f8097aaacffced1d248838d1596c`.
- Downloaded cloud copy: `build/DoublePump_CLOUD_DOWNLOADED.rbxl`, SHA-256
  `f6bbec72c3f7a558d9d1400a599502f3c179225c159422e6245f49412255cd26`.
- Separate backup directory:
  `C:\Users\aaron\Documents\double-pump-backups\2026-10-21-prototype-uncommitted\verified-before-private-release-2026-10-21`.
  Contains both verified/release places, cloud copy, source ZIPs, complete Git
  bundles, pre-checkpoint diff/status and historical playtest evidence.

Before editing, all **72** script containers in the Studio-serialized verified file
matched a fresh build of checkpoint source after line-ending normalization. After
publication and Studio's cloud reload, Download a Copy was compared with the tested
release: **all 72 source containers match; no extra test scripts**. The existing
-120 FallenPartsDestroyHeight is preserved. Serialization bytes differ normally.
The comparison emitted a Lune warning about an unknown Terrain property; script
comparisons and the destroy-height assertion completed successfully.

All **52** original prototype backup checksums were rechecked: **0 mismatches**.
The original prototype checkout was not modified. Its final read-only git-status
attempt was denied by the filesystem sandbox; earlier inspection recorded its
existing uncommitted changes. No merges, pushes, resets or history rewrites occurred.
Recover either checkpoint in a fresh directory using the corresponding bundle/ZIP;
see the backup README. Restoring a cloud version is a separate publishing action.

## Bugs corrected

1. **Respawn pellet-seed state mismatch (major, corrected).** Server WeaponState.reset
   retained shotCounter while client Reset constructed fresh state at zero. This
   changed deterministic pellet patterns after death, not just log counting.
   Reset now sets shotCounter=0 on both sides. No cooldown/damage changes.
2. **Early camera-facing initialization (major, corrected).** Camera initialization
   could read the character before authoritative final placement. CharacterService
   now replicates SpawnCFrame after preparation. GameFlow waits for it and aligns
   once per character, including practice/match transitions. Opening/closing menus
   preserves existing aim. Team spawn coordinates/directions remain unchanged.

Runtime files changed: `src/shared/Weapons/WeaponState.luau`,
`src/server/Services/CharacterService.luau`, `src/client/Controllers/GameFlow.luau`.
Regression coverage: `tests/weapon_state.spec.luau` and
`tests/studio_blockers.spec.luau`. Tests were observed failing for these root causes
before the corrections; existing assertions were retained.

## Automated verification

Windows direct tool binaries were used (Rojo 7.4.4, installed Lune, StyLua, Selene,
luau-lsp and the existing Roblox definitions).

| Check | Actual result |
|---|---|
| Lune test suite | **124 passed, 0 failed** (previous 123 plus counter regression) |
| luau-lsp direct analysis | **Exit 0**, no type/syntax errors; watcher warning only |
| StyLua, Windows line endings | **Exit 0**, src/tests/tools |
| Selene src | **Exit 0**, 0 errors / 0 warnings / 0 parse errors |
| Rojo release build | Passed; includes 2 Scripts, 1 LocalScript, 69 ModuleScripts |
| Cloud/source comparison | 72/72 matching script containers; no temporary scripts |
| git diff --check | Passed |

Raw StyLua without the Windows override reported CRLF-versus-LF differences across
this Windows checkout. The line-ending-aware check passes without changing source.
Sandboxed Selene initially could not fetch Roblox's API dump; the authorized
network-enabled rerun passed. Existing extended-test lint's unused local warning
in validation.spec.luau is unchanged. The legacy typecheck shell wrapper can mask
analyzer exit status, so direct analyzer status was checked.

## Actual Studio release verification

Windows Roblox Studio 0.743.0.7431133, desktop input; solo Play and two local clients.
Device Simulator was disabled for desktop testing. Temporary passive observers
were inserted only into running tests and discarded before publication.

- Solo practice: targets loaded; both stand-in guns rendered, A and B fired,
  damage numbers appeared, switching and ammo tracking worked. Prior reload checks
  remain in the verified checkpoint report.
- Pre-death solo counters: client/server 1/1, then 2/2. After normal menu Respawn,
  first shot was client/server **1/1**; no rejection reason.
- Two clients joined through normal PLAY buttons; ordinary countdown started a
  Rooftops match with opposite teams and working timer/HUD.
- Both team facing measurements: expected SpawnCFrame horizontal direction dot
  camera direction **1.0**, with combat active. Player1's normal respawn again
  measured **1.0**; first post-respawn shot was client/server **1/1**.
- Match -> practice transition and practice -> multiplayer warmup -> next round
  all measured direction dot **1.0**, combat active. Warehouse loaded through
  ordinary results/map voting with the expected new team placement/direction.
- Original three-arena/PvP/scoring verification remains recorded in
  docs/STUDIO_PLAYTEST_REPORT.md. This release retest did not repeat every PvP,
  overtime/assist/full-round case or remeasure alternating cadence.
- Prior controlled accepted alternating intervals: **0.484–0.783 s** versus
  **1.116 s** single-gun control. All combat tuning/config/map sources are unchanged.

Initial solo direction dot was 0.9999756; a later read after mouse input was 0.9406,
which records changed player aim rather than the spawn reset. The two-client
spawn/respawn/transition readings above were taken before manual aim input.

## Owner-reported normal Roblox Player verification

After publication, Aaron confirmed from another computer: "I opened it and have
been testing it. Looks good." This confirms successful owner launch and basic
playability outside Studio. It is owner-reported evidence; no specific controls,
multiplayer cases, respawn counters, map cycles or performance measurements were
provided. The automated attempt below remains a separate, incomplete check.

## Automated normal Roblox Player verification

The experience's Roblox page loads under the owner account, displays the exact
name/description, Shooter genre and server size 10, and exposes Play. The automated
browser Play flow showed loading and then a Download Roblox prompt; it did not
provide a controllable gameplay window. An existing RobloxPlayerBeta.exe was
launched separately and showed Home logged in as supersnapstudios, including Double
Pump in Continue. Automated clicks did not open its experience details/gameplay.

**No live gameplay pass is claimed.** Main menu, practice targets, guns/audio,
controls/respawn, live server logs, live PvP, scoreboard/timers, full match completion,
map voting and all-arena live cycling remain unverified in regular Player. No second
permitted live test account was available. Studio measurements are not live-client
performance measurements. Owner manual launch was requested with the exact URL and subsequently confirmed successful as described above.

## Assets and remaining limitations

- Cosmetic: the finished shotgun mesh/textures are unimported; existing parts
  stand-ins render and embedded animation data travels inside the place.
- Cosmetic: all **29** sound IDs and map art/logo IDs remain empty. Some fallbacks
  produce approval/type warnings (swoosh.wav, 911864050, 203785492). Firing/pumping
  audio may be silent. These were not hidden or replaced for publication.
- Minor/unverified navigation: Rooftops close cover can fill the correctly oriented
  spawn view. No map redesign was attempted. Practice inherits current map lighting.
- Unverified: live DataStore persistence, latency, real-player PvP, complete round
  cycle, all-device controls, performance/FPS/memory/full lobby and arena traversal.
- No release-blocking source error was observed in the relevant Studio checks.
  This is a useful private test build, not a public launch-readiness assertion.

## Evidence and next owner action

See `docs/private-release-evidence/`: automated outputs, filtered Studio counter and
facing logs, source comparison, and screenshots of practice/teams/transitions,
publication success, Creator Dashboard Private/Private and the ten-player setting.
Historical detailed gameplay screenshots/logs are preserved under
`docs/playtest-evidence/blocker-fixes/`.

Open the experience URL in a normal browser as supersnapstudios and click Play.
Follow PRIVATE_PLAYTEST_GUIDE.md. The first useful manual check is practice fire ->
swap -> fire, reload, Respawn, and repeat. Add only explicitly approved testers
through Invite early testers later. Public release and monetization remain disabled.
No further major development phase is proposed.

## Mobile private update — version 5, 2026-10-21

Published at 2:05 PM local time to the same universe 10772275012/start place
82505574993280. Creator Dashboard published-only history shows versions 5 and 2.
Manage audience says **Only available to you and your collaborators**. No public
release or permission changes; products remain disabled. Source branch
feat/mobile-controls, base a487de38a96261dbeac74e701e69ce31762123f9, uncommitted.
Stable backup: ../before-mobile-controls-2026-10-21/; final backup:
../mobile-controls-verified-2026-10-21/. All 76 separately reopened cloud sources
match the tested final build. No runtime test probes are included.

168 automated tests pass; Rojo, type analysis, StyLua and Selene pass. Actual Studio
mobile/desktop observations and simulated-intent server timing are in
[MOBILE_CONTROLS_UPDATE.md](MOBILE_CONTROLS_UPDATE.md). Real hardware multitouch,
new live-client gameplay/rejoin, device performance and full multiplayer/map-cycle
regression remain pending. Owner received the same URL and phone/tablet checklist.
The previous owner live-client confirmation above applies to stable version 2.

## Camera and independent weapon hand � version 8

2026-10-21: published existing universe 10772275012/start place 82505574993280.
Dashboard published-only history verifies version 8, with previous version 5 retained.
Manage audience confirms Only available to you and your collaborators. No access,
product, paid access or monetization changes. Source remains uncommitted on
feat/mobile-controls, base a487de38a96261dbeac74e701e69ce31762123f9.
197 tests pass; type analysis, StyLua, Selene, Rojo pass. All 78 independently
reopened cloud scripts match the candidate. Pre-revision backup:
../before-camera-hand-revision-2026-10-21/; final backup:
../camera-hand-verified-2026-10-21/. Full screenshots, migration, tested observations
and remaining physical multitouch/live-rejoin limitations:
[MOBILE_CAMERA_AND_HANDEDNESS_UPDATE.md](MOBILE_CAMERA_AND_HANDEDNESS_UPDATE.md).

Independently reopened cloud build starts menu/practice in Studio (targets, HP 100,
weapon visible). Studio API access disabled, so no live DataStore rejoin proof.
Existing swoosh.wav asset warning remains. Normal Player/hardware test pending.
