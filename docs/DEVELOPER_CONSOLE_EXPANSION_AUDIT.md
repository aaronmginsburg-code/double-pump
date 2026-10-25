# Developer console expansion audit — 2026-10-25

Inspected before implementation. Branch `feat/development-training-bots`, HEAD `8f0f59759538f0fef91cda449a3d98c9b01df40c`. Canonical development source is `development-copy/source`. Published development checkpoint is v50; production is a separate deployment. Existing unrelated dirty files and untracked audio/marketing assets are preserved.

## Identity and recovery

Development universe **10772492892**, place **139437092998076**. Production universe **10772275012**, place **82505574993280** is excluded. `DeveloperAccess` checks both development IDs and explicit UserId **11808586604**; no Studio/creator shortcut. Backup: `development-copy/developer-console-20261025/backup/BEFORE_DEVELOPER_CONSOLE.zip`, intact full-scene `DoublePump_STABLE_v50.rbxl`, Git status and HEAD. Source-only Rojo output does not preserve every cloud scene asset.

## Existing architecture

- `DeveloperTuningService`: development-only RemoteFunction, revision-checked live Apply/Reset, server authorization, rate limiting, busy guard. Explicit Load-before-Save and compare-and-swap persistence prevent silent overwrites. Old store `DoublePump_DevTuning_v1`, scope `u10772492892`, schema1 aim-only profiles; owner confirmed cloud persistence previously.
- `AimAssist/Config`, `Policy`, `ProfileStore`: centralized validated settings, pure camera response and stable selection, injectable persistence adapter. Controller scans tagged combatants at10Hz, revalidates current target, blocks walls/dead/frozen/cross-context targets, allows touch/controller only. Camera hook changes sensitivity and orientation, never damage.
- `DeveloperPanel`: code-built safe-area GUI, draggable window, scroll sections, F6 launcher, sliders/toggles, diagnostics, explicit save confirmation, selectable JSON. Opening acquires cursor and blocks game input through `InputController.tuningOpen`; retain these contracts.
- `MovementController` and `CharacterService`: native Humanoid walking/crouching/jumping and custom airborne direction blending. Walk20, crouch11 studs/s, jump7.6 studs, air control0.55. Sprint disabled; no slide or custom ground acceleration/deceleration. Unsupported controls must remain unavailable.
- `WeaponController`, `CombatService`, `WeaponState`: one shotgun definition shared by two independent slots. Client prediction and ordinary WeaponAction requests, server state/damage/raycast validation. Timing tables are referenced but magazine capacity is copied into state rules. Live updates must preserve ammo, counters and existing action deadlines; changing reload rules mid-reload is unsafe.
- `WeaponConfig`:10 pellets,9 base damage, deterministic center/inner/outer spread,1s same-gun/.4s global interval, .15s swap, .3/.5/.3s reload start/insert/end,5 shells. Damage falloff9–45 studs to.25,150 maximum range. Existing recoil2.2deg/.18s recovery. Preserve these defaults.
- `AudioController`: central factory for one-shots and serialized ambience loops;51 configured cue IDs, builtin fallbacks and blank unused music/hover/pump entries. Master→Effects/UI/Music groups apply personal preferences. Footsteps .13, ambience .025. No granular developer buses yet. All new mix controls must multiply rather than replace personal preferences and update currently playing audio.

## Integration plan and boundaries

Add shared setting registry, validation/runtime mapping and versioned scoped presets. Reuse existing aim calculations and remote service, extend the panel and input fencing. Keep legacy aim profiles readable; new console presets use a separate development namespace. Movement/weapon values are shared server-session state; diagnostics and window state are local. Auto fire defaults off and uses ordinary validated firing requests, never direct damage. Weapon changes require a safe transition/revision handshake rather than resetting ammunition or shortening an in-progress deadline.

Baseline private Lune suite: **426 passed,0 failed**. Full type/lint checks require their existing external definitions; record actual outcomes later. No physical-device certification inferred from emulator tests.

**Approval gate:** implement/test/capture actual desktop and emulated-mobile UI, then stop. No commit, publication, production configuration edits or uploads before owner screenshot approval.
