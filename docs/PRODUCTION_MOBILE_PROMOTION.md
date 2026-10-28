# Mobile preset and development content promotion â€” 2026-10-28

Status: validated release candidate. Roblox publication is waiting at its explicit asset-permission grant. GitHub integration is being completed; verified results are recorded below.

Owner explicitly authorized applying the saved mobile settings and development content to the existing public Double Pump experience, committing, pushing and merging main. This supersedes prior task-specific development-only publication limits for this release. It does not make the developer console, training NPCs, all-skin overrides or development tuning storage public features.

## Identity and preservation

- Production: universe **10772275012**, place **82505574993280**; https://www.roblox.com/games/82505574993280/Double-Pump . Published-only Creator Dashboard history confirmed v10 before work. Studio opened saved draft v11 with 81 sources; downloading an unchanged rollback copy saved a later draft, not a publication.
- Development: universe **10772492892**, place **139437092998076**. All 131 cloud scripts at saved draft v69 match the published v68 source digest **644707714**. No development scripts were changed by this promotion.
- Original source checkout: `../complete-game-studio`, branch `feat/development-training-bots`, HEAD `b55a144`. Existing dirty files and untracked asset/audio work preserved. Original older prototype is untouched.
- Isolated release checkout: `../production-release-20261028`, branch `release/mobile-live-20261028`, based on b55a144. Fetched remote main is scaffold `bae36c9c2dee10dcd3b95c999d86ccb7cff0e155`, an ancestor. No remote history was overwritten.
- Source/document backup: `../complete-game-studio/release-20261028/BEFORE_PROMOTION.zip`, SHA256 `A09BA03AB455DC400718669714EB6573478B254AE93EE577E5C2A78280B826A9`, plus binary Git diff and status.
- Fresh production draft backup: `release-artifacts/DoublePump_PRODUCTION_BEFORE.rbxl`, SHA256 `6FC35EF92D1B0A1A00CB244591542D14961CD6300D0D870830427B99B3883716`.
- Intact published-development v68 base: `release-artifacts/DoublePump_DEVELOPMENT_v68_BASE.rbxl`, SHA256 `329C20F5BF288EFB847A6602E0E9B8113406C35BA44709A27942B7D97843BD36`.

## Exact owner preset

Read-only Creator Dashboard Data Store Manager retrieval: store `DoublePump_DevConsole_v2`, scope `u10772492892`, key **`u11808586604_all_Mobile`**, name **Mobile**, schema 2, revision **3**; version `08DF34CBECB3D8B0.0000000003.08DF34CF2D48AD41.01`, displayed October 28 at 1:40 AM. No preset/profile writes performed. Full copied record is `release-artifacts/Mobile.owner-saved.json`; its canonical sorted JSON is 6,127 characters, polynomial-31 checksum **3116085691**, independently matched to the actual browser-visible record.

The complete record is embedded as static `src/shared/Config/ReleasePreset.luau`; no public server reads the development DataStore. Both client and server load the same shared movement and weapon configuration before constructing weapon states.

| Area | Approved values |
|---|---|
| Movement | walk 28.5 studs/s; crouch 11; jump 14 studs; air control 0.64. Sprint remains unavailable/disabled; its inert saved value is 24. Acceleration, deceleration, slide/friction remain unavailable. |
| Aim assist | enabled for touch/controller; mouse disabled; radius .08 shorter-screen fraction; distance 93 studs; slowdown .54; rotation .4; tracking 18; hysteresis .2; LOS required; sensitivity/input strength multipliers 1. |
| Auto fire | touch enabled, controller/mouse disabled; auto swap enabled; radius .025; distance 150 studs; delay/persistence 0; interval .4 seconds; LOS required. |
| Weapons | 17 damage/pellet; 10 pellets; spread multiplier .4; range 214 studs; falloff 9â€“45 studs to .25 multiplier; 6 shells; reload .3/.27/.3 seconds; recoil 2.2Â°, recovery .12 seconds. |
| Preserved timing | same gun 1.0 s; global minimum .4 s; swap .15 s; first equip .35 s; existing server validation and head/limb multipliers retained. |
| Audio | complete owner-record mix retained, including footstep bus .23 and individual footstep baselines .13. Personal volume preferences still apply separately. |

