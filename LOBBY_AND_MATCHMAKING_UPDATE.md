# Firing Range Lobby and Voluntary Matchmaking

Date: 2026-10-21 (PDT). Base Git revision: a487de38a96261dbeac74e701e69ce31762123f9, branch feat/mobile-controls, with the preserved verified mobile/camera work and this update uncommitted.

## Preservation and scope

Before editing, source, tests, documentation, the binary Git patch and working-tree status were archived in `../before-lobby-matchmaking-20261021-215033/`. That checkpoint also contains the verified version-8 build `DoublePump_CAMERA_HAND_REVISION.rbxl` (SHA256 a9022a73648b3e6ebb07f14e6683ca167a349205dbc5638290839fee64c3897b). Earlier cloud versions remain recoverable. The original prototype checkout was not modified. No commits, pushes, merges, asset uploads, purchases or permission changes were performed.

The candidate is `build/DoublePump_LOBBY_MATCHMAKING.rbxl`. Instrumented `*_TEST_*DO_NOT_PUBLISH.rbxl` files are disposable local tests and MUST NOT be uploaded. The release verifier compares every production script with local source and rejects extra probe scripts.

## Behavior

All joining players spawn directly in the permanent firing range in Practice mode, with their two shotguns. Server population never admits players. The old Deploy remote only explains where to find the physical queue; it cannot select a roster. Practice/Menu actions can return a participant to the range but cannot enter a match. Desktop/mobile/controller input code and existing targets remain intact.

### Physical queue

A cyan floor area and glowing border sit in the rear corner of the existing range. The overhead display shows population, waiting/pending status and countdown. The HUD explains how to join and shows personal queue status. Notifications are throttled to reduce boundary spam, while the actual membership flag updates every sample.

`GameConfig.LobbyQueue` centralizes minimum 2, capacity 10, countdown 15 seconds and poll interval 0.1 seconds. Its range-relative volume center is (-52, 7, 37), size (18, 14, 10) studs. Existing range spawn points are outside the zone.

On each server sample, eligible living, prepared lobby characters are tested by HumanoidRootPart center against the zone's oriented bounds. This is a direct server spatial query over at most the server population, independent of Touched events. Accessories, limbs, and cosmetic extensions cannot enqueue players. Invalid/missing/dead characters and departed players are removed on the next sample (normally within 100 ms).

The pure LobbyQueue module preserves entry order, deduplicates members, restarts the full countdown after falling below two, and selects no more than ten. Same-sample ties use UserId order. Overflow retains its FIFO position while still physically present. The final deadline sample prunes membership and selects/adopts the roster without yielding. The client has no queue-admission remote.

Only one match roster can exist. When voting, starting, combat or results occupy the arena, remaining lobby players can queue but the display says next match pending. A new full countdown begins after the arena returns to Waiting.

### Match lifecycle

After physical queue admission, only selected players receive the existing map vote (12 seconds), followed by normal team assignment, arena spawn and the existing five-second arena countdown. The queue's fifteen seconds is the admission countdown; voting and arena preparation follow it. Map choices, team balance, scoring, match length and overtime remain unchanged.

Only participants receive match countdown, results and voting events. Late joiners stay in the firing range. After the existing nine-second results sequence, participants leave match membership, clear teams and temporary damage history, reset match HUD statistics, and respawn with full health/ammunition in the range outside the queue. Returning players are not automatically queued. A nonparticipant already standing in the zone retains eligibility for the next round.

Production MatchRules calls use the voluntary-admission context. Legacy pure-state-machine scenarios remain tested independently; their population-based path is not used by the server coordinator.

### Lobby versus match damage

CombatContext holds a private server table, mirrored to attributes only for client raycast prediction. Both shooter and target must be lobby players for nonlethal feedback, or opponents in the same currently active match for real damage. Reserved voters, different contexts, different match IDs, inactive matches and match friendly fire are blocked. Editing a replicated attribute cannot change server membership.

