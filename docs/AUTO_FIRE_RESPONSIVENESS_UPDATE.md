# Responsive auto fire and optional weapon swapping — 2026-10-26



Private development only: universe10772492892/place139437092998076. Production10772275012/place82505574993280 excluded. Owner requested stronger mobile automatic firing and explicitly authorized publication, plus a separate automatic-swap setting. No weapon balance changes.



## Causes and corrections



Previous defaults required250ms uninterrupted acquisition in a3.5%-of-short-screen torso-center circle, with100ms discovery plus50ms polling. Aiming at heads could lose torso-only eligibility. An empty gun could not pass the readiness gate to reach the existing auto-reload path, leaving the trigger stalled.



New touch defaults: enabled, zero activation delay/persistence,10%-short-screen radius,150-stud maximum capped by actual weapon range. Full discovery at30Hz; selected target/visibility and legal readiness checked each heartbeat. Head and torso use one stable model identity. This removes configured dwell, not network/frame latency. Still requires a visible eligible target inside the circle; shots remain aimed at the real crosshair, without camera snapping, silent aim or guaranteed hits.



Auto Swap Weapons is a separate saved boolean, defaultOFF. When enabled and a visible eligible target exists, it uses ordinary Equip only if the other loaded gun can fire earlier. Current reloads and in-progress raises are not canceled. No empty-to-empty switching or oscillation. Existing .4 global interval,1.0 same-gun cooldown,.15 swap,ammo,server validation and damage remain unchanged. Empty equipped guns enter the ordinary auto-reload path. No automatic reload interruption.



Old schema2 presets missing only autoSwap load withfalse. Their saved activation values are preserved; Reset Auto Fire explicitly adopts the new defaults. No player-profile/schema/store namespace changes or automatic saved-preset writes. Mouse/controller remain ineligible by default; automatic swaps/reloads share the same input/combat/UI eligibility gate as automatic firing.



## Validation



471 automated tests pass (463 baseline plus8 cases), including immediate first trigger, fast target changes with global interval, old-preset compatibility, optional swaps, no reload cancellation/empty oscillation and sustained legal alternating cadence. All private sources compile; Rojo verification build passes; changed-file StyLua passes. Selene cannot fetch the Roblox API standard library; Luau LSP definitions are missing from the configured tools/globalTypes.d.luau path. These are blocked, not clean passes.



Actual Studio solo run: stationary dummy first shot37.46ms, training NPC first shot36.87ms, alternating A/B interval415.20ms. Server accepted both shots and hit feedback arrived. Added solid wall prevented activation; console-open fence stopped firing. After a normal death/respawn ended retaliation, five ordinary shots depleted Pump A; auto fire entered normal reload and resumed firing with four shells remaining. Final full scan max0.3653ms in this desktop run. These are scripted camera-alignment/mouse-override tests against actual game targets and combat validation, not physical phone measurements. Initial test fixture failures (retaliation resetting ammo; duplicated probes hitting request rate limit) were corrected by isolating/cleaning the fixtures and rerunning; the final single-probe run completed. Studio API access remains disabled; cloud preset persistence is not newly verified.

Clean deployment scene verified all131 sources, digest31 644707714, exact development IDs, no temporary probes or runtime-only authorization grants. Baseline cloud saved version64 has the same sources as published63; extra test saves are drafts, not publication. Intact baseline scene downloaded as DoublePump_CLOUD_BEFORE.rbxl. Publication and physical mobile acceptance remain pending. No unrelated project source/window was modified or closed; no production publication performed.



## Source, backup and rollback



Base HEADcc9ee48 onfeat/development-training-bots. Stable v63 intact place and CRC-checkable BEFORE_AUTO_FIRE.zip are in development-copy/auto-fire-20261026. Candidate patch, full131-source manifest and verification command are beside them. Source-only Rojo output must never be published as the full scene.



Changed source: DeveloperConsole/Registry,Config,AutoFire; Controllers/DeveloperConsoleController; UI/DeveloperPanel; tests/developer_console.spec.luau. Queue,bots,damage,weapon rules,models and public src are untouched.



After Studio validation, patch only the intact verified development full-scene place, remove all temporary tests/grants, compare every131 source, archive, then publish only the exact development IDs. Verify actual cloud version and source; never infer success from local builds. Roll back via preservedv63 to that same development destination if authorized. No push or production promotion.