Balance implication: a full close torso blast now calculates **170 damage**, and a full head blast **297.5**. This is the owner's explicitly approved preset, not an independently selected balance change. Existing tests were updated to assert the new concrete damage and six-shell configuration; timing, ammunition consumption, reload interruption and nonlethal lobby guarantees remain tested.

## Promoted content and isolation

- Original Blender FP/TP shotgun templates, surfaces, region tinting and all ten existing baked animation clips. No new asset upload. Existing skin ownership/equip logic retained.
- Approved 51-cue audio library, movement-surface cues, action/lobby notifications, and quiet footstep mix.
- Feedback board geometry and existing backend/client. Public namespace **UFeedback_doublepump_public_v2** is distinct from development feedback; production native guards require the exact production IDs. Text filtering and existing moderation allowlist retained. Studio refuses production storage and needs isolated memory adapters; its warning is not evidence of cloud failure.
- Public `AimAssistController` and `AutoFireController` reuse tested policy/trigger and visibility logic. Static preset replaces developer transport. Normal server weapon request, timing, ammo and hit validation remain authoritative.
- No `DeveloperTuningService`, `DeveloperPanel`, `DeveloperConsoleController`, `TrainingBotService`, `BotNavigation`, `DevelopmentIdentity`, `DevelopmentSkins`, or `DevelopmentSkinReady` entry points in the candidate. Public `DeveloperAccess` denies everyone, including the owner. Registered-participant compatibility code remains but cannot register a public training NPC.
- Normal nonlethal human lobby combat, voluntary queue, standard balanced human matches, progression, monetization-off state and three arenas remain.

## Build and verification boundary

Deployment uses the intact Studio scene, never the source-only Rojo verification build or an inspection-normalized place. Full source manifest currently contains **125 permanent scripts**; `release-artifacts/source-manifest.json` and `verify.command.luau` define the current expected digest. Disposable Studio probes must be removed and the full manifest checked again before saving/publishing.

Reproducible asset models were extracted separately for Rojo/Git: `assets/roblox/Weapons/PumpShotgun_FP.rbxm`, `PumpShotgun_TP.rbxm`, and `assets/scene/UniversalFeedbackBoard.rbxm`. Old Lune reflection warns about new SurfaceAppearance emissive content and Terrain fields during inspection; the actual publication scene is preserved through native Studio, not that decoder. Extracted models contain the established non-emissive authored art. No terrain is reconstructed from the diagnostic copy.

Roblox's current [asset-privacy documentation](https://create.roblox.com/docs/projects/assets/privacy) states creators can use their own assets in their own published games. The approved shotgun/audio assets were uploaded under supersnapstudios, also the production owner. Fresh published-client asset loading still requires runtime verification; Studio owner loading alone is insufficient proof.

## Tests so far

- Unchanged development suite: **471 passed, 0 failed**.
- Public suite including imported model, audio, aim policy and new promotion assertions: **399 passed, 0 failed**. Raw output in `release-artifacts/automated-tests.txt`.
- Luau compilation: passed. Rojo with committed geometry/templates: passed. StyLua source/new regression file: passed.
- Selene 0.27.1 blocked by current fetched Roblox standard-library schema (`lua_versions` unknown); not a clean lint result. LSP definitions `C:/Users/aaron/tools/globalTypes.d.luau` remain absent; no clean type-analysis claim.
- Studio simulated-touch run verifies production isolation, actual server-accepted auto shots, wall exclusion, UI fence and keyboard trigger exclusion. Initial fixtures had a 10-pixel emulated projection offset and a 100-HP target that respawned between shots. Subsequent fixtures center the actual projected reticle and use a durable disposable practice dummy for cadence measurement. Final fresh-run results are to be recorded below.
- Physical phone/controller and fresh normal Roblox Player acceptance are not yet verified in this task.

