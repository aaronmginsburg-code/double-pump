# Aim-assist audit — 2026-10-24

Scope: private Double Pump development only, universe **10772492892**, place **139437092998076**. Production universe10772275012/place82505574993280 is explicitly excluded. Repository feat/mobile-controls at b90e77a; existing dirty work preserved. Read the eventual test report for fresh cloud/version evidence.

## Source authority and preservation

Latest archived private publication is v29: audio-production/footstep-level-review-20261024/publication/DoublePump_PRIVATE_V29.rbxl and cloud-source-after.json. It contains111 scripts, versus89 in development-copy/source. The22 added feedback scripts and modified GameFlow must be preserved. This task first reconciles those exact cloud sources, retains intact Studio place geometry/assets, and patches only reviewed source deltas. Local source backup and public-source hashes are in development-copy/aim-assist-20261024/backup. Root src/ is the production project and must not change.

## Camera and input

Client.Controllers.CameraController owns Scriptable camera yaw/pitch, render priority Camera+1. Mouse uses GetMouseDelta × .0035 radians/pixel × sensitivity; touch uses an owned DragAim finger's displacement × .006 × touchSensitivity; controller Thumbstick2 uses .15 deadzone,1.7 response curve,4.2rad/sec × gamepadSensitivity. Pitch clamp80degrees; recoil is added separately. No pre-existing aim assist. Default Roblox camera is not the active first-person controller. Touch has no look joystick; MobileControls/TouchState separate drag aiming from movement, buttons and swipe region. Independent weapon hand/layout remain untouched.

InputController maps LMB/R2/fire, Q/R1/L1/swap, R/X/reload. Manual fire remains deliberate. Mobile FireSequence permits one held-fire follow-up per valid fresh downward swipe; no new firing automation is needed. Camera.requestCursor protects menus; GameFlow selects Combat/Dead/Scenic and resets orientation using SpawnRevision. Feedback board also owns cursor requests in newer GameFlow.

## Combat and reticle

WeaponController reads CurrentCamera origin/LookVector, predicts WeaponState, raycasts10 deterministic pellets and submits claims. CombatService reruns state validation, spread, range/origin/team checks, obstruction and lag-compensated hit validation. DamageService applies shared Damage calculations and context rules. No physical projectile system. Shared Combatants identifies tagged living characters/dummies; CombatContext is server authority separating lobby practice from match opponents. HUD reticle is centered with weapon feedback; assistance must move camera, never silently bend pellets or damage.

Timing: same gun1s, global interval.4s, swap.15s,equip.35s,input buffer.1s. Five shells/gun; reload start.3s,shell.5s,end.3s.10pellets×9base; Head1.75,Torso1,Arm.9,Leg.8; full damage to9studs,25%at45,max150. None are tuning-panel controls.

## Integration recommendation (before gameplay edits)

1. Separate pure configuration, eligibility/stability/response math, runtime target adapter, server tuning/profile service and developer UI. Require exact private IDs on both sides; authorize11808586604 from existing server FeedbackBackend.IntegrationConfig ModeratorIds. No negative Studio-user bypass in shipped code.
2. Camera hook scales only manual touch/stick deltas and adds bounded gentle yaw/pitch while current-frame aim input exists. Mouse path remains identical; no shot remote changes. Reset target/filter on spawn/transfer/menu/focus loss/config changes.
3. Cache tagged combatants; acquisition at10Hz, cheap projection/context and current-target visibility recheck before each assisted frame. Solid occluders always block, even if the optional stricter queryable-prop LOS setting is disabled. Torso targeting avoids automatic headshot bias. Stable score hysteresis; no sticky dead/offscreen targets.
4. Per-server active configuration broadcast from validated privileged requests. Explicit Save/Load for named developer-owned slots; schema/revisions and UpdateAsync conflict checks; no automatic save/load or player-profile schema changes. DataStore failure retains session state. Export JSON for future reviewed promotion; no production promotion capability.
5. Panel opening acquires cursor, blocks combat/mobile pending-fire input and resets look; closing releases ownership. Hidden panel must not intercept inputs. Bounded diagnostics omit wall-hidden targets.

## Baseline limitations

377 local tests pass before modifications. Existing missing Luau-LSP definitions and Selene API-library fetch blocker require fresh attempts, not assumed passes. Studio API access has historically been denied; persistence needs durable-service/live verification. Physical touch/controller feel cannot be certified by simulated input. Existing Landing audio name-suppression bug is unrelated and left untouched. New feedback code is preserved, not redesigned.

Official API references: [Data stores](https://create.roblox.com/docs/cloud-services/data-stores), [UpdateAsync](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore), [Camera projection](https://create.roblox.com/docs/reference/engine/classes/Camera), [raycast parameters](https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams).
