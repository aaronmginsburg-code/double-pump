# Current training-bot checkpoint

Read [training-bot update](../docs/TRAINING_BOTS_UPDATE.md) for the current123-script private source, branch, deployment and rollback record. Previous aim-assist and audio history follows.

## Development aim assist checkpoint — 2026-10-24

**Private developmentv39 published and verified**, implementation commit `665d307` on `feat/development-aim-assist`: development-only aim assist and the authorized F6 tuning console. Production remains publishedv10. The owner subsequently confirmed Save→rejoin→Load persistence in the published development build. This is owner-reported verification; Studio DataStore access remained disabled. Real phone/controller aiming and multitouch feel remain pending. The newer private cloudv29 source was reconciled: local private source now includes the feedback modules and GameFlow, with118 permanent scripts in the aim-assist candidate. Earlier warnings below about the89-script private tree are historical. Preserve full-scene cloud geometry; do not deploy the stand-alone Rojo source build over it.

Read [aim-assist test/release report](../docs/AIM_ASSIST_TEST_REPORT.md) for actual publication status, source checkpoints,398 passing tests, Studio observations, screenshots and remaining hardware/cloud-persistence verification. Architecture and parameters are in AIM_ASSIST_IMPLEMENTATION.md and AIM_ASSIST_CONFIGURATION.md. This does not update the public game or promote any tuning configuration.

---

## Private quieter-footstep release — 2026-10-24

Approved .65 -> .13 footstep gains are now **published privately asv29**, based on newer cloudv26 and preserving its feedback system (111scripts).377 existing local tests passed; fresh Studio verified four gains and actual movement/rolloff. Public game unchanged. **Local development-copy/source lacks the newer cloud feedback additions**; use the archivedv29 cloud place/source snapshot as deployment authority until reconciled. Do not overwrite it with the older89-script Rojo build. See [publication report](../audio-production/footstep-level-review-20261024/publication/PRIVATE_RELEASE_REPORT.md) for exact delta, backups, test boundaries and known pre-existing Landing suppression.

---
# Private development copy

Play: https://www.roblox.com/games/139437092998076/

Latest private update: **version24, approved Batch07 surface footsteps and landing (2026-10-24)**.
Read [batch-seven audio release report](audio-batch07-20261024/AUDIO_RELEASE_REPORT.md) for five new IDs,
377 passing tests, final two-client Studio validation, clean89-script archive and stablev22 rollback.
The [batch-six report](audio-batch06-20261024/AUDIO_RELEASE_REPORT.md) documents retained unlock/assist/ambience cues.
The [batch-five report](audio-batch05-20261024/AUDIO_RELEASE_REPORT.md) documents retained handling/impact/match/UI cues.
The [batch-four report](audio-batch04-20261023/AUDIO_RELEASE_REPORT.md) documents retained lobby/progression cues.
The [batch-three audio release report](audio-batch03-20261023/AUDIO_RELEASE_REPORT.md) documents retained match/UI cues.
The [batch-two audio report](audio-batch02-20261023/AUDIO_RELEASE_REPORT.md) documents retained handling/elimination/respawn cues.
The [first audio report](audio-update-20261023/AUDIO_RELEASE_REPORT.md) documents the retained pilot cues.
The Blender/custom-animation/all-skin version 9 report below remains historical context.

Read [DEVELOPMENT_RELEASE_REPORT.md](DEVELOPMENT_RELEASE_REPORT.md) for deployment, all ten custom animations, all-skin access, test evidence, limitations and rollback.

- Edit/build only `source/default.project.json` for this development experience.
- `source/assets/Weapons/`: actual imported FP/TP templates with mesh/texture IDs.
- `overrides/`: development-only all-skin scripts, guarded to universe10772492892/place139437092998076.
- `backup/DoublePump_DEVELOPMENT_PUBLISHED_V9.rbxl`: final Studio copy.
- `backup/DEVELOPMENT_SOURCE_CHECKPOINT.zip`: recoverable source snapshot.
- `assets/`: embedded-texture FBX import bundles.
- `evidence/`: screenshots, tests, source comparisons, asset inventory and hashes.

The normal repository project continues to describe production. Do not sync these overrides to production, and never publish a diagnostic normalized file.
