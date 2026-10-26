# Developer console configuration — schema2

Development only. All five categories are shared session configuration broadcast by the authorized server; camera/audio handlers apply locally to each test client. Diagnostics, window position and shortcut selection are session-local. Personal player settings remain separate. Presets are stored per developer/name/scope, never automatically loaded or promoted to production.

Touch auto fire defaults ON with instant acquisition; Auto Swap Weapons defaults OFF. Mouse/controller auto fire remain OFF. Other defaults preserve the verified build. Existing .4s global shot interval, headshot multipliers, equip time and validation tolerances are not tunable in this implementation. Both independent pumps share one weapon definition. Weapon changes wait for active reload/raise actions, preserve existing deadlines/counters, clamp reduced capacity and never refill increased capacity.

## Validation and units

Acquisition radius is a fraction of the shorter viewport dimension, measured from screen center. Angles use degrees; world distances use studs; timings seconds; bus gains multiply the existing mix and personal preferences. Individual audio levels are absolute baseline levels converted to cue-bus gain; fades and per-instance contextual multipliers remain intact. Spatial overrides are optional for cues whose attenuation is inherited. Solid walls always block aim/auto fire even if the additional strict-query visibility test is disabled.

New pellet counts keep the original first ten pattern points; extra pellets use a deterministic outer-ring progression. Spread is a multiplier of the original pattern, never compounded across edits. Full empty reload is start + capacity × insert; reload-end is presentation only. Touch/controller/mouse have independent eligibility, assistance-scale and sensitivity overrides over the shared aim response. Mouse eligibility is additionally limited to authorized developers.

## movement

| ID | Name | Default | Range / options | Unit | Availability |
|---|---|---|---|---|---|
| movement.walk | Walk Speed | 20 | 4–40 | studs/s | Available |
| movement.crouch | Crouch Speed | 11 | 2–30 | studs/s | Available |
| movement.jump | Jump Height | 7.6 | 0–20 | studs | Available |
| movement.air | Air Control | 0.55 | 0–1 | blend | Available |
| movement.sprint | Sprint Speed | 24 | fixed |  | Unavailable |
| movement.acceleration | Acceleration | 0 | fixed |  | Unavailable |
| movement.deceleration | Deceleration | 0 | fixed |  | Unavailable |
| movement.slide | Slide Speed | 0 | fixed |  | Unavailable |
| movement.friction | Slide Friction | 0 | fixed |  | Unavailable |

## aiming

| ID | Name | Default | Range / options | Unit | Availability |
|---|---|---|---|---|---|
| aiming.enabled | Aim Assist Enabled | True | true / false |  | Available |
| aiming.slowdownEnabled | Aim Slowdown Enabled | True | true / false |  | Available |
| aiming.slowdownStrength | Aim Slowdown Strength | 0.4 | 0–0.8 | fraction | Available |
| aiming.rotationEnabled | Rotational Assist Enabled | True | true / false |  | Available |
| aiming.rotationStrength | Rotational Assist Strength | 0.2 | 0–0.6 | fraction | Available |
| aiming.radius | Target Acquisition Radius | 0.12 | 0.02–0.3 | short-screen fraction | Available |
| aiming.maxDistance | Maximum Target Distance | 100 | 5–150 | studs | Available |
| aiming.trackingSpeed | Target Tracking Speed | 8 | 0–30 | response/s | Available |
| aiming.switchThreshold | Target Switching Threshold | 0.2 | 0–0.8 | relative improvement | Available |
| aiming.lineOfSight | Strict Query Visibility | True | true / false |  | Available |
| aiming.touchEligible | Touchscreen Eligibility | True | true / false |  | Available |
| aiming.touchStrength | Touchscreen Assist Scale | 1 | 0–1 | multiplier | Available |
| aiming.touchSensitivity | Touchscreen Sensitivity | 1 | 0.25–2 | multiplier | Available |
| aiming.controllerEligible | Controller Eligibility | True | true / false |  | Available |
| aiming.controllerStrength | Controller Assist Scale | 1 | 0–1 | multiplier | Available |
| aiming.controllerSensitivity | Controller Sensitivity | 1 | 0.25–2 | multiplier | Available |
| aiming.mouseEligible | Mouse / Keyboard Eligibility | False | true / false |  | Available |
| aiming.mouseStrength | Mouse / Keyboard Assist Scale | 1 | 0–1 | multiplier | Available |
| aiming.mouseSensitivity | Mouse / Keyboard Sensitivity | 1 | 0.25–2 | multiplier | Available |

