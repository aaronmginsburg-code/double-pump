Current follow-up: private **v50** fixes range-duel hostility after owner death. See [passive reset report](TRAINING_BOTS_PASSIVE_RESET.md). The originalv48 implementation record follows.

# Private development training bots

2026-10-24 local date. **Published privately as development v48.** Implementation commit `3b2b25e348c0e9eb9edee0ba5a80c7863cadd7d0`, branch `feat/development-training-bots`, based on `4f70b958f96ad57510f03c62f4cfceb17b11d3bc`. Public production remains published v10.

## Operation and isolation

The existing development destination is universe **10772492892**, start place **139437092998076**: https://www.roblox.com/games/139437092998076/. `DeveloperAccess` requires both exact IDs and explicitly permits developer UserId **11808586604**. Production universe **10772275012** / place **82505574993280** is excluded.

Two named R15 humanoids, Training Bot 1 and Training Bot 2, appear for the authorized developer. They have normal 100 HP, existing third-person Blender shotguns, distinct teal/orange clothing, BOT labels, normal movement limits, procedural locomotion/jump/reload poses and existing replicated pump/recoil/equip effects. No avatar account is impersonated and no asset was uploaded. They remain passive until a validated developer shot hits one. Both then retaliate against that developer, with normal protection, damage, death and respawning. Uninvolved humans remain protected from bots; human-versus-human range shots remain hypothetical and nonlethal.

Walk into the existing MATCH QUEUE to bring both bots into the queue. They navigate there physically; admission uses the normal server root-center checks, FIFO order and final liveness validation. Leaving cancels their eligibility immediately while they walk home. A 20-second navigation failure reports the problem and requires leaving/reentering to retry; no teleport fallback or synthetic roster is used. Dead, missing or capacity-excluded bots cannot be silently injected. The owner and pair must fit together; earlier eligible human FIFO entries can proceed independently.

The normal queue minimum 2, maximum 10, 15-second countdown, 0.1-second occupancy sample, map vote and one-active-arena lifecycle remain. The training owner is Red and both bots Blue. Additional independently queued humans are assigned deterministically by UserId to the smaller team, capped at five each. Death rebalancing is suspended only for this intentionally asymmetric training roster. Late joiners stay in the range. Results return participants to full-health, full-ammo range spawns outside the queue; bots become passive. Owner disconnect removes their bots and resources.

Any round containing these bots is permanently marked `training` for its entire lifecycle. `ProgressionService` rejects that result before profile reads/writes or reward notifications. XP, coins, mastery, challenges, permanent match statistics and leaderboard progress are not awarded to any participant in a training round. Profile schema and stores are unchanged.

## Architecture and changed source

All implementation changes are under `development-copy/source`; root production source is preserved.

New modules:

- `shared/Training/Beginner`: centralized decision/error configuration.
- `shared/Training/Policy`: pure team, FIFO group selection, context, perception and lifecycle rules.
- `server/Services/Participants`: registry of opaque server NPC records alongside real Players. NPCs are not fake Players and have no client remotes.
- `server/Services/BotNavigation`: throttled PathfindingService paths, waypoint progress, blocked-path recovery and explicit cleanup.
- `server/Services/TrainingBotService`: authorized-session ownership, two-rig lifecycle, perception, beginner combat, physical queue following and cleanup.

Extended modules: CharacterService, CombatContext, CombatService, DamageService, MatchService, TeamService, ProgressionService, server bootstrap, EffectsController, Scoreboard and Postgame. Existing human remote validation remains; bot actions are callable only on registered server NPCs. `WeaponState` supplies the same legal fire/swap/reload rules with zero timing tolerance for NPC actions. Both paths use deterministic pellet Spread, obstruction raycasts, `Damage.total` and the sole DamageService health application path. NPC shots use current server geometry without artificial latency or lag rewind. Tagged bot bodies enter existing position histories for genuine human shots.

Server decisions run at 10 Hz and perception at 4 Hz. Paths are asynchronous and rate-limited; stale paths/listeners are destroyed. Targets require living, opposing, same-context membership and unobstructed line of sight. Bots retain only a short last-seen point, then investigate known map positions rather than hidden live opponent coordinates. They occasionally strafe or reposition toward cover. They use independent ammo states, deliberate swap/reload delays, bounded aim error and turn speed; they receive no extra damage or spread advantage.

