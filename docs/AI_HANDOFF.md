> **Public release v13 — 2026-10-28.** The owner-approved saved **Mobile** preset (schema 2, revision 3) is now the static public-source configuration. Version13 is published; read [PRODUCTION_MOBILE_PROMOTION.md](PRODUCTION_MOBILE_PROMOTION.md) for current evidence and final deployment outcome. Root `src/` is the public build; `development-copy/source/` remains the separate private development build. Older entries below describe historical checkpoints.

> 2026-10-26: **private development v68 published and cloud-source verified**, implementation `7d6a8ba`. Instant touch auto fire, head/torso acquisition and optional **Auto Swap Weapons**; 471 tests pass. Studio acquired targets in~37ms and accepted alternating shots at0.415s. Physical-device acceptance remains pending. See [AUTO_FIRE_RESPONSIVENESS_UPDATE.md](AUTO_FIRE_RESPONSIVENESS_UPDATE.md). Production unchanged.

> 2026-10-25: **private development v63 published and cloud-source verified**, implementation `80a1dca` on `feat/development-training-bots`. Five-category console plus approved bottom mobile DEV launcher.463tests pass. Public publishedv10 unchanged. New-schema cloud persistence and physical-device acceptance remain pending. See [publication report](DEVELOPER_CONSOLE_PUBLISH_REPORT.md).

## Private development correction — October 24, 2026

Development **v50 is published and cloud-source verified**, commit `b32ed9f` on `feat/development-training-bots`. The firing-range duel now ends when the owner dies: both bots clear hostility and stay passive after respawn until a fresh hit. Match deaths are excluded. **426 tests pass** and the genuine Studio death/respawn/reprovocation check passed. Public production remains unchanged. See [TRAINING_BOTS_PASSIVE_RESET.md](TRAINING_BOTS_PASSIVE_RESET.md). Older release checkpoints follow.

---

## Private development training bots — 2026-10-24

Private development **v48 is published and cloud-source verified**, implementation commit `3b2b25e348c0e9eb9edee0ba5a80c7863cadd7d0` on `feat/development-training-bots`. The current development source is `development-copy/source`; public production remains v10. Two authorized-session beginner NPCs reuse normal weapons, physical queue admission, match scoring and respawning. The developer and both bots form an intentional 1v2 roster; independently queued humans can join within normal team capacity. Bot rounds suppress all permanent progression. Human-versus-human range practice remains nonlethal. No production source, controls, combat balance, maps, profile schemas or assets were replaced.

Read [TRAINING_BOTS_UPDATE.md](TRAINING_BOTS_UPDATE.md) for exact private deployment status, source revision, backups, tests, screenshots and acceptance limits. This is a private development feature, not a production release. The candidate has 123 permanent scripts, verified against the full-scene cloud base. 424 tests pass; Studio solo lifecycle checks covered all three arenas with shortened test clocks. Physical-device difficulty/performance acceptance remains pending. Older checkpoints below are historical.

---

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
## Local Blender integration preparation — 2026-10-22

Read [BLENDER_SHOTGUN_INTEGRATION.md](BLENDER_SHOTGUN_INTEGRATION.md) before asset work. Original master recovered from fdeae963; local ShotgunModel now supports segmented imported rigs and existing skin palette tinting. Prepared FP/TP exports, PBR maps, renders and upload checklist are in `asset-integration-20261022/`. **No Roblox upload/import or publication completed. Public version 10 still uses parts; the new Rojo candidate also falls back until templates exist.** 301 tests pass via documented Lune path shim; native runner path resolution, missing LSP definitions and Selene API collection are disclosed in the report. Keep upload and publication approvals separate. Combat/config/profiles/controls/animations are unchanged.

---

# Double Pump — AI handoff

Updated 2026-10-22, America/Los_Angeles. Read PROJECT_STATUS.md and RELEASE_RECORD.md next. This is an existing playable game; preserve its working systems. Older accumulated notes remain in history/release-transition-20261022/ and Git history.

## Source and deployment authority