## autoFire

| ID | Name | Default | Range / options | Unit | Availability |
|---|---|---|---|---|---|
| autoFire.enabled | Auto Fire Enabled | True | true / false |  | Available |
| autoFire.autoSwap | Auto Swap Weapons | False | true / false | | Available |
| autoFire.radius | Activation Radius | 0.1 | 0.005–0.15 | short-screen fraction | Available |
| autoFire.delay | Activation Delay | 0 | 0–2 | s | Available |
| autoFire.maxDistance | Maximum Target Distance | 150 | 5–150 | studs | Available |
| autoFire.persistence | Target Persistence | 0 | 0–1.5 | s | Available |
| autoFire.cooldown | Firing Cooldown | 0.4 | 0.4–3 | s | Available |
| autoFire.lineOfSight | Strict Query Visibility | True | true / false |  | Available |
| autoFire.touchEligible | Touchscreen | True | true / false |  | Available |
| autoFire.controllerEligible | Controller | False | true / false |  | Available |
| autoFire.mouseEligible | Mouse Test Override | False | true / false |  | Available |

## weapons

| ID | Name | Default | Range / options | Unit | Availability |
|---|---|---|---|---|---|
| weapons.damage | Damage per Pellet | 9 | 1–30 | HP | Available |
| weapons.pellets | Pellet Count | 10 | 1–20 | pellets | Available |
| weapons.spread | Pellet Spread | 1 | 0.25–2 | pattern multiplier | Available |
| weapons.range | Maximum Damage Range | 150 | 10–300 | studs | Available |
| weapons.falloffStart | Damage Falloff Start | 9 | 0–200 | studs | Available |
| weapons.falloffEnd | Damage Falloff End | 45 | 1–300 | studs | Available |
| weapons.minDamage | Minimum Damage Multiplier | 0.25 | 0–1 | fraction | Available |
| weapons.cooldown | Fire Cooldown | 1 | 0.4–3 | s | Available |
| weapons.reloadStart | Reload Start | 0.3 | 0.1–2 | s | Available |
| weapons.reloadInsert | Reload per Shell | 0.5 | 0.15–2 | s | Available |
| weapons.reloadEnd | Reload End (visual) | 0.3 | 0.1–2 | s | Available |
| weapons.swap | Weapon Switch Duration | 0.15 | 0.1–1 | s | Available |
| weapons.recoil | Recoil Pitch | 2.2 | 0–8 | degrees | Available |
| weapons.recovery | Recoil Recovery Time | 0.18 | 0.05–1 | s | Available |
| weapons.capacity | Ammunition Capacity | 5 | 1–10 | shells | Available |

## audio

