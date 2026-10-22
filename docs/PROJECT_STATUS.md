## Lobby update publication - 2026-10-21

Published privately as version 9 to existing place 82505574993280 (universe 10772275012). Creator Dashboard confirms owner/collaborator-only access. 245 automated tests pass; staged Studio multiplayer covers voluntary queueing, nonlethal lobby PvP, all arenas, match PvP and return to lobby. See LOBBY_AND_MATCHMAKING_UPDATE.md for evidence, retained diagnostic failures and manual test limits. Normal Roblox Player/mobile acceptance remains pending.

## 2026-10-21 - Permanent firing-range lobby and voluntary queue

Implemented a server-owned physical FIFO queue (2-10 players, 15 seconds), selected-roster map voting, nonlethal range PvP using the existing pellet damage pipeline, and full-health/ammo return to the lobby. Healthy transfers retain the prepared avatar; real deaths retain normal respawns. Base a487de38 with existing mobile/camera changes preserved; no commit/push. 245 tests pass; staged three-client Studio cycles verified all three arenas, real match PvP and return/requeue, plus an actual fourth late join. See `LOBBY_AND_MATCHMAKING_UPDATE.md` and `docs/lobby-matchmaking-evidence/` for exact evidence, initial failed probes and limitations. Private publication is tracked in the report. Weapon balance, control implementations and arena source files remain unchanged.

## Marketing asset delivery � 2026-10-21

Owner reports the latest mobile camera/independent-hand revision works properly.
Created marketing-only assets: three icon concepts, six thumbnail concepts, one
refined 512-square icon and three refined 1920x1080 thumbnails, with Studio captures,
editable SVG typography, generated masters and source prompts. Files are under
marketing/. No gameplay code, combat settings, maps, cloud version, access or
monetization was changed; no promotional art was uploaded. 197 tests pass and all
78 local scripts still match the previously verified candidate. See
[marketing report](../marketing/MARKETING_ASSET_REPORT.md) for provenance, capture
limitations, final files and upload instructions. Earlier sections are historical.

## Camera and independent weapon hand revision — 2026-10-21

Owner tested version 5 on iPhone 17 Pro Max with no technical issues. On
feat/mobile-controls (base a487de38a96261dbeac74e701e69ce31762123f9, uncommitted),
LOOK was removed and original displacement-based touch aiming restored. All other
mobile bounds and swipe/held-fire behavior remain unchanged. Control Layout and
Weapon Hand are independent canonical right/left preferences; profile v3 preserves
old coupled layout/weapon selections. Datastore name unchanged.

197 tests pass; type analysis, StyLua, Selene and Rojo pass. Local build and Studio
snapshot match all 78 script containers. Actual Studio checks include all four
combinations, drag axes/gesture separation, server-saved left UI/right weapon,
respawn continuity and desktop mouse/Q/R. Physical revised multitouch and live
rejoin/map-cycle testing remain pending. Privately published version 8 to the
existing experience; Dashboard confirms owner/collaborator-only access. Independently
reopened cloud copy matches all 78 tested sources. Version 5 remains recoverable.

See [MOBILE_CAMERA_AND_HANDEDNESS_UPDATE.md](../MOBILE_CAMERA_AND_HANDEDNESS_UPDATE.md)
for files, migration, screenshots, exact test scope, backup and publication state.
Earlier sections below are historical.

## Mobile private update — 2026-10-21

Implemented on `feat/mobile-controls`, based on
`a487de38a96261dbeac74e701e69ce31762123f9`; changes remain uncommitted.
**168 tests pass** (124 existing + 44 mobile); type analysis, StyLua, Selene and
Rojo build pass. Studio Practice, LOOK/release, fire taps, valid/invalid swipes,
both layouts/viewmodels, reload, server preference save, respawn and desktop
fire/Q/R were observed. Instrumented server-accepted alternate shots measured
0.439 / 0.630 seconds; simulated intent, not physical multitouch.

Published **version 5** to existing universe **10772275012**, start place
**82505574993280**, still restricted to owner/collaborators. Independently reopened
cloud source matches all **76** containers without probes. Stable version 2, local
backups and source history remain recoverable. No balance, maps, desktop bindings,
public access, products or assets changed. Original prototype untouched.