Current development repository: `C:\Users\aaron\Documents\double-pump-backups\2026-10-21-prototype-uncommitted\complete-game-studio`. Despite the parent folder name, this subdirectory is the active source checkout. GitHub: https://github.com/aaronmginsburg-code/double-pump, branch **feat/mobile-controls**, implementation checkpoint **4505edef94f69a251d07a6b5c014c671fcbde675**, pushed. Later documentation-only commits may follow; inspect HEAD/status before work.

The original `C:\Users\aaron\Documents\double-pump` is an older dirty prototype (claude/project-thread-19b8zl, observed HEAD 6c77104); leave it untouched. Main is the scaffold. PR #2 at 14848886 is an ancestor, not the newest gameplay implementation. The asset branch claude/project-thread-lv25xu at fdeae96367f73ca408ad190e134cdebd235defaf contains Blender masters/FBX and must be preserved separately.

Public experience: **Double Pump**, owner supersnapstudios, universe 10772275012, start place 82505574993280. https://www.roblox.com/games/82505574993280/Double-Pump . Version 10 published 2026-10-22 at 00:54PDT; later that day owner explicitly confirmed public release. Dashboard verifies Public selected / Friends unchecked, available ages 16+. Content questionnaire complete: Mild, Violence (Repeated/Mild). Broader under-16/region requirements remain unmet; no fee paid or monetization enabled. Public name/description no longer say Private Test. No new binary or gameplay changes for this release. RELEASE_RECORD.md holds evidence, rollback and remaining reach requirements. Future access/publication changes still require owner authorization.

## Game and core rules

First-person close-range TDM, up to 5v5, exclusively two identical pump shotguns with independent ammo, cooldown and reload state. Deliberately firing, swapping and firing the other gun beats waiting for one pump. Preserve this defining skill mechanic and competitive fairness. Client prediction is responsive; server combat validates state/timing, origin, pellet claims, obstruction and rewound hitboxes.

WeaponConfig actual values: same-gun cooldown 1.0 s, any-shot minimum0.4s, swap0.15s, equip0.35s, client input buffer0.1s, server tolerance0.08s. Five shells per gun, unlimited reserve, auto-reload on empty; reload starts0.3s and inserts every0.5s, visual end0.3s. Fire/swap interrupts reload, preserving inserted shells. Ten deterministic pellets at9 damage each; Head1.75x, Torso1x, Arm0.9x, Leg0.8x; full damage through9studs, linear falloff to25% at 45, max range 150. GAME_DESIGN.md contains the remaining configuration and rules.

Desktop: WASD/mouse, LMB fire, Space jump, Q swap,1/2 equip,R reload,C/LeftCtrl crouch,Tab scoreboard,M menu. Gamepad bindings exist; hardware certification remains pending.

Mobile: movement stick and displacement-based touch-and-drag aiming, **no camera joystick**. FIRE hold gives the initial shot only; a fresh deliberate downward swipe in the marked opposite-side region swaps and queues one legal follow-up while held. Release cancels pending fire. Thresholds:0.30s maximum,72 logical pixels,1.8 vertical dominance,16 upward allowance, resolution-scaled. Touch ownership separates movement/buttons/swipe/aim. Responsive button placement is the previously verified layout.

Control Layout and Weapon Hand are independent right/left preferences; all four combinations are supported. Layout mirrors touch controls/zones only. Weapon Hand affects both first-person guns, also on desktop, never ballistics or third-person/world orientation. Profile v3 migrates legacy coupled settings preserving previous presentation. DataStore name remains **DoublePump_Profiles_v1**.

## Lobby, match lifecycle and UI

All joins spawn armed in the permanent firing range with ten targets. Population never starts a match. Enter the cyan physical queue: min 2/cap 10/FIFO/15 s, server root-center bounds sampled every0.1s. Leaving below2 cancels; final sample validates the roster. Only selected players vote12s, receive balanced teams and enter the normal5s arena preparation. Others and late joiners remain in the range; next queue stays pending while the single arena is occupied.

