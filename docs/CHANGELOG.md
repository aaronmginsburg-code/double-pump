## Private release preparation — 2026-10-21

Verified Studio checkpoint: `137a9ebe68341432ea256de1cb7281b0da613a47`.
Current branch: `release/private-playtest`. Original prototype and verified backup
remain untouched. A separate recoverable source/history/place backup is at
`../verified-before-private-release-2026-10-21/`.

- Corrected the real respawn pellet-seed mismatch: WeaponState.reset now resets the
  server shotCounter, matching the client's fresh weapon state. Studio measured
  client 1/server 1 on the first post-respawn shot, in solo and local multiplayer.
- CharacterService replicates the final SpawnCFrame after preparation. GameFlow
  waits for that readiness marker and aligns the camera once per character. Both
  team camera direction dots measured 1.0, including after respawn and transitions
  between match and practice. Closing menus preserves the player's existing aim.
- 124 tests pass (all original 123 plus one counter regression); type analysis,
  source Selene, StyLua and Rojo build pass. No weapon timing, damage, movement,
  map or monetization changes. Parts-based guns/embedded animations remain usable;
  unuploaded audio and map thumbnails remain cosmetic limitations.
- Publication and normal Roblox Player verification are in progress; the final
  PRIVATE_RELEASE_REPORT.md will record confirmed IDs, access and live results.
# Changelog

## Unreleased — Studio gameplay blockers (2026-10-21)

Base: PR #2 `14848886bfec43bd5277564ffce89c938f46f629`.
Local branch: `fix/studio-gameplay-blockers`. Uncommitted; no merge or push.

- Restore existing firing, switching and reload eligibility by assigning
  `WeaponController.active` from GameFlow's existing combat-input state. Menus,
  death, postgame and practice use the same lifecycle as camera/input controls.
  File: `src/client/Controllers/GameFlow.luau`.
- Place and initialize characters after `LoadCharacterAsync` completes, rather than
  in the earlier `CharacterAdded` callback where engine spawn placement overwrote
  the chosen team CFrame. Verify humanoid/root/current character before preparing;
  emit Spawned after placement and retain the existing three-stud lift/protection.
  File: `src/server/Services/CharacterService.luau`.
- Remove the protected runtime Workspace destroy-height assignment which prevented
  range construction; serialize the identical -120 value in the place build.
  Files: `src/server/Services/MapService.luau`, `default.project.json`.
- Add three regression tests in `tests/studio_blockers.spec.luau`. Original 120
  tests and all three regressions pass. Direct type analysis, Rojo build, source
  lint and StyLua pass. Extended lint retains one pre-existing test warning.
- Update AI_HANDOFF, PROJECT_STATUS, TESTING and STUDIO_PLAYTEST_REPORT.

Corrected build: `build/DoublePump_STUDIO_BLOCKER_FIXES.rbxl`. Once the owner cleared
the window limit, Studio tests confirmed range startup/targets, mouse fire/Q swap/R
reload, target damage, two-player team initial/respawn placement and staged PvP
damage/elimination. A controlled probe measured accepted alternating intervals of
0.550/0.783/0.484 s and a 1.116 s single-gun control; the server rejected a premature
request, and reload interruption preserved inserted shells. Human latency/device
validation remains incomplete. The original report/screenshots remain pre-fix evidence.
All three arenas loaded through normal round flow; initial team coordinates matched
their markers. Warehouse/Rooftops respawns were measured. Spawn-facing camera views
need follow-up; no extra orientation/map fix was introduced during verification.

Weapon configuration, double-pump state rules, damage, movement, recoil, animation,
team rules, maps and assets are unchanged. Original prototype and all 52 backup
files remain intact. The separate post-respawn shot-counter issue is now reproduced
in Studio (predicted 1 vs server 7) and remains unfixed for a separately scoped review.