## Rollback

Production v10 remains the pre-promotion published rollback version in Creator Dashboard. To roll back with owner authorization, restore v10, open that saved version in Studio and publish to universe10772275012/place82505574993280. Restoring alone does not publish. Local full-place rollback and development base are preserved above; no profile schema changes or production tuning DataStore migration are involved. Keep public feedback data separate and do not delete its records during rollback. Git rollback should be a new revert commit, never history rewriting or force-push.

## Final local runtime evidence

Fresh iPhone17Pro Studio simulation (not physical phone): centered target auto-acquisition 0.00223s; alternating server-accepted shots0.41588s apart; wall obstruction, UI focus and keyboard-auto-fire exclusion pass. Respawn restores100HP,6shells per slot,walk28.5,jump14 and resetshotcounter. Maximum observed acquisition scan0.3221ms in this small desktop-hosted scene, not hardware performance certification.

Two real simulated Studio clients passed initial lobby population/ten targets, authoritative body159.8->160 feedback, head297.5->298feedback with health100, no lobbykill/death/score/XP, one-playerwaiting,two-playercountdown and cancellation, Warehouse admission/load,PvPelimination/scoring andrespawn,return-to-range health/ammo,noautoqueue. DustTownload/returnalso passed; finalRooftopsresults are pending below. Disposablefixturepositionscharactersandacceleratesroundclocks; it does not bypass normal client/server firing validation. Initial serverfixtureexpired waiting forclients duringStudio startup; retest began oncebothclientsconnected. Duplicate debug shot log lines are two test-observer connections from restarting the fixture, not duplicate accepted shots (eachshotconsumedone shell).

## Multiplayer completion and publication checkpoint

All **20 staged two-client assertions passed**, with zero failures. Warehouse, Dust Town and Rooftops each loaded through the physical queue and normal voting/activation flow, then returned both players to the firing range. Real PvP elimination, team scoring and normal respawn passed. Test clocks were shortened only in the disposable fixture. Evidence is in `docs/release-evidence-20261028/`; screenshots show an emulated mobile queue state and return to the range, not physical-device certification.

All disposable probes were removed. Native Studio confirmed **125 permanent sources / digest433540397**, imported FP/TP templates and feedback-board geometry, with no developer/bot/skin override entrypoints. Saved intact candidate SHA256 **02E21C4F2022B485673514118D7B9E6FD995FF7067164C76CA7F33148B928FCA**.

Studio's Publish As service explicitly logged targetUniverse10772275012 and targetPlace82505574993280. Roblox then paused at **Grant Permissions and Publish** for promoted assets. Publication is not yet confirmed. Owner action was requested; no permission or audience change was automated.

## Current source layout and future updates

Public root source contains the static owner-approved configuration, ordinary profile store, normal cosmetic ownership and enabled gameplay presentation. Private source remains `development-copy/source/` and retains the tuning console and bots. Change private presets freely there, then explicitly promote approved values into `ReleasePreset` for future public releases; public servers never query development tuning storage. Existing profile schema and monetization-off state are retained.

Refresh AI_HANDOFF, PROJECT_STATUS, GAME_DESIGN, ROADMAP and RELEASE_RECORD in the ChatGPT Project after this promotion. Obsidian was not changed during this task. Do not infer automatic synchronization.

## Confirmed public publication

**Public version13 was published on2026-10-28 at09:51:56Z (02:51:56 PDT)**. Creator Dashboard's **Show published only** list includes13 as current, then10/9/8/7/5/2. Owner completed the asset grant; Studio logged productionUniverse10772275012 granted access to26assets and PublishSuccessful. No new experience, audience change or monetization activation.

Studio subsequently hit its known background script-version history rate-limit/close issue (HTTP429 frompublish/v1/Scripts). This does not invalidate the independently confirmed published-version record. Fresh cloud source parity and normal Player acceptance are checked separately; do not treat the success toast as runtime proof.