The existing deterministic spread, lag compensation, pellet claims, hitboxes, falloff, obstruction checks and Damage.total aggregation remain in use. DamageService returns the full calculated hypothetical blast total for a lobby player hit BEFORE modifying health, recording assists/double-pump history, emitting Damaged/Eliminated signals or awarding any statistics. A hypothetical overkill shot can display more than 100; real match feedback retains its existing health-capped applied-damage value. Practice dummies retain their normal health/elimination/respawn behavior without match rewards.

### Runtime defect found during this update

The first multi-round test found full-health returned characters carrying Dead=true and consequently unable to requeue. Character initialization now clears Dead/Frozen/Crouching, disables neck-death before joint conversion, ignores queued death callbacks for a healthy spawn, and marks intentionally replaced characters as retiring before LoadCharacterAsync. Retiring/replaced characters cannot schedule an extra delayed respawn. The real death handler remains connected after an ignored initialization event and processes a real death once. Healthy range/arena transfers now preserve the prepared avatar, reset its movement/health/protection state, publish a new SpawnRevision for camera realignment, and fire the existing spawn signal to reset both shotgun states. Only actual dead/missing characters use the avatar-load respawn path. This avoided the teardown races in the final three-round run.

## Files changed by this task

- New: src/shared/Match/LobbyQueue.luau; src/server/Services/CombatContext.luau; src/server/Maps/QueueZone.luau.
- Updated: GameConfig, MatchRules, Combatants, MatchService, CombatService, DamageService, CharacterService.
- Client lifecycle/text only: Controllers/GameFlow, UI/Hud, UI/MainMenu, UI/Tutorial. No control positions or functions were changed.
- Tests: lobby_queue (22), lobby_combat (14), lobby_lifecycle (12), extended studio_blockers; Loader permits a fake Instance factory for actual coordinator tests.
- Documentation and evidence in this report and docs/lobby-matchmaking-evidence.

## Verification

Baseline: 197 passed, 0 failed; type analysis, Selene, StyLua and Rojo passed.
Current automated: 245 passed, 0 failed (48 new tests plus stronger character lifecycle regression). Type analysis passed; Selene reported 0 errors, 0 warnings and 0 parse errors; StyLua passed. Rojo built successfully. The release verifier confirmed all 81 script containers exactly match local source after line-ending normalization, with no test probes included.

Protected source comparison against the checkpoint confirms unchanged WeaponConfig, mobile layout/touch/swipe/fire sequence, camera, weapon/movement/viewmodel controllers and all three arena modules (12 files). New spatial queue geometry requires no uploaded assets.

Studio: isolated local solo spawn observed with 100 HP, both full shotguns and ten targets; no forced menu. A three-client server test exercises real remotes, shot validation, hit feedback, voting and respawns. The separate test copy anchors/stages players and expedites only regulation/overtime clocks; production balance values are unchanged. Emulator/staged tests are not real phone/controller playtesting.

Final staged runtime results:

| Scenario | Observed result |
|---|---|
| Solo join | Direct armed range spawn, full health, ten targets, no forced menu |
| Three lobby players outside queue | Waiting; no automatic match |
| Nonlethal full torso blast (focused repeat) | 10 pellets, authoritative total 90, client indicator 90, target stays 100 HP |
| Nonlethal head blast | 10 pellets, authoritative total 149.85, rounded indicator 150, critical marker, target stays 100 HP |
| Lobby progression | Kills/deaths/score and profile XP unchanged |
| One queued | Waiting, count 1 |
| Second enters / then leaves | Countdown begins / cancels |
| Final admission | Two selected; outsider remains Practice; observed admission about 15 seconds |
| Waiting queue while occupied | Pending; outsider remains armed in range |
| Match PvP | Real elimination, team score +1, normal respawn |
| Warehouse / Dust Town / Rooftops | All loaded through selected-player votes and normal arena countdown |
| Return / repeat queue across three rounds | Full health/ammo, lobby controls active, postgame hidden, no automatic requeue |
| Actual queued-client disconnect | Kick request was asynchronous; after actual removal, 2 connected players / 1 queued / Waiting, countdown canceled |
| Actual late join during Active | Player4 Practice, neutral, range x=-1254; existing roster remains exactly two |

