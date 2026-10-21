# Project status

Audit date: **2026-10-21**. Audited commit: **`534df2e`** on branch
`claude/full-game-build-3jb3hx` (draft PR #2). "Verified" below means checked against
the source, git, or a command run during this audit. "Claimed" means it is stated in
earlier docs or notes and was not re-checked.

## Identity

| | |
|---|---|
| Game | **Double Pump**: 5v5 first-person team deathmatch on Roblox, two pump shotguns each |
| Owner | Aaron (GitHub `aaronmginsburg-code`) |
| Repository | <https://github.com/aaronmginsburg-code/double-pump> (**public**, default branch `main`) |
| Project type | Rojo 7.4.4 project (`default.project.json`), Luau, toolchain pinned in `rokit.toml` |
| Published on Roblox | **No.** No experience, no place ID, no universe ID exists in the repo |

## Where the source lives

| Location | What it holds | Durable? |
|---|---|---|
| GitHub `claude/full-game-build-3jb3hx` (PR #2, draft, open) | **The complete game.** 142 files changed vs `main`, ~20.9k lines | Yes (GitHub). Not merged into `main`. |
| GitHub `claude/project-thread-lv25xu` (PR #1, draft, open) | Pump shotgun Blender asset: `.blend`, FBX/GLB exports, textures, renders, build scripts (~170 MB, plain git, no LFS) | Yes (GitHub). Not merged. Required for the shotgun import. |
| GitHub `claude/project-thread-19b8zl` (no PR) | Early "feel test" prototype (milestone 1, Oct 17–18). **Superseded** by PR #2; different file layout | Yes |
| GitHub `main` | Only the initial Rojo scaffold (`bae36c9`, 2026-10-17) | Yes |
| GitHub `claude/project-thread-nm90yn` | Same as `main`; unused (the handoff docs were committed to the PR #2 branch instead) | — |
| Claude project folder `/mnt/project-files/DoublePump/` | Same shotgun asset as PR #1 (verified identical, see below) | Claude-only storage, not reachable by Codex |
| Claude project folder `/mnt/project-files/double-pump`, `double-pump-sync`, `double-pump-tools` | Old scaffold copy, partial old feel-test files, a one-off `link-github.bat` | Obsolete |
| Aaron's PC `C:\Users\aaron\Documents\double-pump` | Git clone on the **old feel-test branch**, see below | Local disk only |

### Git audit (verified 2026-10-21)

```
claude/full-game-build-3jb3hx  534df2e 2026-10-21 04:18 UTC  M8: game design doc, development report, asset pipeline, publishing and playtest docs
                               a241585 2026-10-21 04:14 UTC  M4/M6/M7: maps, save data, progression, shop, leaderboards, receipts, touch controls
                               3e3843d 2026-10-21 03:43 UTC  M3: match flow UI, menus, scoreboard, results and voting, tutorial
                               9fab5dd 2026-10-21 03:28 UTC  Combat foundation: two-shotgun rules, pellets, damage, server validation, viewmodel, range
                               bae36c9 2026-10-17 21:20 UTC  Set up Rojo project scaffold   (= main)
claude/project-thread-lv25xu   fdeae96 2026-10-20  Add pump shotgun presentation renders
                               b83a64b 2026-10-20  Add pump shotgun asset: Blender master, rig, animations, textures, Roblox exports
claude/project-thread-19b8zl   33cc54e 2026-10-18  Stabilize prone ... (10 commits on top of bae36c9)
main                           bae36c9 2026-10-17  Set up Rojo project scaffold
```

- The cloud working copy used for this audit had no uncommitted or untracked files
  before the handoff docs were written (only the gitignored `sourcemap.json`).
- No generated place files (`.rbxl`/`.rbxlx`) are committed; they're gitignored and
  rebuilt with `rojo build`. No `.rbxm` models exist yet in `assets/roblox/`.
- Milestones M1–M8 were committed as 4 commits (M2 and M5 landed inside the M1 and
  M4/M6/M7 commits).
- No CI is configured (no `.github/workflows`).

### Aaron's local clone (checked over the device link, read-only)

- `HEAD` → `claude/project-thread-19b8zl` at `6c77104`, which is **5 commits behind**
  `origin/claude/project-thread-19b8zl` (`33cc54e`). The full-game branch has never been
  fetched there.
- `git status` there: 7 modified (`src/client/Movement.luau`, `src/client/Weapons.luau`,
  `src/server/Movement.luau`, `src/server/Weapons.luau`, `src/shared/Config.luau`,
  `src/shared/Hitboxes.luau`, `src/shared/Pose.luau`), 1 untracked
  (`src/server/Rig.luau`), nothing ignored. Most of this equals later GitHub commits on
  the same branch (up to `33cc54e`). The part that is on no commit is a small prone /
  collision-group experiment in 5 files (a "Bodies" collision group,
  `ProneBodyDrop = 1.0`, no `ClassicJoints` attribute; 48 added lines).
- **These are uncommitted local prototype changes, not GitHub source, and unrelated to
  PR #2.** They apply only to the superseded prototype.
- **Backed up 2026-10-21** (original folder untouched) to
  `C:\Users\aaron\Documents\double-pump-backups\2026-10-21-prototype-uncommitted\`:
  git bundle of the history, two patches (vs local HEAD `6c77104` and vs GitHub
  `33cc54e`), a byte-exact copy of the working tree, git metadata, `MANIFEST.md`,
  `RESTORE.md`, `SHA256SUMS.txt`. Verified: restoring from the bundle + patch reproduces
  all 28 working-tree files, and 51 of 52 files read back from the PC match their
  checksums (one deeply nested reflog couldn't be read back remotely; its size matches).
- No `rokit.toml` tools beyond the Oct 17 setup (Rokit, Rojo 7.4.4, Studio Rojo plugin,
  VS Code extensions, per project notes) are known to be installed there.

### Backup assessment

- **Game source and history: preserved on GitHub.** Every commit of the full game is on
  `origin/claude/full-game-build-3jb3hx`. Nothing of the game exists only in a Claude
  workspace.
- **Shotgun asset: preserved on GitHub** on `claude/project-thread-lv25xu`. Verified
  2026-10-21: all 100 files in `/mnt/project-files/DoublePump/` are on the branch;
  non-image files byte-identical, every PNG pixel-identical.
- **Risks:**
  1. Both PRs are unmerged drafts. Deleting either branch (for example "delete branch"
     after closing a PR) would orphan that work. Keep both branches until merged.
  2. The repo is **public**. The game, the asset sources and the docs are visible to
     anyone. If it should be private, the owner changes it in GitHub Settings (Codex must
     not).
  3. The uncommitted prototype edits on Aaron's PC exist only on that PC (working
     tree plus a local backup folder, see above). They are not on GitHub by choice.
  4. The build tooling used in Claude's containers (patched Selene, downloaded
     definitions, pip `bpy`) is not saved; it's reproducible from public downloads
     (see `AI_HANDOFF.md`, "Environment").

## Gameplay status

### Core loop (verified in source)

Join → practice range while fewer than 2 players (dummies) → intermission 10 s →
countdown 5 s → combat (5 min or score target 40, scaled down for small lobbies, minimum
15) → overtime 60 s sudden death if tied → results 9 s (winner, MVP, XP, coins) → map
vote 12 s among Warehouse / Dust Town / Rooftops → next map. Respawn 2.5 s, spawn
protection 2 s. Server: `src/server/Services/MatchService.luau`; rules:
`src/shared/Match/`.

### Implemented systems (code present, unit-tested where noted)

| System | Main files | Unit tests |
|---|---|---|
| Two independent pump shotguns (ammo, 1.0 s same-gun cooldown, 0.4 s min shot interval, 0.15 s swap, shell-by-shell interruptible reload) | `src/shared/Weapons/WeaponState.luau`, `Config/WeaponConfig.luau` | yes |
| Fixed 10-pellet pattern, falloff, head/torso/arm/leg multipliers | `Weapons/Spread.luau`, `Weapons/Damage.luau` | yes |
| Server authority: re-traced pellets, rewound hitboxes, origin/direction/timing checks, rate limits | `Services/CombatService.luau`, `Weapons/ShotValidation.luau`, `Weapons/PositionHistory.luau`, `Util/RateLimiter.luau` | partly (validation) |
| Damage, kills, assists, double-pump kill detection | `Services/DamageService.luau` | partly |
| Teams, join balancing, auto-balance | `Services/TeamService.luau`, `Match/TeamBalance.luau` | yes |
| Spawns, respawn, protection | `Services/CharacterService.luau`, `Match/SpawnScoring.luau` | yes (scoring) |
| 3 arenas + practice range built from parts at runtime | `src/server/Maps/` | yes (layout) |
| Client prediction, input (KBM, controller, touch), camera, first-person viewmodel, effects, audio | `src/client/Controllers/` | no |
| UI: menu, HUD, scoreboard, kill feed, death screen, results/MVP, vote, settings, tutorial, mobile layout editor, F2 debug overlay | `src/client/UI/` | no |
| Save data with session lock, repair, autosave | `src/server/Data/ProfileStore.luau`, `Services/DataService.luau` | yes (fake store) |
| XP/levels/mastery/challenges/stats/anti-idle | `src/shared/Progression/`, `Services/ProgressionService.luau` | yes |
| Cosmetic shop (16 colour-scheme skins, coins) | `Progression/Cosmetics.luau`, `Services/CosmeticService.luau` | partly |
| Leaderboards (all-time) | `Services/LeaderboardService.luau` | no |
| Robux coin packs + receipt processing (disabled) | `Config/Products.luau`, `Services/MonetizationService.luau`, `Data/Receipts.luau` | yes (receipts) |
| Shotgun model loader with stand-in fallback, baked animations | `Weapons/ShotgunModel.luau`, `ShotgunRig.luau`, `AnimPlayer.luau`, `ShotgunAnimData.luau` | no |

"Implemented" means the code exists, builds, type-checks and (where listed) passes unit
tests. **None of it has been run inside Roblox.** Treat every client-side and
networked behaviour as unverified until Studio testing.

### Incomplete / blocked on the owner

- Shotgun model not imported (stand-in in use).
- Sounds and map images not uploaded (mostly silent, plain vote cards).
- Experience not created; DataStores untested for real.
- No playtest of any kind. See `TESTING.md`.

### Known issues (found in this audit; none from play)

| # | Issue | Where | Severity |
|---|---|---|---|
| 1 | If the decal→image lookup fails, the upload script writes the **decal** ID into `AssetIds.Images.*` (only prints a warning); the vote card would then not render | `tools/upload_assets.py`, `main()` | Medium (tooling) |
| 2 | Decal→image lookup uses unauthenticated `assetdelivery.roblox.com/v1/asset`; may be refused by Roblox. Unverified | `tools/upload_assets.py`, `decal_to_image()` | Medium (tooling) |
| 3 | `tools/typecheck.sh` always exits 0, so it can't gate CI | `tools/typecheck.sh` | Low |
| 4 | `selene src` needs to download the Roblox API dump on first run (fails in sandboxed containers) | `selene.toml` | Low |
| 5 | Shotgun asset lives on a separate unmerged 170 MB branch; PR #2 depends on it for the import step | PR #1 / PR #2 | Process |
| 6 | Design drift vs. earlier decisions (see below) has not been confirmed by the owner | config | Needs decision |

### Design drift to confirm with the owner

Earlier project notes record decisions that the full build does not follow. The build
is internally consistent; these need the owner's yes/no, not a silent fix:

- **Shield:** notes mention 100 HP + 100 shield and the prototype spawned with 100 shield;
  the full build has 100 HP only (`GameConfig.Player.MaxHealth = 100`), no shield.
- **Swap/equip timing:** notes record an "easy baseline" 0.05 s equip delay and a 1.4 s
  per-gun cooldown in the design doc; the full build uses 0.15 s swap, 0.4 s minimum shot
  interval and 1.0 s same-gun cooldown.
- **Movement:** the prototype had sprint, slide, prone, dolphin dive and a third-person
  view; the full build is first-person only with crouch and jump, sprint off
  (`GameConfig.Movement.SprintEnabled = false`).
- Round length / score (5 min, 40 kills) and shield pickups were listed as "still open".

### Technical limitations (claimed in `DEVELOPMENT_REPORT.md`, consistent with source)

No bots; matches need 2+ players. Maps are built from parts at round start (server build
time unmeasured). Skins are colour tints, not models. All-time leaderboards only.
`StreamingEnabled` off. No logo art. Map previews are renders, not screenshots.

## Planned but not implemented

See [ROADMAP.md](ROADMAP.md).
