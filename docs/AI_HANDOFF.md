# Double Pump — AI handoff

Updated 2026-10-22, America/Los_Angeles. Read PROJECT_STATUS.md and RELEASE_RECORD.md next. This is an existing playable game; preserve its working systems. Older accumulated notes remain in history/release-transition-20261022/ and Git history.

## Source and deployment authority

Current development repository: `C:\Users\aaron\Documents\double-pump-backups\2026-10-21-prototype-uncommitted\complete-game-studio`. Despite the parent folder name, this subdirectory is the active source checkout. GitHub: https://github.com/aaronmginsburg-code/double-pump, branch **feat/mobile-controls**, implementation checkpoint **4505edef94f69a251d07a6b5c014c671fcbde675**, pushed. Later documentation-only commits may follow; inspect HEAD/status before work.

The original `C:\Users\aaron\Documents\double-pump` is an older dirty prototype (claude/project-thread-19b8zl, observed HEAD 6c77104); leave it untouched. Main is the scaffold. PR #2 at 14848886 is an ancestor, not the newest gameplay implementation. The asset branch claude/project-thread-lv25xu at fdeae96367f73ca408ad190e134cdebd235defaf contains Blender masters/FBX and must be preserved separately.

Private experience: **Double Pump [Private Test]**, owner supersnapstudios, universe 10772275012, start place 82505574993280. https://www.roblox.com/games/82505574993280/Double-Pump . Version 10 published 2026-10-22 at 00:54PDT; private owner/collaborator access confirmed. RELEASE_RECORD.md holds exact evidence, rollback and public-release requirements. Public access requires separate final owner approval.

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