Real phone/tablet multitouch, live rejoin persistence, device performance and this
update's full multiplayer/map cycle remain unverified. See
[MOBILE_CONTROLS_UPDATE.md](../MOBILE_CONTROLS_UPDATE.md) for exact evidence,
configuration, screenshots, backups and checklist. Earlier sections below describe
historical stable builds and are retained for continuity.

## Owner live-client confirmation — 2026-10-21

Aaron opened the private experience on another computer and reported that he has
been testing it and it looks good. Basic normal-client launch/playability is now
owner-confirmed. Detailed live multiplayer, map-cycle and performance checks remain
outstanding; this does not change the automated Player verification limitations
recorded below. No further source, settings or publication changes were made.

## Published private test — 2026-10-21

Current source checkpoint: `a487de38a96261dbeac74e701e69ce31762123f9` on
`release/private-playtest`; previous verified checkpoint `137a9ebe` remains intact.
Published **privately** as Double Pump [Private Test], universe **10772275012**,
start place **82505574993280**, published version **2**. No public/friends release,
monetization, asset upload, merge or push. Server limit saved as 10; genre Shooter.

[Open owner playtest](https://www.roblox.com/games/82505574993280/Double-Pump).
See [private release report](../PRIVATE_RELEASE_REPORT.md) and
[manual guide](../PRIVATE_PLAYTEST_GUIDE.md) for verified scope and limitations.
All 124 automated tests pass; type analysis, Windows-aware StyLua, Selene source
lint and Rojo build pass. Studio solo/two-client checks confirm counter 1/1 after
respawn and camera direction dot 1.0 through team respawn and practice/match changes.
The downloaded cloud place matches all 72 tested script containers. Actual regular
Roblox Player gameplay remains unverified; owner manual launch is pending.
Original prototype untouched; all 52 original backup checksums match. Separate
verified/release places, source archives and Git bundles are retained in
`../verified-before-private-release-2026-10-21/` beside the isolated checkout.
The sections below are historical preparation/audit records, superseded by this
publication status where they say not published or repairs uncommitted.
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
# Project status

## Current local repairs — 2026-10-21

Authoritative base: PR #2 head `14848886bfec43bd5277564ffce89c938f46f629`, rechecked
unchanged. Isolated checkout: `complete-game-studio` under the verified backup
directory. Branch: `fix/studio-gameplay-blockers`; all repairs are uncommitted.

- Practice startup: the script's protected `FallenPartsDestroyHeight` assignment
  aborted MapService before range construction. The same -120 value now lives in
  `default.project.json`; MapService proceeds to build the range normally.
- Firing/switching: `WeaponController.active` was initialized false and never enabled.
  GameFlow now synchronizes it with the existing combat-input lifecycle.
- Team spawns: CharacterAdded pivot preceded Roblox's final character placement.
  CharacterService now prepares/places the character after LoadCharacterAsync returns,
  checks required parts/current character, and then emits Spawned.
- Validation: 123/123 tests, direct type analysis, Rojo build, source lint and format
  checks pass. Extended lint reports one unchanged unused-variable warning in
  `tests/validation.spec.luau:41`. After the window limit was cleared, Studio solo and
  two-client tests confirmed range/targets, real mouse firing/manual switching/reload,
  correct team initial/respawn placement and staged PvP damage/elimination. Controlled
  accepted alternating intervals were 0.550/0.783/0.484 s; single-gun control 1.116 s.
  Premature server request rejected; reload interruption preserved inserted shells.
  Warehouse, Rooftops and Dust Town loaded through ordinary round flow with correct
  team coordinates. Spawn-facing views sometimes show close walls; investigate
  camera orientation separately. Full arena navigation remains unverified.
- No timing, balance, map, asset or product changes. No commit/push/merge/publish.
  Original prototype untouched; all 52 original backup checksums still match.

See [STUDIO_PLAYTEST_REPORT.md](STUDIO_PLAYTEST_REPORT.md) and
[CHANGELOG.md](CHANGELOG.md) for evidence, changed files and remaining coverage.
The respawn pellet-counter mismatch (now Studio-confirmed: predicted 1 vs server 7),
missing assets, real-device/full-lobby testing and upload/typecheck-tool issues remain
open. Review the repairs and complete remaining Studio coverage before considering
integration or launch work.

## Historical Claude handoff audit

The following records the earlier audit; current results above supersede its
"never tested" statements and older commit/test counts.

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
