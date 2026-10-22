# Double Pump — release record

## Identity

- Experience **Double Pump [Private Test]**, owner supersnapstudios.
- [Play](https://www.roblox.com/games/82505574993280/Double-Pump).
- Universe **10772275012**; start place **82505574993280**; capacity **10**; genre **Shooter**, subgenre None (Dashboard genre changes restricted until2026-11-19).
- Implementation commit **4505edef94f69a251d07a6b5c014c671fcbde675**, branch **feat/mobile-controls**, pushed to aaronmginsburg-code/double-pump. Later documentation/evidence commits may follow without changing this source tree.
- **Version 10 published 2026-10-22 at 00:54:06 PDT** (Studio 07:54:06Z). Its Dashboard “Last Updated” row remains 2026-10-21 at 22:51 PDT: that is the earlier saved-version timestamp, not publication time. Initially unpublished version 10 now has the Published Version checkmark. Prior versions 9/8 remain recoverable.
- After publication Dashboard confirms **Only available to you and your collaborators.** No Public/friends change, duplicate experience, monetization activation or asset upload.

## Source reconciliation and rollback

Current source: C:/Users/aaron/Documents/double-pump-backups/2026-10-21-prototype-uncommitted/complete-game-studio. Original C:/Users/aaron/Documents/double-pump remains dirty older prototypeHEAD 6c77104, untouched. PR #2 / 14848886 is an ancestor; main is scaffold. Mobile/lobby changes were dirty at start and are now checkpointed. No gameplay code was changed in this release transition.

Before-work backup: ../release-transition-20261022/before-release-source-docs-build.zip, file hash manifest, binary Git patch/status and before-release-history.bundle. Studio-before-release.rbxl preserves the open editor;81 script paths/classes/text match the fresh production build after CRLF normalization, with no probe scripts. Lune warns about an unknown new Terrain property type; script parity is not proof every unrelated serialized property decoded.

Production build/DoublePump_RELEASE_20261022.rbxl SHA256 **99ACCD4C34C956D5201D2FA963F055E4DB6DC1D525AB0478FE0E192FF56AD770**, identical to the verified lobby candidate. Instrumented DO_NOT_PUBLISH copy is separate. Historicalv8 source/binary backups also remain. Rollback: select the known previous version in Creator Dashboard; Restore saves it, then open/publish in Studio with authorization. Do not reset current Git or overwrite the prototype.

## Fresh tests — 2026-10-22

| Check/environment | Actual result and boundary |
|---|---|
| Lune |245 passed,0 failed|
| luau-lsp |No type/syntax errors; CLI watch-registration warning only|
| Selene |0 errors,0 warnings,0 parse errors after network API-definition fetch|
| StyLua |Passed Windows-line-ending check over src/tests/tools|
| Rojo/parity |Build passed;81 scripts match saved Studio snapshot|
| Studio solo |Armed range100 HP/targets; fireA/Qswap/fireB/Rreload observed|
| Three-client Studio |**21/21 assertions,0 failures**: population waits, accurate nonlethal feedback/noXP, queue start/cancel/selected admission, match PvP/score/respawn, all three maps, three healthy returns/no requeue|
| Normal Roblox Player |Browser Play reached loading prompt, no Player window appeared; **not agent-verified**. Owner previously reports satisfied gameplay, not exhaustive version 10 acceptance.|
| Physical phone/controller |Earlier iPhone17ProMax owner feedback retained; no fresh agent hardware test|

Fresh body blast:10 pellets, server aggregate81.90, client rounded82, target100 HP. Head blast:10 pellets157.5, client158 critical, target100 HP. Body collisions can include limb pellets; this checks actual aggregation, not a fabricated torso-only90. Prior focused90torso result remains separately recorded. Existing1.0/0.4/0.15 timing unchanged. Earlier0.484–0.783double-pump versus1.116single cadence is historical Studio evidence, not a fresh latency benchmark.

Staging anchors players and expedites only round clocks in the test copy; ordinary combat remotes/server checks/lifecycle run unchanged. Prior dated reports cover late joins/disconnects, mobile gestures and four preference combinations; these are not all claimed freshly rerun. Test profiles are session-only because Studio API access remains off. Live saves/rejoin, ten-player load, physical multitouch/controller performance and real purchases remain unverified.

Evidence: release-evidence-20261022/automated-tests.log, studio-results.json, studio-three-client.log, source-comparison.log, publication.log, screenshots. Earlier failed probes remain in historical reports, not relabeled passes.

## Metadata and asset readiness

Name/description confirmed in Creator Dashboard. Description: “Master the double pump in a fast-paced, first-person shotgun arena shooter. Switch between two pump shotguns, land precise shots, and battle across three maps in team-based combat. Private development test.” Existing crossed-shotgun icon and five Experience Detail thumbnails are present and preserved. Home Page performance table has no active thumbnail rows; no CTR claim. No gameplay video uploaded. Final art and editable material remain in marketing/, now committed.

Parts-based guns and baked animations exist in source/build and permit current play without uploaded meshes. Blender masters/FBX exist on asset branch fdeae96367f73ca408ad190e134cdebd235defaf; not claimed imported.29 sound IDs,3 map-card IDs and Logo remain blank; fallback/silence/plain cards persist. Existing audio permission/fallback, CoreGui and platform heartbeat warnings are retained in logs. No new game-service startup blocker observed. Full external-asset ownership/moderation acceptance remains unverified; empty IDs are not approved uploads.

## Public readiness — observed status and owner actions

Dashboard: identity verification **Complete**,2FA **Complete**, content rating **Incomplete**; game page maturity **Unknown**. Broader Kids/Select cards show250 highly engaged players incomplete (0 as of Oct 21 21:00PDT) and1,000 Robux fee incomplete. No money action taken. Account standing, daily release quota and all region/age eligibility are not independently established.

[Roblox current publishing documentation](https://create.roblox.com/docs/production/publishing/publish-games-and-places), accessed2026-10-22, separates initial 16+/Trusted Friends release prerequisites from broader Kids/Select reach. Initial release needs account age/standing, age check and an age-restricted-content declaration. Wider reach has additional verification/2FA, subscription-or-fee, evaluation and full-rating requirements. Dashboard and documentation expose different paths: do not assume the250player card prevents initial 16+ release or that verified ID establishes all-ages eligibility.

Owner: select intended audience, truthfully review content questions in Publish settings→Content rating (or initial release flow), recheck account-specific gates/moderation and metadata, and separately approve the final Public step. No content declaration was answered for you, no fee paid and no Public action performed. Live-client acceptance and cosmetic asset quality remain release-stabilization work.

## Future updates

Follow DEVELOPMENT_WORKFLOW.md: verify actual source/Git/cloud identity, preserve binaries/history, run checks plus scoped Studio/device acceptance, commit/push reviewed authorized files, publish production to existingIDs, verify cloud/version/access and fresh servers, update dated release evidence. Never publish probes/capture copies. Refresh ChatGPT reference uploads manually; update Obsidian via reviewed lock/import workflow. Do not infer Public or commerce approval.

## Independent cloud parity follow-up

Reopened Double Pump through Studio owned Experiences after publication, downloaded Cloud-version10.rbxl into the separate release-transition backup, and compared it to the production build. All 81 script paths/classes/source texts match after line-ending normalization; no extra test scripts. See release-evidence-20261022/cloud-source-comparison.log. This is cloud source verification, not a normal Player test.

The independently retrieved cloud place also passed an actual Studio solo startup smoke test after publication: armed range, targets and100 HP with queue instruction HUD. Screenshot: release-evidence-20261022/retrieved-cloud-smoke.jpg. The local test was stopped afterward.
