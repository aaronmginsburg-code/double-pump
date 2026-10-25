# Developer console test report — 2026-10-25

**Owner-approved implementation committed as80a1dca and published privately asv63. See DEVELOPER_CONSOLE_PUBLISH_REPORT.md.**

## Source and preservation

Branch `feat/development-training-bots`, starting HEAD `8f0f59759538f0fef91cda449a3d98c9b01df40c`. Edits are confined to private `development-copy/source` and task documentation/evidence. All81 public source hashes match the preserved pre-task baseline, including previously dirty work. No production deployment, permissions, assets, profile data or monetization operation was performed. This verifies local source isolation; no independent post-task production cloud source download was performed.

Baseline123 permanent sources from the intact private editor matched prior v50 digest2499729693. Editor PlaceVersion51 was a saved draft, not a new published release. Clean candidate now has131 permanent source containers; stopped-editor checks verified every source hash against the baseline plus task changes and no temporary negative developer grant. Every TemporaryConsole probe was removed before downloading the intact candidate.

Backups: `development-copy/developer-console-20261025/backup/BEFORE_DEVELOPER_CONSOLE.zip` and `DoublePump_STABLE_v50.rbxl`. Clean review place: `development-copy/developer-console-20261025/evidence/DoublePump_DEVELOPER_CONSOLE_FINAL_REVIEW.rbxl`. File432781bytes, SHA256 `7a932eb9422a3a75df8fba87a91bcc520e19af90c62fb094b1996eb31e160562`. Preserve this full scene; SOURCE_ONLY Rojo files are verification artifacts, not deployment candidates.

## Automated checks

- Lune: **463 passed,0 failed**; baseline426,37 new console regression cases. Covers registry/schema/ranges/cross-field consistency, independent scoped presets, legacy migration, CAS conflicts/storage failures, defaults, runtime capacity and deadline preservation, spread/pellet consistency, movement, production guards, auto-fire stability/cancellation/readiness, responsive layout.
- Private source compile check: all Luau sources compile.
- Rojo source-only build: passed.
- StyLua: passed (exit0) on task-changed/new Luau files after formatting. See final-stylua.txt for exact exit status.
- Luau LSP: blocked by missing configured `C:/Users/aaron/tools/globalTypes.d.luau`; not a type-analysis pass.
- Selene: blocked while retrieving Roblox standard-library API dump; not a lint pass.

## Actual Studio solo observations

- Authorized owner11808586604 receives console. All five tabs rendered, scrolling/toggles/precise fields/slider dragging/reset/compare/export/diagnostics and close/reopen exercised. Slider input bug found during review was corrected. Safe-area header overlap found in phone emulation was corrected.
- Server and client Walk Speed22 and Jump Height9 applied immediately. Reset and character respawn restored20walk.
- Damage12/pellets12/capacity4 propagated through authoritative weapon revision1,12-point spread and both independent slot rules. Capacity tuning did not refill ammunition. Old action deadlines remain covered by regression tests.
- Ordinary auto-fire path produced a genuine server-accepted shot with35HP/7pellet feedback against a range target. Opening console stopped additional automatic shots. Default remains OFF. No direct damage path or artificial timing bypass used.
- Audio Gunshots bus changed to~0.2; Fire cue mute produced0gain. Engine sound inventory observed and routed separately without replacing playback. Baseline silent Running/Landing/Died remain silent.
- Export returned valid schema2 JSON with all five categories (6217bytes in runtime test).
- Existing aim response tested at normal range spawn with simulated Touch: slowdown0.94698, gentle yaw~-0.000404radians/frame, target23.03studs. Disposable solid barrier excluded target. This is simulated input, not physical touch feel.
- New store Load was attempted: Roblox rejected it with `StudioAccessToApisNotAllowed`. UI preserved active configuration and returned a useful unavailable message. **Cloud Save/Load/rejoin for schema2 remains unverified**. Studio API/security settings were not changed. Injectable store regression tests passed; previously owner-verified aim-only persistence does not prove new-store persistence.

## Actual two-client Studio test

One disposable Studio-only server grant authorized simulated UserId-1. Client-2 remained unauthorized. Genuine remote Apply/Save/Export attempts from-2 returned Not authorized; no console UI was created there. Authorized movement22 and12pellet weapon configuration reached both clients; both received reset. Test grant and helpers existed only in the disposable test server and were removed from the candidate. Actual DeveloperAccess remains the exact development IDs and sole verified owner allowlist.