## Beginner configuration

These affect AI decisions only, not shared weapon balance.

| Parameter | Initial value / units |
|---|---|
| Reaction | 0.65–1.15 seconds |
| Base aim error | 4.5 degrees |
| Moving-target additional error | 3 degrees |
| Aim tracking / turn cap | 3.5 per second / 2.3 radians per second |
| Movement decision / reposition | 1.3 / 2.4 seconds |
| Preferred engagement distance | 20 studs |
| Decision delay before switching | 0.22–0.48 seconds |
| Inefficient-switch chance | 22% |
| Reload decision delay | 0.7 seconds |
| Acquisition range / field of view | 110 studs / 150 degrees |
| Last-seen persistence | 2.2 seconds |
| Minimum path interval | 1.5 seconds |
| Waypoint timeout / queue timeout | 3 / 20 seconds |

Shared configuration remains authoritative: same-gun cooldown 1.0 seconds, minimum shot interval 0.4, swap 0.15, equip 0.35, five shells per gun, 100 HP, 2.5-second respawn and normal movement/protection. No damage, timing, input, map or monetization configuration was changed.

## Verification

424 automated tests pass, including 26 new training tests. They cover registration/count/guards, independent NPC identity, passive retaliation gating, isolated real damage, ordinary nonlethal human practice, cross-context denial, removal, FIFO/countdown cancellation/capacity, 1v2 and expanded teams, perception and progression suppression. Pure/mocked tests do not establish runtime behavior by themselves.

The private Luau compile check passes. Rojo source build passes and is not a deployment artifact. Changed-file StyLua result and final source comparison are recorded in the evidence folder. Selene cannot obtain its Roblox API standard library; Luau LSP cannot find the configured globalTypes definitions. These are blocked checks, not clean lint/type-analysis results.

Actual Studio solo tests completed Warehouse, Dust Town and Rooftops through physical bot admission, team assignment, live client firing/server damage, bot shots/eliminations, normal respawns, results and passive range return without automatic requeue. The disposable harness shortened each match clock only after 35 seconds of genuine combat; these were not full five-minute endurance matches. Observed alternating bot shot intervals included 0.538, 0.666 and 0.750 seconds, enforced through normal WeaponState eligibility. A real ground-waypoint/root-height navigation issue found during testing was corrected and given regression coverage.

The first multiplayer harness timed out during slow client startup; another first-shot staging check was inconclusive. A fixed two-second wait for a staged owner walk-out also finished before queue cancellation was observed; the final harness waited for actual occupancy to clear. Disposable probes are excluded from deployment. Final results follow.

### Completed two-client Studio acceptance

The final server log completed `BOT_MULTI_COMPLETE` at 2026-10-25 05:49:18 UTC (October24 local). Two genuine simulated Studio Players were used, with a temporary runtime-only authorization of the negative Studio owner ID; this grant and all test scripts were removed afterward. Human practice hit registration preserved100HP. Both bots fired in the owner duel while the uninvolved tester remained100HP and was context-blocked from bot attacks. Only the owner plus pair entered the first queue. Leaving canceled it; reentry with the independently queued second human admitted a2v2 Rooftops match, humansRed/botsBlue.

After40seconds of genuine combat the disposable harness shortened the round clock. Blue won0–2, MVP identified Training Bot2, the results UI displayed TRAINING—NO REWARDS, and both humans returned with100HP and5+5shells. Before/after in-memory XP, coins, mastery and every permanent-stat field were unchanged. Owner disconnect removed both NPC records and active models; the other human remained safely in the range. No persistent test progress was written.

Measured986 server decision steps, maximum observed synchronous two-bot step **22.23ms**, with18and23successful paths and zero failed path computations in that run. This is a worst observed step on a machine running several Studio processes, not average overhead or a physical-device performance certification. Async path-compute time and long-session memory were not separately measured. Further profiling on a representative live server is recommended if spikes are visible.