Lobby player hits reuse the real pellet pipeline and aggregate hypothetical damage, including overkill, but never apply health loss, eliminations, competitive statistics, XP, mastery or challenge progress. Private server CombatContext records distinguish lobby/reserved/current match; replicated attributes are prediction hints, not authority. Cross-context damage is blocked. Dummies retain their target damage/respawn behavior.

Matches last300s, target40 eliminations scaled down for smaller rosters (minimum15, rounded to5). Red/Blue teams, up to5 each. Tied regulation enters60s first-elimination overtime, then draw. Normal real damage, assists, scoring and respawns apply. After9s results participants return outside the queue with full health/ammo and cleared match HUD/state; they must walk back in to requeue. Warehouse, Dust Town and Rooftops layouts/voting remain intact.

HUD: crosshair, health, dual ammo/readiness, hit/critical/damage feedback, scoreboard/timer/killfeed, queue status, vote/results, settings/profile/challenges/shop. Progression implements levels/mastery, earned coins/cosmetic skins, daily/weekly challenges, statistics and leaderboards. Paid coin-pack definitions exist but **Products.Enabled=false**, all productIDs nil; real commerce is not certified or activated.

## Architecture and important files

Rojo maps src/shared to ReplicatedStorage.Shared, src/server to ServerScriptService.Server, src/client to StarterPlayerScripts.Client. Server bootstrap sets Net/Collision, then starts Map,Team,Character,Damage,Combat,Practice,Match,Data,Progression,Cosmetic,Monetization,Leaderboard services in dependency order.

- Weapons/WeaponState,Spread,Damage,ShotValidation,PositionHistory: shared combat logic; CombatService/DamageService validate/apply; WeaponController/CameraController/ViewmodelController present/predict.
- MatchService, shared MatchRules/LobbyQueue, server CombatContext and Maps/QueueZone: admission and contexts. CharacterService transfers healthy prepared avatars, reloads actual deaths and publishes SpawnRevision for camera/weapon reset.
- Mobile/Layout,TouchState,FireSequence,DragAim,Presentation and UI/MobileControls: responsive input/presentation.
- Data/ProfileStore,DataService, Progression/Profile(v3),Levels,Challenges,Cosmetics and ProgressionService: saves and preferences/rewards.

## Evidence, limitations and next work

Fresh 2026-10-22:245/245 Lune tests; LSP no type errors; Selene0 errors/0 warnings; Windows-aware StyLua and Rojo pass.81 sources match saved Studio copy. Three-client Studio staging passes21/21 assertions across all maps, lobby feedback/100 HP/noXP, queue cancellation/admission, match elimination/score/respawn and three healthy returns. Staging anchors players and expedites round clocks only in a separate DO_NOT_PUBLISH copy. Earlier failed probes remain documented. Never publish test/capture copies.

Owner reports satisfied gameplay and prior iPhone17ProMax controls; this is user feedback, not exhaustive hardware certification. Automated normal Player launch produced no Player window. Fresh live multiplayer, saves/rejoin,10-player load and representative performance remain unverified. Studio API access is off; test profiles are session-only. Current guns are parts-based stand-ins with embedded animations;29 audio and3 map-card IDs remain blank/fallback. No new game-service blocker was observed in current staging.

Next safe task: owner fresh-server desktop/mobile acceptance and public rating/audience decision. Read ROADMAP.md, TESTING.md, DEVELOPMENT_WORKFLOW.md and AGENTS.md. Preserve history, prototype, saves and backups; no force-push, Public change, purchase or asset upload by inference. ChatGPT uploaded files and Obsidian notes are snapshots/navigation, not automatic source synchronization.

## Owner live-client confirmation — 2026-10-22 PDT

Aaron replied “it is working” to the request to launch the existing private experience in normal Roblox Player and check the firing range, weapons and queue. Those basic live-client behaviors are now **owner-reported working**. This is not agent-controlled Player verification or a claim of exhaustive multiplayer, every map, device performance, ten-player load or live-save/rejoin acceptance. No game build or audience setting changed.
