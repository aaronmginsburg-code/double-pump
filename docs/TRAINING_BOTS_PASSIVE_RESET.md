# Range duel reset after player death

October 24, 2026. Private development correction on `feat/development-training-bots`.

The range duel flag previously survived the owner's character death. Once spawn protection expired, the same bots could reacquire the respawned player. `TrainingBotService` now listens to the existing server `CharacterService.Died` signal and ends the duel only when the authorized owner dies in Practice mode. It clears the shared hostility flag, cancels both bots' paths and pending combat decisions, forgets their target/pursuit memory and makes living bots stationary and passive. Dead bots retain the normal respawn lifecycle. No teleport, health/ammo refill, weapon timing, damage, profile or input change is introduced.

Match-mode deaths are explicitly excluded: enemies continue fighting through ordinary match respawns. A fresh validated owner hit in the range still provokes both bots. The public source and deployment remain excluded.

Changed production-runtime modules, private copy only:

- `src/server/Services/TrainingBotService.luau`: range-owner death signal handler and navigation/state reset.
- `src/shared/Training/Policy.luau`: reusable reset of transient AI combat decisions, preserving identity and weapon inventory.
- `tests/training_bots.spec.luau`: two regressions for transient reset and blocked retaliation after respawn until fresh provocation.

## Validation

- Baseline424 tests passed; final **426 passed, 0 failed**.
- Private Luau compile, changed-file StyLua and source-only Rojo build passed.
- Selene is blocked obtaining its Roblox API standard library; Luau LSP is blocked by missing `C:/Users/aaron/tools/globalTypes.d.luau`. Neither is reported as passing.
- Actual Studio acceptance used genuine client WeaponController calls, server shot validation, bot damage and normal character death/respawn. After three bot shots the owner died. Both bots cleared target/path/pending-swap state and became passive. Following normal respawn, eight seconds produced no additional bot shots and the owner remained100HP. A fresh legitimate owner hit restarted combat and a fourth bot shot was accepted. `PASSIVE_RESET_COMPLETE Practice` was logged.
- The temporary probe only staged the owner's position and camera/input; it did not fake damage, bypass weapon validation, award progress or change profile data. All probes were removed from the candidate.
- All123 permanent sources matched the pre-changev48 editor before patching. The clean candidate's123-source digest is2499729693. Detailed logs/manifests are in `development-copy/training-bots-passive-reset-20261024/evidence/`.
- This targeted correction did not repeat all three arenas or physical-device testing. The match-mode exclusion is source-verified; the prior bot release's full lifecycle coverage remains historical evidence, not a new test run.

## Backup and deployment

Previous intact developmentv48: `development-copy/training-bots-passive-reset-20261024/backup/DoublePump_DEVELOPMENT_V48.rbxl`. Original two module sources are beside it. New intact candidate: `DoublePump_PASSIVE_RESET.rbxl` in the same folder. Source-only Rojo and normalized INSPECTION_ONLY files must not be published.

Authorized destination remains universe10772492892/place139437092998076, https://www.roblox.com/games/139437092998076/. Production universe10772275012/place82505574993280 is excluded. Verified publication details are appended after deployment. Restore/publish the intactv48 backup only to the verified private destination to roll back this correction.