This run verified security and replication, not a complete new two-human match cycle or PvP balance certification. Existing match/bot regressions passed, but full-match combat, tuning during simultaneous multiplayer reloads and all-map soak tests remain follow-up acceptance work.

## Device, visual and performance evidence

Actual Studio HD1080 screenshots: Movement,Aiming,Auto Fire,Weapons,Audio,and closed-console gameplay diagnostics. Actual Studio iPhone17Pro emulation: all five categories,gameplay controls and preset drawer. Camera viewport749×381, TouchEnabledtrue. Mobile gameplay controls intentionally hide while editing, then restore when closed. Header/launcher reserve CoreGui safe areas. These are real UI captures, not mockups. Documentary viewport crops/resizing are recorded in `docs/screenshots/developer-console/capture-manifest.json`; raw full-window captures remain in task evidence.

Ten-second Studio phone-emulation sample: mean16.66345ms/frame,worst21.8792ms,client-reported memory1532.55MB. Maximum observed auto-target scan0.243ms; aim scan0.1702ms in separate probe. Studio/process numbers do not establish real phone FPS, long-run memory stability or an isolated before/after cost. No physical phone/controller test performed this task.

## Test corrections and remaining work

Early disposable probes failed because of float exact-equality, test timing and an unsafe test teleport outside the range floor. Corrected probes passed. A temporary diagnostic attempted unsupported Sound.PlaybackState; implementation now uses IsPlaying/IsPaused and runtime review passed. These attempts are not concealed as successful tests.

After explicit UI/publishing approval: rerun required checks, commit approved files, publish only development universe10772492892/place139437092998076, verify cloud source/version and normal Player, exercise schema2 persistence on rejoin and physical mobile/controller controls. Do not publish to production10772275012/82505574993280.

## Files

- `development-copy/source/src/client/Controllers/AimAssistController.luau`
- `development-copy/source/src/client/Controllers/AudioController.luau`
- `development-copy/source/src/client/Controllers/CameraController.luau`
- `development-copy/source/src/client/Controllers/DeveloperConsoleController.luau`
- `development-copy/source/src/client/Controllers/MovementAudio.luau`
- `development-copy/source/src/client/Controllers/MovementController.luau`
- `development-copy/source/src/client/Controllers/WeaponController.luau`
- `development-copy/source/src/client/UI/DeveloperPanel.luau`
- `development-copy/source/src/client/init.client.luau`
- `development-copy/source/src/server/Services/CombatService.luau`
- `development-copy/source/src/server/Services/DeveloperTuningService.luau`
- `development-copy/source/src/shared/DeveloperConsole/AudioCatalog.luau`
- `development-copy/source/src/shared/DeveloperConsole/AutoFire.luau`
- `development-copy/source/src/shared/DeveloperConsole/Config.luau`
- `development-copy/source/src/shared/DeveloperConsole/Layout.luau`
- `development-copy/source/src/shared/DeveloperConsole/ProfileStore.luau`
- `development-copy/source/src/shared/DeveloperConsole/Registry.luau`
- `development-copy/source/src/shared/DeveloperConsole/Runtime.luau`
- `development-copy/source/tests/audio_pilot.spec.luau`
- `development-copy/source/tests/developer_console.spec.luau`

New docs: expansion audit,architecture,configuration,audio inventory,test report,user guide,publish status,rollback and sample JSON. Evidence/logs/screenshots/backups are under developer-console-20261025 and docs/screenshots/developer-console.

## Mobile launcher revision (owner-requested)

Moved only the mobile DEV launcher from the upper-right corner to the bottom, eight logical pixels left of the ammo HUD and bottom-aligned with it. Tracks actual HUD bounds for resizing. Desktop launcher and all gameplay controls retain their positions. Compile and changed-file StyLua checks passed. Review screenshots are Studio device emulation; this revision is included in private developmentv63. The earlier FINAL_REVIEW archive predates this launcher-only revision. The approved publication archive includes it; see publication/DoublePump_APPROVED_DEVELOPER_CONSOLE.rbxl.


## Post-publication verification

Fresh cloud place63 matched all131 approved source texts (digest2381679486). Studio Play from that copy opened all five categories, confirmed Auto Fire OFF and the new mobile launcher, and ordinary firing provoked the existing training duel/death path. Respawn restored 100 HP and 5+5 shells; Pump B manual equip/fire and reload back to five shells were observed. Dashboard confirms private access and production publishedv10. Normal Player did not launch through browser automation; schema2 cloud persistence, physical phone/controller input and a new full multiplayer match remain unverified.
