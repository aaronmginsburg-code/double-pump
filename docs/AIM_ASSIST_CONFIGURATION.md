# Development aim-assist configuration

Schema **1**, module `aimAssist`. Development-only universe **10772492892**, place **139437092998076**. No public configuration promotion exists. Initial values are conservative test starting points, not certified balance recommendations. Master defaults on for touch/controller, always excluded for mouse/keyboard.

| Key | Default | Valid range | Meaning |
|---|---:|---|---|
| enabled | true | boolean | Master switch; disabled yields identity input/no rotation immediately |
| slowdownEnabled | true | boolean | Independent sensitivity attenuation |
| slowdownStrength | 0.40 | 0–0.80 | Fractional maximum reduction at target center; min manual sensitivity0.20× |
| rotationEnabled | true | boolean | Independent gentle camera steering during current-frame aim input only |
| rotationStrength | 0.20 | 0–0.60 | Response multiplier; angular speed also limited to35×strength degrees/sec |
| radius | 0.12 | 0.02–0.30 | Circle radius as fraction of shorter viewport edge; NOT pixels, diameter or angular degrees |
| maxDistance | 100 | 5–150 | Camera-to-target torso distance in studs |
| trackingSpeed | 8 | 0–30 | Exponential response/sec, multiplied by rotational strength and target proximity;0 means no rotation |
| switchThreshold | 0.20 | 0–0.80 | New candidate must improve normalized crosshair distance by this fraction over valid current target |
| lineOfSight | true | boolean | Strict queryable-prop visibility in addition to mandatory solid-wall occlusion |

**Solid walls always block assistance.** Turning strict LOS off permits ignoring noncolliding queryable props only; it never permits wall tracking. The UI calls this “Strict Queryable Line of Sight” to make that constraint explicit. Acquisition never selects dead/frozen/self/cross-context/behind-screen/outside-radius/out-of-range candidates. Match teammates excluded; lobby players and existing practice dummies use nonlethal practice eligibility.

Slowdown uses squared center proximity, eased at18/sec. Rotation uses the same proximity and bounded exponential response, dt clamped to50ms to avoid stall catch-up. Pitch remains constrained by the existing camera. Target acquisition10Hz; selected target safety/visibility is checked before each assisted frame. No config can modify pellets, damage, recoil, ammo, reload, swap or shot eligibility.

## Developer workflow

Explicit server allowlist: **11808586604**, sourced from existing private feedback IntegrationConfig. Other players receive the current server configuration but cannot tune, export or save/load. No shipped negative-user or generic Studio authorization shortcut. The panel is created only after server authorization.

Open **DEV TUNING · F6** (button or F6). Drag the header; scroll and collapse sections. Tap toggles or drag sliders; adjustments apply to everyone in the **current private server** after server validation. Close the panel to resume combat. Opening clears held input, pending mobile fire and look ownership. It does not change movement speed. Closed UI leaves only the small launcher.

Profiles: `default`, `touch`, `controller`, owned by each allowlisted developer. These are labels/slots, not device auto-selection. **Load** checks the slot and explicitly applies saved values if present. An empty Load retains current values and permits first Save. Save requires a second **CONFIRM** click; server revision checks reject overwriting a changed slot. **Reset** changes live values only. Initial server starts use defaults; no automatic save or automatic persisted rollout. After joining a new server, explicitly Load the desired slot.

Live status shows configuration revision and whether it matches this slot's last loaded/saved values. A missing saved baseline is explicitly unsaved. DataStore errors preserve live values; if a write outcome is uncertain, Load before retrying. Never change an unknown/future schema automatically.

**JSON** shows selectable, JSON-compatible export in the panel; select/copy into a file or a Codex request. Close/reopen to return to controls. This is an export for review, not an upload or production-promotion action.

Storage is separate from player profiles: `DoublePump_DevTuning_v1`, scope `u10772492892`, key `u_<developerUserId>_<slot>`, record `{schema:1, revision:N, values:{...}}`. No profile migration or inventory writes. `UpdateAsync` verifies previous revision inside every retry callback. Server restarts do not erase explicitly saved profiles, subject to Roblox service availability.
