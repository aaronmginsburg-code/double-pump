> 2026-10-25: **private development v63 published and cloud-source verified**, implementation `80a1dca` on `feat/development-training-bots`. Five-category console plus approved bottom mobile DEV launcher.463tests pass. Public publishedv10 unchanged. New-schema cloud persistence and physical-device acceptance remain pending. See [publication report](DEVELOPER_CONSOLE_PUBLISH_REPORT.md).

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
## Weapon presentation candidate — 2026-10-22

Production still uses the documented parts-based shotgun. An uncommitted local loader adaptation and original Blender FP/TP exports are prepared, awaiting separately approved Roblox upload/import and runtime verification. Current skin IDs/palettes, independent Weapon Hand preference, combat rules and all timings are preserved. No redesign or gameplay-rule change. See [integration report](BLENDER_SHOTGUN_INTEGRATION.md).

---

# Double Pump — current game design

Inspected 2026-10-22 at implementation 4505edef. Implemented rules are listed below; future opportunities are proposals. Source configuration overrides stale prose.

## Concept and player experience

First-person Roblox arena TDM, up to 5v5, focused exclusively on two identical pump shotguns. Alternating independent guns creates a learnable firing rhythm. Precision, movement, spacing and manual switching are the competitive core; cosmetics must not buy power.

## Weapon and damage configuration

Sources: src/shared/Config/WeaponConfig.luau, Weapons/WeaponState.luau and Weapons/Damage.luau.

| Setting | Current value |
|---|---|
| Same-gun cooldown / any-shot minimum |1.0s /0.4s|
| Swap / equip |0.15s /0.35s|
| Input buffer / server tolerance |0.1s /0.08s|
| Magazine / reserve |5 per gun / unlimited|
| Reload start / shell insert / visual end |0.3s /0.5s /0.3s|
| Pellets / base pellet damage |10 /9|
| Head / torso / arm / leg |1.75x /1x /0.9x /0.8x|
| Falloff start / end / minimum |9studs /45studs /0.25|
| Maximum ray range |150studs|
| Inner/outer spread radii / roll per shot |1.6deg /3.6deg /17deg|
| Crouch / airborne spread |0.9x /1.15x|
| Double-pump kill attribution window |1.2s alternating-gun hits|

Pattern: center+3inner+6outer pellets. Each slot has separate ammo/cooldown/reload; firing/swapping interrupts loading while keeping inserted shells. Auto-reload on empty is enabled. Server validates state, rate, origin, pellet claims, world obstruction and lag-compensated hitboxes (max rewind0.4s, history20Hz). No uncontrolled held auto-fire; mobile adds one legal follow-up per deliberate swipe.

## Combat contexts

Active opponents in the same server-owned match take real damage and yield scoring/progression. Friendly fire and cross-context hits are blocked. Lobby players receive the same calculated aggregated damage/critical feedback but no health, elimination or progression application. Hypothetical overkill can exceed100. Dummies remain damageable and respawn normally without match farming.

## Lobby and voluntary admission

Permanent armed range with ten targets, no time limit. Cyan MATCH QUEUE checks living prepared root-center bounds, excluding accessories and button/remote admission. Min2/max 10/FIFO/15s countdown,0.1s samples; offset(-52,7,37), size(18,14,10) relative to range origin. Leaving below2 cancels and resets countdown. Final membership is validated on server. Overflow keeps order. Only one roster/arena can be reserved/active. Waiting players may queue for the next match but never auto-join a running match.

Selected roster votes12s, receives balanced teams, then enters existing5s arena preparation. After9s results, return outside queue with full health/ammo and cleared match state; no automatic requeue.

## Match and movement configuration

Source: src/shared/Config/GameConfig.luau.

-10 players, max 5/team, Red/Blue. Rebalance on death at team-size gap2.
-300s regulation,40 elimination target; scaled by roster/10, minimum15, rounded up to5. Tied regulation:60s sudden-death overtime, first elimination wins; otherwise draw.
-100 HP, respawn2.5s, protection2s ended early by firing. Assist window8s/minimum25damage. Spawn scoring avoids nearby/visible enemies, radius30studs.
- Walk20/crouch11studs/s, jumpheight7.6, gravity196.2, aircontrol0.55. Sprint disabled. Crouch hip/camera drops1.25/1.6studs.
- Vertical FOV78 default,60–95 selectable; sensitivity1 default,0.1–4 range; pitch80deg. Mouse0.0035rad/pixel, touch drag0.006rad/pixel, gamepad4.2rad/s full stick, sensitivity-scaled.

## Maps and presentation

Warehouse: industrial lanes/racks/catwalks. Dust Town: warm adobe streets/roofs/courtyard. Rooftops: bridges/vertical cover/AC/neon. Existing builders and voting remain; no map redesign in release work. Separate PracticeRange/QueueZone coexist with one active arena.

HUD has health, center crosshair, PumpA/B ammo/readiness, hit/damage/critical markers, killfeed, score/timer, queue status, results/vote, menu/settings/profile/challenges/shop.

## Controls and preferences

Desktop: WASD/mouse/Space/LMB/Q/1/2/R/C orLeftCtrl/Tab/M. Gamepad: R2fire,R1/L1swap,Xreload,Bcrouch,DPadgun,Selectscore,Startmenu.

Mobile: movement stick, free touch-and-drag aiming; FIRE hold gives initial shot only; a fresh downward SWAP gesture queues one valid switched-gun follow-up while held. Release cancels pending fire. Gesture max0.30s/min72logicalpixels/vertical dominance1.8/upward allowance16, resolution-scaled. Touch ownership excludes movement/buttons and separates aim from marked swap area. No LOOK joystick or invisible look capture region remains; LegacyV2Constraint is saved-layout compatibility only.

Control Layout mirrors touch controls/zones. Weapon Hand independently presents both first-person guns on right/left on touch or desktop. Four combinations supported, crosshair/trajectories unchanged. Profile v3 saves both, migrates old coupled choices; DataStore DoublePump_Profiles_v1 unchanged.

## Progression, cosmetics and monetization

Implemented levels cap 100, XP-to-next=min(400+100*(level-1),2000), mastery, earned coins/skin ownership/equipping, daily/weekly challenges, statistics and leaderboards. Kill50XP/5coins, assist20XP, headshotbonus10XP, doublepumpbonus25XP; completion100XP/25coins and win150XP/50coins activity/presence-scaled, completion/win minimum active fraction0.35. Lobby PvP/dummy hits do not farm match progression.

Three paid coin packs are defined but disabled, productIDs nil. No real purchase acceptance claimed. Current weapons use parts-based models/embedded baked animations; Blender masters/FBX remain separate asset pipeline.29 audio and3 map-card IDs are blank, with fallback/silence/plain-card behavior. Existing published icon/five thumbnails retained.

## Balancing and future opportunities

No timing/damage/movement changes authorized in release transition. Measure server-accepted cadence, rejection rates, network and device performance before tuning. Cosmetic mesh/audio integration, retention evaluation, analytics, readability/accessibility and new content require bounded approval and evidence. New weapons/ranked modes/additional maps are proposals, not implemented promises. See ROADMAP.md.

## Development training duel reset — October 24, 2026

In private developmentv50, owner death in the firing range ends the bot duel. Both bots stop pursuing/firing and remain passive after respawn until the owner shoots one again. Ordinary match deaths do not end bot combat. See TRAINING_BOTS_PASSIVE_RESET.md.
