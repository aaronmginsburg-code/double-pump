> 2026-10-25 local development candidate: five-category developer console implemented in `development-copy/source`; **owner approved desktop/mobile UI and authorized private development publication; deployment verification in progress**. See [test report](DEVELOPER_CONSOLE_TEST_REPORT.md), [architecture](DEVELOPER_CONSOLE_ARCHITECTURE.md) and [user guide](DEVELOPER_CONSOLE_USER_GUIDE.md). Public gameplay/configuration remains unchanged. Schema2 cloud persistence and physical-device acceptance are pending. Historical published records below remain historical.

## Private development training bots — 2026-10-24

Private development **v48 is published and cloud-source verified**, implementation commit `3b2b25e348c0e9eb9edee0ba5a80c7863cadd7d0` on `feat/development-training-bots`. The current development source is `development-copy/source`; public production remains v10. Two authorized-session beginner NPCs reuse normal weapons, physical queue admission, match scoring and respawning. The developer and both bots form an intentional 1v2 roster; independently queued humans can join within normal team capacity. Bot rounds suppress all permanent progression. Human-versus-human range practice remains nonlethal. No production source, controls, combat balance, maps, profile schemas or assets were replaced.

Read [TRAINING_BOTS_UPDATE.md](TRAINING_BOTS_UPDATE.md) for exact private deployment status, source revision, backups, tests, screenshots and acceptance limits. This is a private development feature, not a production release. The candidate has 123 permanent scripts, verified against the full-scene cloud base. 424 tests pass; Studio solo lifecycle checks covered all three arenas with shortened test clocks. Physical-device difficulty/performance acceptance remains pending. Older checkpoints below are historical.

---

## Private development audio — 2026-10-24

Private universe10772492892/place139437092998076 is now **publishedv24**, adding the five owner-selected surface-footstep/landing cues (51 total configured audio cues). New presentation-only movement audio replaces default Running/Landing without layering; movement/combat configuration, controls, profiles and public game are unchanged. Current authority is development-copy/source, branch feat/mobile-controls @ b90e77a plus preserved uncommitted private changes. **377 tests pass**,89 scripts match clean Studio candidate; two-client Studio surface/jump/idle/respawn/queue/return checks completed. LSP/Selene dependencies remain blocked; full formatting has pre-existing differences. Live-device listening remains owner acceptance. [Release report](../development-copy/audio-batch07-20261024/AUDIO_RELEASE_REPORT.md) contains IDs, implementation, exact limitations, backups and rollbackv22. Older privatev9/blank-audio notes below are historical. Batch08 variations await owner review and must not be described as implemented.

---
## Private development shotgun build — 2026-10-22

The original Blender shotgun is now imported **only in the separate private development experience**, universe10772492892 / place139437092998076, publishedv9. Both FP slots and TP use the recovered rig and all ten original baked animation clips. All16 skins are unlocked through exact-development-ID guarded overrides. Public production is not updated. See [development release report](../development-copy/DEVELOPMENT_RELEASE_REPORT.md) for source snapshot, imported assets, backups,306 passing tests, Studio evidence, owner Player confirmation and remaining limits. Earlier local-preparation notes below describe the prior checkpoint and are superseded for development deployment.

---
## Asset integration checkpoint — 2026-10-22

Local original-shotgun preparation is complete; **upload approval → local import/templates → fresh lint/type checks and Studio/multiplayer/device acceptance → separate publication approval** remains the required sequence. Keep existing public build unchanged until acceptance. This is the original model integration, not approval of the earlier cosmetic redesign concepts. See [integration report](BLENDER_SHOTGUN_INTEGRATION.md).

---

# Double Pump — development roadmap

Updated 2026-10-22. Current facts: PROJECT_STATUS.md and RELEASE_RECORD.md. Proposals below are not implementation or authorization. No new gameplay feature is part of this release transition.

## Confirmed stabilization priorities

- Fresh private desktop/phone two-player acceptance: lobby damage, queue cancellation/admission, all maps, respawn/return and settings/progression rejoin.
- Measure ten-player latency/hit acceptance, sustained FPS/memory and queue boundaries; record actual devices and environments.
- Owner content declaration/target audience decision and account-specific eligibility review. Keep private until separate final Public approval.
- Review blank cosmetic audio/map-card IDs and sound permission warnings. Blender mesh import remains a separate approved asset task.
- Keep source/Studio/cloud identity, documentation and rollback records current.

## Proposed next evaluations — scoped approval required

| Category | Evaluation | Evidence needed |
|---|---|---|
| Gameplay balancing | Compare alternate-gun and single-gun cadence before tuning | Accepted shot times, rejection rates, player feedback |
| UI polish | Queue discoverability, results readability, safe areas | Desktop/mobile screenshots and confusion reports |
| Map improvements | Spawn/sightline/cover fairness across existing arenas | Real5v5 rounds and spawn-death data; no automatic redesign |
| Mobile optimization | Sustained multitouch/drag/swipe and preferences | Physical phones/tablets; emulator is not hardware |
| Retention | Evaluate existing challenges/mastery and repeat sessions | Cohort and player feedback before adding reward loops |
| Monetization | Cosmetic-only product readiness and receipt/save safety | Separate owner approval/IDs/fulfillment tests; sales remain off |
| Analytics | Define minimal match/queue/funnel/performance events | Privacy-conscious contract and verified delivery |
| Acquisition | Preserve polished art; evaluate thumbnail performance | Actual impressions/qualified plays; no CTR guarantees |
| Additional content | Consider maps/cosmetics/events from demand | Maintenance cost and player demand; ranked/new weapons speculative |

Preserve the two-identical-shotgun identity, balance, server authority and desktop/mobile responsiveness. Record supported decisions and dates; append superseding rationale instead of rewriting history. Earlier roadmap retained in history/release-transition-20261022/ROADMAP.md.
