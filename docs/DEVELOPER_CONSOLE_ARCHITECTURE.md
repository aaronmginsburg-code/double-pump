# Developer console architecture

Local, uncommitted development candidate; publication requires owner screenshot approval.

## Modules

- Shared/DeveloperConsole/Registry: setting identifiers, labels, categories, types, defaults, units, ranges/options, descriptions, availability, persistence policy and handler key. One shared metadata source drives validation, UI and reference tables.
- Config: strict complete-table validation, unknown-field rejection, finite bounds, integer requirements, interdependent falloff/spatial constraints, copies, category merge and legacy aim migration.
- Runtime: maps validated values into existing GameConfig/WeaponConfig tables. Native movement and existing deterministic damage/state machinery continue operating.
- ProfileStore: injectable schema2 compare-and-swap adapter. Separate DoublePump_DevConsole_v2/u10772492892 store; old DoublePump_DevTuning_v1 is only read by explicit legacy import. Full and category presets use separate keys.
- AutoFire: pure acquisition/trigger state, independent of aim assist. Controller scans at10Hz and revalidates its selected target at20Hz, honors visibility/context/alive/frozen/device state, then calls WeaponController.fireMobile only when ordinary readiness permits. No swapping, direct damage, hidden trajectory change or reload interruption.
- AudioCatalog: approved cues, original mix and observed engine sounds. AudioController adds hierarchical SoundGroups and weak playback tracking. Existing personal preference groups, fades, contextual gains and cleanup remain.
- Layout: safe-viewport bounds used by UI and regression tests.
- DeveloperTuningService: existing exact-environment/UserId guard and request/state remotes, expanded to five categories. Live active revisions, rate limit, busy guard, scoped named presets, explicit migration and JSON export.
- DeveloperConsoleController: accepts validated state, applies client presentation, synchronizes weapon revisions, performs auto-fire acquisition, collects shot/feedback metrics.
- DeveloperPanel: extended existing shell/input ownership, category navigation, reusable rows, precise input, sliders, toggles, enum dropdowns, per-field reset, scoped actions, compare/export and diagnostics. Phone uses core/device safe areas and a separate action drawer.

## Authority and transitions

Every privileged operation validates DeveloperAccess against universe10772492892/place139437092998076 and UserId11808586604. Get returns state and authorization; it grants no mutation privileges. Production IDs fail closed.

Server movement applies immediately to living unfrozen humans/NPCs and remains in GameConfig for subsequent crouch/spawn/unfreeze operations. Client air steering uses the same values. No sprint/slide/ground acceleration implementation is added.

Weapon values requested by the panel are distinct from applied values until active reload/raise actions finish. Both server and client retain existing ammo/counters/deadlines. A tuning revision accompanies ordinary shots; old-revision shots are rejected before consumption and receive the existing authoritative snapshot. State rules keep the .4s global interval and all hit-validation/security checks. Additional configured pellets update the deterministic pattern, count and claim limit together.

## Persistence and failure behavior

Preset name uses1–24 letters/numbers/underscore/hyphen; scope is all or one registered category. Load-before-Save establishes the expected revision; Save requires a second UI confirmation. Compare-and-swap prevents concurrent overwrites and rejects unknown schemas. Category loads merge only that category and revalidate the entire result. Active revisions prevent delayed loads from overwriting later live edits.

No automatic loading at startup. Defaults are recoverable; active edits survive storage failures. JSON exports are versioned human-readable data for manual review, with no automated production promotion. Legacy aim-only slots default/touch/controller can be imported explicitly without writing to their original store.

## Extending

Register metadata, validation and a category handler; extend Config.Categories and the controller/service apply boundary. New game adapters should replace Double Pump runtime mapping and deployment allowlists, while reusing UI and scoped-preset logic. Do not copy the Double Pump IDs or assume another game's combat authority is equivalent.
