# Audio asset inventory — 2026-10-25

Source: private AssetIds, AudioController, MovementAudio and DeveloperConsole/AudioCatalog. Native character sound properties were read from the running Studio client. No audio uploads or asset-ID replacements occurred.

## Routing

Developer Master gain → personal Master preference → personal Effects/UI/Music preference → developer family buses → individual cue bus → Sound.Volume (including fades/context multipliers). Weapon subfamilies share Weapons; footsteps/landing/native movement share Movement; ambience shares Environment. UI and hit/result notifications share Interface. Music is unavailable because MusicMenu is blank. Diagnostics report source, cue bus, raw/effective gain, playback state and simultaneous same-cue count; multiple simultaneous sounds are a review signal, not automatically a bug.

One-shots are centrally created, cleaned on Ended/Debris; positional shots/impacts use Attachments or parts. Ambience beds are serialized loops with .25s fade-out and .35s fade-in to .025. Four surface footsteps remain .13; landing .65. MovementAudio retains engine attenuation unless the developer explicitly enables an override. Native Jumping/Climbing/GettingUp/Swimming/Splash/FreeFalling are observed and assigned cue groups without replacing the engine controller. Native Running/Landing are intentionally muted in favor of approved one-shots; native Died is also observed muted.

| Cue | Asset | Family | Baseline | Loop | Spatial baseline |
|---|---|---|---|---|---|
| StepConcrete | 127480360069744 | Footsteps | 0.13 | False | source/engine attenuation for positional playback; 2D otherwise |
| StepMetal | 87968940009629 | Footsteps | 0.13 | False | source/engine attenuation for positional playback; 2D otherwise |
| StepSand | 96114396174087 | Footsteps | 0.13 | False | source/engine attenuation for positional playback; 2D otherwise |
| StepWood | 118025107093825 | Footsteps | 0.13 | False | source/engine attenuation for positional playback; 2D otherwise |
| Landing | 119227276951004 | Landing | 0.65 | False | source/engine attenuation for positional playback; 2D otherwise |
| RangeAir | 107314588536789 | Ambience | 0.025 | True | source/engine attenuation for positional playback; 2D otherwise |
| Assist | 72366323452361 | Interface | 0.35 | False | source/engine attenuation for positional playback; 2D otherwise |
| Unlock | 132043275280472 | Interface | 0.6 | False | source/engine attenuation for positional playback; 2D otherwise |
| Confirm | 119959350292311 | Interface | 0.3 | False | source/engine attenuation for positional playback; 2D otherwise |
| Error | 133238281799902 | Interface | 0.3 | False | source/engine attenuation for positional playback; 2D otherwise |
| TimeWarning | 107321103973404 | Interface | 0.4 | False | source/engine attenuation for positional playback; 2D otherwise |
| Overtime | 131993078530333 | Interface | 0.5 | False | source/engine attenuation for positional playback; 2D otherwise |
| ImpactWood | 125794832817300 | Impacts | 0.25 | False | 8–70, InverseTapered |
| ImpactMetal | 82455709298224 | Impacts | 0.25 | False | 8–70, InverseTapered |
| ImpactHard | 128202319714882 | Impacts | 0.25 | False | 8–70, InverseTapered |
| ReloadEnd | 91588700050239 | Reload | 0.3 | False | source/engine attenuation for positional playback; 2D otherwise |
| MasteryMilestone | 85511675749835 | Interface | 0.7 | False | source/engine attenuation for positional playback; 2D otherwise |
| ReturnToRange | 111267390132943 | Interface | 0.4 | False | source/engine attenuation for positional playback; 2D otherwise |
| Admitted | 73939245280780 | Interface | 0.5 | False | source/engine attenuation for positional playback; 2D otherwise |
| QueueCancel | 90412393185987 | Interface | 0.4 | False | source/engine attenuation for positional playback; 2D otherwise |
| QueueCountdown | 136743664945691 | Interface | 0.35 | False | source/engine attenuation for positional playback; 2D otherwise |
| QueueLeave | 124530677310844 | Interface | 0.35 | False | source/engine attenuation for positional playback; 2D otherwise |
| QueueJoin | 109535765491493 | Interface | 0.4 | False | source/engine attenuation for positional playback; 2D otherwise |
| Fire | 76270373964419 | Gunshots | 0.9 | False | 8–160, InverseTapered |
| PumpBack | 110029776273911 | Handling | 0.38 | False | 8–50, InverseTapered |
| PumpForward | 82334124029040 | Handling | 0.42 | False | 8–50, InverseTapered |
| Equip | 76066705752904 | Switching | 0.5 | False | source/engine attenuation for positional playback; 2D otherwise |
| Swap | 120708988258180 | Switching | 0.55 | False | 8–40, InverseTapered |
| ShellInsert | 102336135537532 | Reload | 0.5 | False | source/engine attenuation for positional playback; 2D otherwise |
| ReloadStart | 95926422694750 | Reload | 0.4 | False | source/engine attenuation for positional playback; 2D otherwise |
| EmptyClick | 129023358510589 | Handling | 0.6 | False | source/engine attenuation for positional playback; 2D otherwise |
| ShellBounce | 85310208341495 | Impacts | 0.25 | False | 8–25, InverseTapered |
| HitBody | 122067256034974 | Interface | 0.55 | False | source/engine attenuation for positional playback; 2D otherwise |
| HitHead | 105275885463350 | Interface | 0.6 | False | source/engine attenuation for positional playback; 2D otherwise |
| Elimination | 93718579667184 | Interface | 0.75 | False | source/engine attenuation for positional playback; 2D otherwise |
| DoublePumpElim | 83664872569347 | Interface | 0.85 | False | source/engine attenuation for positional playback; 2D otherwise |
| DamageTaken | 103016997503788 | Interface | 0.6 | False | source/engine attenuation for positional playback; 2D otherwise |
| Death | 105465906827933 | Interface | 0.6 | False | source/engine attenuation for positional playback; 2D otherwise |
| Spawn | 81574290995171 | Interface | 0.45 | False | source/engine attenuation for positional playback; 2D otherwise |
| CountdownTick | 95699893390042 | Interface | 0.6 | False | source/engine attenuation for positional playback; 2D otherwise |
| MatchStart | 100823336379034 | Interface | 0.7 | False | source/engine attenuation for positional playback; 2D otherwise |
| MatchEnd | 128914040219922 | Interface | 0.7 | False | source/engine attenuation for positional playback; 2D otherwise |
| Victory | 128338264574038 | Interface | 0.75 | False | source/engine attenuation for positional playback; 2D otherwise |
| Defeat | 74379053980430 | Interface | 0.7 | False | source/engine attenuation for positional playback; 2D otherwise |
| UIClick | 97692260400881 | Interface | 0.45 | False | source/engine attenuation for positional playback; 2D otherwise |
| Vote | 83424934876088 | Interface | 0.5 | False | source/engine attenuation for positional playback; 2D otherwise |
| Reward | 90581179107431 | Interface | 0.55 | False | source/engine attenuation for positional playback; 2D otherwise |
| LevelUp | 130023511315158 | Interface | 0.7 | False | source/engine attenuation for positional playback; 2D otherwise |
| AmbWarehouse | 95360702770922 | Ambience | 0.025 | True | source/engine attenuation for positional playback; 2D otherwise |
| AmbDustTown | 130680677216207 | Ambience | 0.025 | True | source/engine attenuation for positional playback; 2D otherwise |
| AmbRooftops | 127043544223367 | Ambience | 0.025 | True | source/engine attenuation for positional playback; 2D otherwise |
| EngineJumping | rbxasset://sounds/action_jump.mp3 | Jumping | 0.65 | False | 5–150, Inverse (engine) |
| EngineClimbing | rbxasset://sounds/action_footsteps_plastic.mp3 | OtherMovement | 0.65 | True | 5–150, Inverse (engine) |
| EngineGettingUp | rbxasset://sounds/action_get_up.mp3 | OtherMovement | 0.65 | False | 5–150, Inverse (engine) |
| EngineSwimming | rbxasset://sounds/action_swim.mp3 | OtherMovement | 0.65 | True | 5–150, Inverse (engine) |
| EngineSplash | rbxasset://sounds/impact_water.mp3 | OtherMovement | 0.65 | False | 5–150, Inverse (engine) |
| EngineFreeFalling | rbxasset://sounds/action_falling.ogg | OtherMovement | 0.65 | True | 5–150, Inverse (engine) |

Blank Pump is a legacy full-cycle entry (split PumpBack/PumpForward are active); UIHover is blank and MusicMenu is blank. No new music, jump recording or sliding sound was fabricated. Builtin previews use the engine-owned asset path, not a new upload.

Higher gains can stack and clip; evaluate by ear at normal personal volume. Each cue/bus has bounded controls, and ambience boosts are limited to four times baseline. This is not an automatic loudness-normalization or clipping-limiter system.