| ID | Name | Default | Range / options | Unit | Availability |
|---|---|---|---|---|---|
| audio.bus_Master | Master Mix | 1 | 0–2 | gain | Available |
| audio.bus_Weapons | Weapons Mix | 1 | 0–2 | gain | Available |
| audio.bus_Gunshots | Gunshots Mix | 1 | 0–2 | gain | Available |
| audio.bus_Reload | Reload Mix | 1 | 0–2 | gain | Available |
| audio.bus_Switching | Switching Mix | 1 | 0–2 | gain | Available |
| audio.bus_Impacts | Impacts Mix | 1 | 0–2 | gain | Available |
| audio.bus_Handling | Handling Mix | 1 | 0–2 | gain | Available |
| audio.bus_Movement | Movement Mix | 1 | 0–2 | gain | Available |
| audio.bus_Footsteps | Footsteps Mix | 1 | 0–2 | gain | Available |
| audio.bus_Landing | Landing Mix | 1 | 0–2 | gain | Available |
| audio.bus_Environment | Environment Mix | 1 | 0–2 | gain | Available |
| audio.bus_Ambience | Ambience Mix | 1 | 0–2 | gain | Available |
| audio.bus_Interface | Interface Mix | 1 | 0–2 | gain | Available |
| audio.bus_Music | Music Mix | 1 | 0–2 | gain | Unavailable |
| audio.StepConcrete_volume | StepConcrete Volume | 0.13 | 0–0.52 | level | Available |
| audio.StepConcrete_mute | StepConcrete Mute | False | true / false |  | Available |
| audio.StepMetal_volume | StepMetal Volume | 0.13 | 0–0.52 | level | Available |
| audio.StepMetal_mute | StepMetal Mute | False | true / false |  | Available |
| audio.StepSand_volume | StepSand Volume | 0.13 | 0–0.52 | level | Available |
| audio.StepSand_mute | StepSand Mute | False | true / false |  | Available |
| audio.StepWood_volume | StepWood Volume | 0.13 | 0–0.52 | level | Available |
| audio.StepWood_mute | StepWood Mute | False | true / false |  | Available |
| audio.Landing_volume | Landing Volume | 0.65 | 0–1.5 | level | Available |
| audio.Landing_mute | Landing Mute | False | true / false |  | Available |
| audio.RangeAir_volume | RangeAir Volume | 0.025 | 0–0.1 | level | Available |
| audio.RangeAir_mute | RangeAir Mute | False | true / false |  | Available |
| audio.Assist_volume | Assist Volume | 0.35 | 0–1.4 | level | Available |
| audio.Assist_mute | Assist Mute | False | true / false |  | Available |
| audio.Unlock_volume | Unlock Volume | 0.6 | 0–1.5 | level | Available |
| audio.Unlock_mute | Unlock Mute | False | true / false |  | Available |
| audio.Confirm_volume | Confirm Volume | 0.3 | 0–1.2 | level | Available |
| audio.Confirm_mute | Confirm Mute | False | true / false |  | Available |
| audio.Error_volume | Error Volume | 0.3 | 0–1.2 | level | Available |
| audio.Error_mute | Error Mute | False | true / false |  | Available |
| audio.TimeWarning_volume | TimeWarning Volume | 0.4 | 0–1.5 | level | Available |
| audio.TimeWarning_mute | TimeWarning Mute | False | true / false |  | Available |
| audio.Overtime_volume | Overtime Volume | 0.5 | 0–1.5 | level | Available |
| audio.Overtime_mute | Overtime Mute | False | true / false |  | Available |
| audio.ImpactWood_volume | ImpactWood Volume | 0.25 | 0–1 | level | Available |
| audio.ImpactWood_mute | ImpactWood Mute | False | true / false |  | Available |
| audio.ImpactWood_min | ImpactWood Near Distance | 8 | 1–100 | studs | Available |
| audio.ImpactWood_max | ImpactWood Far Distance | 70 | 10–500 | studs | Available |
| audio.ImpactWood_rolloff | ImpactWood Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.ImpactMetal_volume | ImpactMetal Volume | 0.25 | 0–1 | level | Available |
| audio.ImpactMetal_mute | ImpactMetal Mute | False | true / false |  | Available |
| audio.ImpactMetal_min | ImpactMetal Near Distance | 8 | 1–100 | studs | Available |
| audio.ImpactMetal_max | ImpactMetal Far Distance | 70 | 10–500 | studs | Available |
| audio.ImpactMetal_rolloff | ImpactMetal Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.ImpactHard_volume | ImpactHard Volume | 0.25 | 0–1 | level | Available |
| audio.ImpactHard_mute | ImpactHard Mute | False | true / false |  | Available |
| audio.ImpactHard_min | ImpactHard Near Distance | 8 | 1–100 | studs | Available |
| audio.ImpactHard_max | ImpactHard Far Distance | 70 | 10–500 | studs | Available |
| audio.ImpactHard_rolloff | ImpactHard Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.ReloadEnd_volume | ReloadEnd Volume | 0.3 | 0–1.2 | level | Available |
| audio.ReloadEnd_mute | ReloadEnd Mute | False | true / false |  | Available |
| audio.MasteryMilestone_volume | MasteryMilestone Volume | 0.7 | 0–1.5 | level | Available |
| audio.MasteryMilestone_mute | MasteryMilestone Mute | False | true / false |  | Available |
| audio.ReturnToRange_volume | ReturnToRange Volume | 0.4 | 0–1.5 | level | Available |
| audio.ReturnToRange_mute | ReturnToRange Mute | False | true / false |  | Available |
| audio.Admitted_volume | Admitted Volume | 0.5 | 0–1.5 | level | Available |
| audio.Admitted_mute | Admitted Mute | False | true / false |  | Available |
| audio.QueueCancel_volume | QueueCancel Volume | 0.4 | 0–1.5 | level | Available |
| audio.QueueCancel_mute | QueueCancel Mute | False | true / false |  | Available |
| audio.QueueCountdown_volume | QueueCountdown Volume | 0.35 | 0–1.4 | level | Available |
| audio.QueueCountdown_mute | QueueCountdown Mute | False | true / false |  | Available |
| audio.QueueLeave_volume | QueueLeave Volume | 0.35 | 0–1.4 | level | Available |
| audio.QueueLeave_mute | QueueLeave Mute | False | true / false |  | Available |
| audio.QueueJoin_volume | QueueJoin Volume | 0.4 | 0–1.5 | level | Available |
| audio.QueueJoin_mute | QueueJoin Mute | False | true / false |  | Available |
| audio.Fire_volume | Fire Volume | 0.9 | 0–1.5 | level | Available |
| audio.Fire_mute | Fire Mute | False | true / false |  | Available |
| audio.Fire_min | Fire Near Distance | 8 | 1–100 | studs | Available |
| audio.Fire_max | Fire Far Distance | 160 | 10–500 | studs | Available |
| audio.Fire_rolloff | Fire Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.PumpBack_volume | PumpBack Volume | 0.38 | 0–1.5 | level | Available |
| audio.PumpBack_mute | PumpBack Mute | False | true / false |  | Available |
| audio.PumpBack_min | PumpBack Near Distance | 8 | 1–100 | studs | Available |
| audio.PumpBack_max | PumpBack Far Distance | 50 | 10–500 | studs | Available |
| audio.PumpBack_rolloff | PumpBack Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.PumpForward_volume | PumpForward Volume | 0.42 | 0–1.5 | level | Available |
| audio.PumpForward_mute | PumpForward Mute | False | true / false |  | Available |
| audio.PumpForward_min | PumpForward Near Distance | 8 | 1–100 | studs | Available |
| audio.PumpForward_max | PumpForward Far Distance | 50 | 10–500 | studs | Available |
| audio.PumpForward_rolloff | PumpForward Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.Equip_volume | Equip Volume | 0.5 | 0–1.5 | level | Available |
| audio.Equip_mute | Equip Mute | False | true / false |  | Available |
| audio.Swap_volume | Swap Volume | 0.55 | 0–1.5 | level | Available |
| audio.Swap_mute | Swap Mute | False | true / false |  | Available |
| audio.Swap_min | Swap Near Distance | 8 | 1–100 | studs | Available |
| audio.Swap_max | Swap Far Distance | 40 | 10–500 | studs | Available |
| audio.Swap_rolloff | Swap Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.ShellInsert_volume | ShellInsert Volume | 0.5 | 0–1.5 | level | Available |
| audio.ShellInsert_mute | ShellInsert Mute | False | true / false |  | Available |
| audio.ReloadStart_volume | ReloadStart Volume | 0.4 | 0–1.5 | level | Available |
| audio.ReloadStart_mute | ReloadStart Mute | False | true / false |  | Available |
| audio.EmptyClick_volume | EmptyClick Volume | 0.6 | 0–1.5 | level | Available |
| audio.EmptyClick_mute | EmptyClick Mute | False | true / false |  | Available |
| audio.ShellBounce_volume | ShellBounce Volume | 0.25 | 0–1 | level | Available |
| audio.ShellBounce_mute | ShellBounce Mute | False | true / false |  | Available |
| audio.ShellBounce_min | ShellBounce Near Distance | 8 | 1–100 | studs | Available |
| audio.ShellBounce_max | ShellBounce Far Distance | 25 | 10–500 | studs | Available |
| audio.ShellBounce_rolloff | ShellBounce Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.HitBody_volume | HitBody Volume | 0.55 | 0–1.5 | level | Available |
| audio.HitBody_mute | HitBody Mute | False | true / false |  | Available |
| audio.HitHead_volume | HitHead Volume | 0.6 | 0–1.5 | level | Available |
| audio.HitHead_mute | HitHead Mute | False | true / false |  | Available |
| audio.Elimination_volume | Elimination Volume | 0.75 | 0–1.5 | level | Available |
| audio.Elimination_mute | Elimination Mute | False | true / false |  | Available |
| audio.DoublePumpElim_volume | DoublePumpElim Volume | 0.85 | 0–1.5 | level | Available |
| audio.DoublePumpElim_mute | DoublePumpElim Mute | False | true / false |  | Available |
| audio.DamageTaken_volume | DamageTaken Volume | 0.6 | 0–1.5 | level | Available |
| audio.DamageTaken_mute | DamageTaken Mute | False | true / false |  | Available |
| audio.Death_volume | Death Volume | 0.6 | 0–1.5 | level | Available |
| audio.Death_mute | Death Mute | False | true / false |  | Available |
| audio.Spawn_volume | Spawn Volume | 0.45 | 0–1.5 | level | Available |
| audio.Spawn_mute | Spawn Mute | False | true / false |  | Available |
| audio.CountdownTick_volume | CountdownTick Volume | 0.6 | 0–1.5 | level | Available |
| audio.CountdownTick_mute | CountdownTick Mute | False | true / false |  | Available |
| audio.MatchStart_volume | MatchStart Volume | 0.7 | 0–1.5 | level | Available |
| audio.MatchStart_mute | MatchStart Mute | False | true / false |  | Available |
| audio.MatchEnd_volume | MatchEnd Volume | 0.7 | 0–1.5 | level | Available |
| audio.MatchEnd_mute | MatchEnd Mute | False | true / false |  | Available |
| audio.Victory_volume | Victory Volume | 0.75 | 0–1.5 | level | Available |
| audio.Victory_mute | Victory Mute | False | true / false |  | Available |
| audio.Defeat_volume | Defeat Volume | 0.7 | 0–1.5 | level | Available |
| audio.Defeat_mute | Defeat Mute | False | true / false |  | Available |
| audio.UIClick_volume | UIClick Volume | 0.45 | 0–1.5 | level | Available |
| audio.UIClick_mute | UIClick Mute | False | true / false |  | Available |
| audio.Vote_volume | Vote Volume | 0.5 | 0–1.5 | level | Available |
| audio.Vote_mute | Vote Mute | False | true / false |  | Available |
| audio.Reward_volume | Reward Volume | 0.55 | 0–1.5 | level | Available |
| audio.Reward_mute | Reward Mute | False | true / false |  | Available |
| audio.LevelUp_volume | LevelUp Volume | 0.7 | 0–1.5 | level | Available |
| audio.LevelUp_mute | LevelUp Mute | False | true / false |  | Available |
| audio.AmbWarehouse_volume | AmbWarehouse Volume | 0.025 | 0–0.1 | level | Available |
| audio.AmbWarehouse_mute | AmbWarehouse Mute | False | true / false |  | Available |
| audio.AmbDustTown_volume | AmbDustTown Volume | 0.025 | 0–0.1 | level | Available |
| audio.AmbDustTown_mute | AmbDustTown Mute | False | true / false |  | Available |
| audio.AmbRooftops_volume | AmbRooftops Volume | 0.025 | 0–0.1 | level | Available |
| audio.AmbRooftops_mute | AmbRooftops Mute | False | true / false |  | Available |
| audio.Equip_spatial | Equip Spatial Override | False | true / false |  | Available |
| audio.Equip_min | Equip Near Distance | 5 | 1–100 | studs | Available |
| audio.Equip_max | Equip Far Distance | 150 | 10–500 | studs | Available |
| audio.Equip_rolloff | Equip Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.ReloadStart_spatial | ReloadStart Spatial Override | False | true / false |  | Available |
| audio.ReloadStart_min | ReloadStart Near Distance | 5 | 1–100 | studs | Available |
| audio.ReloadStart_max | ReloadStart Far Distance | 150 | 10–500 | studs | Available |
| audio.ReloadStart_rolloff | ReloadStart Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.ShellInsert_spatial | ShellInsert Spatial Override | False | true / false |  | Available |
| audio.ShellInsert_min | ShellInsert Near Distance | 5 | 1–100 | studs | Available |
| audio.ShellInsert_max | ShellInsert Far Distance | 150 | 10–500 | studs | Available |
| audio.ShellInsert_rolloff | ShellInsert Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.ReloadEnd_spatial | ReloadEnd Spatial Override | False | true / false |  | Available |
| audio.ReloadEnd_min | ReloadEnd Near Distance | 5 | 1–100 | studs | Available |
| audio.ReloadEnd_max | ReloadEnd Far Distance | 150 | 10–500 | studs | Available |
| audio.ReloadEnd_rolloff | ReloadEnd Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.EmptyClick_spatial | EmptyClick Spatial Override | False | true / false |  | Available |
| audio.EmptyClick_min | EmptyClick Near Distance | 5 | 1–100 | studs | Available |
| audio.EmptyClick_max | EmptyClick Far Distance | 150 | 10–500 | studs | Available |
| audio.EmptyClick_rolloff | EmptyClick Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.StepConcrete_spatial | StepConcrete Spatial Override | False | true / false |  | Available |
| audio.StepConcrete_min | StepConcrete Near Distance | 5 | 1–100 | studs | Available |
| audio.StepConcrete_max | StepConcrete Far Distance | 150 | 10–500 | studs | Available |
| audio.StepConcrete_rolloff | StepConcrete Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.StepMetal_spatial | StepMetal Spatial Override | False | true / false |  | Available |
| audio.StepMetal_min | StepMetal Near Distance | 5 | 1–100 | studs | Available |
| audio.StepMetal_max | StepMetal Far Distance | 150 | 10–500 | studs | Available |
| audio.StepMetal_rolloff | StepMetal Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.StepSand_spatial | StepSand Spatial Override | False | true / false |  | Available |
| audio.StepSand_min | StepSand Near Distance | 5 | 1–100 | studs | Available |
| audio.StepSand_max | StepSand Far Distance | 150 | 10–500 | studs | Available |
| audio.StepSand_rolloff | StepSand Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.StepWood_spatial | StepWood Spatial Override | False | true / false |  | Available |
| audio.StepWood_min | StepWood Near Distance | 5 | 1–100 | studs | Available |
| audio.StepWood_max | StepWood Far Distance | 150 | 10–500 | studs | Available |
| audio.StepWood_rolloff | StepWood Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.Landing_spatial | Landing Spatial Override | False | true / false |  | Available |
| audio.Landing_min | Landing Near Distance | 5 | 1–100 | studs | Available |
| audio.Landing_max | Landing Far Distance | 150 | 10–500 | studs | Available |
| audio.Landing_rolloff | Landing Rolloff | InverseTapered | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.bus_Jumping | Jumping Mix | 1 | 0–2 | gain | Available |
| audio.bus_OtherMovement | OtherMovement Mix | 1 | 0–2 | gain | Available |
| audio.EngineJumping_volume | Jumping Volume | 0.65 | 0–1.5 | level | Available |
| audio.EngineJumping_mute | Jumping Mute | False | true / false |  | Available |
| audio.EngineJumping_min | Jumping Near Distance | 5 | 1–100 | studs | Available |
| audio.EngineJumping_max | Jumping Far Distance | 150 | 10–500 | studs | Available |
| audio.EngineJumping_rolloff | Jumping Rolloff | Inverse | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.EngineClimbing_volume | Climbing Volume | 0.65 | 0–1.5 | level | Available |
| audio.EngineClimbing_mute | Climbing Mute | False | true / false |  | Available |
| audio.EngineClimbing_min | Climbing Near Distance | 5 | 1–100 | studs | Available |
| audio.EngineClimbing_max | Climbing Far Distance | 150 | 10–500 | studs | Available |
| audio.EngineClimbing_rolloff | Climbing Rolloff | Inverse | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.EngineGettingUp_volume | GettingUp Volume | 0.65 | 0–1.5 | level | Available |
| audio.EngineGettingUp_mute | GettingUp Mute | False | true / false |  | Available |
| audio.EngineGettingUp_min | GettingUp Near Distance | 5 | 1–100 | studs | Available |
| audio.EngineGettingUp_max | GettingUp Far Distance | 150 | 10–500 | studs | Available |
| audio.EngineGettingUp_rolloff | GettingUp Rolloff | Inverse | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.EngineSwimming_volume | Swimming Volume | 0.65 | 0–1.5 | level | Available |
| audio.EngineSwimming_mute | Swimming Mute | False | true / false |  | Available |
| audio.EngineSwimming_min | Swimming Near Distance | 5 | 1–100 | studs | Available |
| audio.EngineSwimming_max | Swimming Far Distance | 150 | 10–500 | studs | Available |
| audio.EngineSwimming_rolloff | Swimming Rolloff | Inverse | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.EngineSplash_volume | Splash Volume | 0.65 | 0–1.5 | level | Available |
| audio.EngineSplash_mute | Splash Mute | False | true / false |  | Available |
| audio.EngineSplash_min | Splash Near Distance | 5 | 1–100 | studs | Available |
| audio.EngineSplash_max | Splash Far Distance | 150 | 10–500 | studs | Available |
| audio.EngineSplash_rolloff | Splash Rolloff | Inverse | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
| audio.EngineFreeFalling_volume | FreeFalling Volume | 0.65 | 0–1.5 | level | Available |
| audio.EngineFreeFalling_mute | FreeFalling Mute | False | true / false |  | Available |
| audio.EngineFreeFalling_min | FreeFalling Near Distance | 5 | 1–100 | studs | Available |
| audio.EngineFreeFalling_max | FreeFalling Far Distance | 150 | 10–500 | studs | Available |
| audio.EngineFreeFalling_rolloff | FreeFalling Rolloff | Inverse | InverseTapered, Inverse, Linear, LinearSquare |  | Available |