Visual evidence is in `development-copy/training-bots-20261024/evidence/`: `two-passive-bots.png`, `bots-physical-queue.png`, `match-live-staged.png` (solo DustTown), `multiplayer-bot-elimination.png`, and `multiplayer-results.png`. Results table text clips in the narrow Studio viewport; the MVP/training reward indication is readable. This pre-existing fixed-width table was not redesigned as part of the bot feature.

Final changed-file StyLua check passes. All123 permanent script paths and source texts in the intact archived candidate exactly match the local manifest; digest3907900398. The archive has no TemporaryBot scripts or negative-ID authorization. The new humanoid rigs are generated at runtime, not saved test models. See `solo-runtime.txt`, `multiplayer-runtime.txt`, `automated-tests-final.txt`, `compile-final.txt`, `selene.txt` and `type-analysis.txt` for evidence and blocked-tool details.

Known acceptance limits: real phone/controller performance and subjective beginner difficulty need owner playtesting; ten-participant load, long-session memory behavior and all navigation failure permutations have not been certified. Procedural avatar locomotion/reload presentation reuses existing rigs; no new uploaded animation clips were created. Studio API access is disabled, so test profiles are in-memory fallbacks, not production inventories.

Studio observed owner disconnect cleanup after results, not a mid-round disconnect. Full-queue partial-group selection, capacity, wrong-context denial and production guards have automated coverage; full-capacity runtime admission, disconnect at the final countdown tick, failed avatar-generation/network requests and all dead-bot admission races remain manual reliability tests. No physical phone/controller test or normal Roblox Player acceptance of this feature is claimed.

## Verified development publication

- Universe10772492892 / place139437092998076, unchanged private access: only owner and collaborators.
- Published **v48**, Studio success logged2026-10-25T05:52:46.941Z (October24local). Creator Dashboard's **Show published only** lists48; its version timestamp displays October24 at10:51PM, corresponding to the saved version that was then published.
- Reopened the cloud place and checked `game.PlaceVersion==48`, both IDs, all123 permanent paths/source texts and digest3907900398. No test probes remained. A fresh Studio Play from that cloud copy started the training service and normal range/weapons; it was stopped afterward to release game input. This is Studio verification, not an independent live Roblox Player session.
- Public place82505574993280 still shows latest publishedv10 after this deployment. All81 production-source file hashes match the pre-task snapshot; its pre-existing dirty ShotgunModel file was preserved.
- No asset upload, access change, purchase, monetization activation or production publication occurred. No Git push was performed.

Intact candidate: `development-copy/training-bots-20261024/backup/DoublePump_DEVELOPMENT_TRAINING_BOTS.rbxl` (417131bytes, SHA256 `FA9016BB1032139175D831AA668073389A9F52438A3372E3801BF49A0C4C02EB`). Previous stablev39 SHA256 `ED30FB50BE87D84BB222250906485770707BE1F47762BF422D66AE78239D603A`. Detailed source manifests, runtime logs and Dashboard screenshots accompany this report in the task evidence folder.

Owner acceptance: join a fresh private development server as supersnapstudios, shoot a bot for the range duel, then walk into MATCH QUEUE for1v2. Leave during countdown to cancel. A completed training match returns everyone to the range and requires a fresh voluntary queue entry. Existing public game is not the test destination.

## Backup, rollback and documentation

`development-copy/training-bots-20261024/backup/BEFORE_TRAINING_BOTS.zip` preserves private source/assets/docs, and `DoublePump_DEVELOPMENT_V39.rbxl` is the intact previous published build. Restore private published v39 through development place version history, or publish that intact backup only to the exact development IDs after source/destination verification. Never publish an INSPECTION_ONLY normalized archive or source-only Rojo place over the full-scene cloud place.

Refresh ChatGPT Project copies of AI_HANDOFF, PROJECT_STATUS, GAME_DESIGN, ROADMAP and RELEASE_RECORD after this feature's final record is written. Obsidian's Double Pump overview, AI handoff, source inventory, known issues/next actions and dated development history need a curated update through the established vault import workflow; this task does not claim those external copies were synchronized automatically.
