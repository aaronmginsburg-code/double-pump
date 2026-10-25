# Development training bot audit

2026-10-24. Current branch feat/development-training-bots, based on4f70b958 (private aim assistv39). Owner persistence-confirmation documentation remains dirty and preserved. Original prototype/public root source untouched. Before-change backup and intactv39 place are in development-copy/training-bots-20261024/backup.

Verified development target: universe10772492892/place139437092998076, developer UserId11808586604 from server DeveloperAccess allowlist. Production universe10772275012/place82505574993280 is excluded. The exact development identity and118-source baseline must be verified in editor/cloud before patching or publishing.

## Current architecture and integration

- MatchService owns one MatchRules state machine, server-root physical occupancy, FIFO LobbyQueue,15second countdown,12second vote,5second preparation, results9seconds and lobby return. Queue minimum2/cap10/poll0.1seconds. LobbyQueue already supports generic keys; it never sees client queue requests. MatchService currently gathers only Players, so an NPC participant adapter is needed rather than fake Player instances or remote spoofing.
- TeamService uses Player.Team and per-team cap5; death rebalancing would undo a1v2 test unless narrowly disabled while a developer bot roster is active. Ordinary human-only logic must remain the fallback.
- CharacterService prepares avatars,100HP, walk20/crouch11/jump7.6, protection2seconds, death ragdoll and Blender TP WorldShotgun+IK. Player loading uses LoadCharacterAsync, which cannot load NPCs. Reuse preparation/mounting/ragdoll for server-created normal humanoid rigs with no account impersonation.
- CombatService owns real human remote validation and deterministic10-pellet Spread, world obstruction,20Hz PositionHistory and bounded0.4second lag rewind. Add a registered-NPC server entry point using WeaponState, live server raycasts, Damage.total and DamageService; no rewind or tolerance bonus is necessary for server AI. Tagged bot bodies participate in the existing human-shot history checks.
- DamageService is the sole health subtraction path, aggregates actual pellet damage, protection, assists and elimination signals. CombatContext holds server membership independent of replicated attributes. Extend it for registered NPCs and a per-owner lobby training pair; ordinary human-human lobby resolve remains Practice, cross-context remains Blocked. Training duels do not mutate the owner's normal Lobby membership or expose them to other players.
- ProgressionService awards all persistent match rewards from MatchEnded, not individual hits. Mark any roster containing a training bot permanently reward-ineligible for that entire round, even if bots disappear. Reject training results before touching DataService. NPCs must never enter profile, cosmetic, commerce or leaderboard APIs.
- EffectsController can already render remote shots by character model, imported TP gun/pump animation and AimPitch; needs NPC tag discovery for equip/pose/reload presentation before the first shot. Existing score/results UI needs explicit BOT rows, not fabricated Player objects.
- Existing ten stationary/moving practice dummies remain separate, Dummy=true, passive and unchanged. New two humanoid opponents use TrainingBot identity and normal hit zones; never Dummy=true.

## Scope and deterministic behavior

Exactly two bots per authorized session, bound to the lowest authorized connected developer UserId (currently one allowlisted owner). Other humans remain ordinary lobby users until independently physically queued. Bots follow only their owner, never start without the owner, are excluded if owner absent/dead/outsidequeue or both bot roots/liveness/capacity cannot be validated. Admission uses the actual sampled roots and existing LobbyQueue deadline. Selected humans retain FIFO; an incomplete owner+pair selection is rolled back/reported rather than injected.

A bot round assigns owner Red and both bots Blue; additional selected humans sorted by UserId fill the smaller team with total cap5 each. Late joiners stay lobby. Do not rebalance this intentional training roster on death. When owner leaves, bots cancel/despawn; ordinary MatchRules low-player timeout handles an abandoned round. Results keep temporary stats while permanent rewards are suppressed for every participant in a bot round.

Beginner perception/decision/pathfinding budgets and explicit lifecycle state will live in separate modules. No new assets/uploads, weapon balance changes, auto-fire for humans, input changes or production deployment. Physical hardware/AI difficulty quality require actual acceptance, not just unit tests.