Run 1 and run 2 retain failures found during development; they are not release passes. Run 3 passes the three-round lifecycle, headshot and match tests but its first scripted body shot missed (no hit), leaving one probe failure. A separate stabilized repeat confirmed a player torso hit for exactly 90 with unchanged 100 HP. The supplemental one-second Kick assertion sampled before the disconnect request was processed; the later explicit server snapshot confirms correct settled membership. These diagnostics are retained rather than relabeled as passes.

Screenshots: `01-solo-default-range.jpg`, `02-match-results.jpg`, `03-personal-countdown.jpg`, `04-queue-zone-before-board-adjustment.jpg`, `05-final-queue-zone-waiting.jpg`. The board was lowered three studs, to 9.06 above the floor origin, after visual inspection to clear the existing HUD; input/HUD control positions did not move.

No game-service startup failures were seen in the final run. Studio emitted existing sound permission/fallback warnings and Roblox CoreGui chat registration errors in simulated clients. Several simultaneous Studio sessions caused graphics frame-query stalls over 100 ms; this environment is unsuitable for a representative performance benchmark. Actual hardware, ten-player network load, and exact disconnect-at-deadline races remain separate manual checks; deterministic race cases have automated coverage.

## Private publication

Published successfully to the existing experience as **version 9**, October 21, 2026 at 10:47 PM PDT. Creator Dashboard version history shows version 9 published, with version 8 still available for restore. After publication, Manage audience explicitly confirmed: "Only available to you and your collaborators." No access or monetization settings were changed.

The published-place Studio editor passed a solo smoke test: direct range spawn, 100 HP, two shotguns, targets and the new queue instruction banner. This is Studio verification, not a normal Roblox Player test. A fresh live-client session and actual mobile multiplayer acceptance remain owner checks.

Candidate SHA256: 99ACCD4C34C956D5201D2FA963F055E4DB6DC1D525AB0478FE0E192FF56AD770. The verified candidate and source/test archive are retained in `../lobby-matchmaking-verified-20261021-224508/`. Final publication evidence and this completed report are copied there separately.

Publication evidence: `docs/lobby-matchmaking-evidence/06-published-version9.png`, `07-private-access.png`, and `08-published-lobby-smoke.jpg`.

Existing destination only: universe 10772275012, start place 82505574993280, https://www.roblox.com/games/82505574993280/Double-Pump . No public-access or monetization setting changes are authorized or needed.

## Known limitations and remaining manual checks

- Ten-player capacity/FIFO overflow and same-deadline disconnect races have automated coverage; actual ten-client network load is not measured.
- Actual phone/tablet/controller movement into the zone and long-session boundary behavior still need owner playtesting. Existing input implementations are unchanged.
- Studio's local place has no live profile persistence; test profiles fall back to session storage. Live persistence is outside this update's schema (no save shape changed).
- Existing stand-in shotgun and missing/fallback cosmetic audio/texture warnings remain; no assets were replaced or uploaded.
- No frame-rate, memory or network-performance guarantee is inferred from passing logic tests.

## Manual acceptance

1. Join a fresh private server; remain outside the cyan queue with a friend. Practice, shoot each other and confirm feedback with 100 HP/no career gains.
2. Enter alone: one queued, no countdown. Have the second player enter, then leave: countdown cancels.
3. Both enter and remain for 15 seconds. Only selected players vote, receive teams, and spawn into the chosen arena after its normal preparation countdown.
4. A late joiner stays in the range and may wait in the pending queue; they never enter the running match.
5. Finish a round. Participants see results, return with full health/ammo outside the zone and must walk back into it to queue again.
6. Repeat on mobile and across Warehouse, Dust Town and Rooftops. Record device, map, queue state, player count, screenshots and logs for any failure.
