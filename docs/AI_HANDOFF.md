# AI handoff: Double Pump

For the next AI agent (Codex or other) taking over development. Self-contained: you
don't need the earlier Claude conversations. Written 2026-10-21 against commit
`534df2e`; updated below for local repairs based on PR head `14848886bfec43bd5277564ffce89c938f46f629`. Details: [PROJECT_STATUS.md](PROJECT_STATUS.md), [TESTING.md](TESTING.md),
[ASSET_UPLOAD_MANIFEST.md](ASSET_UPLOAD_MANIFEST.md), [ROADMAP.md](ROADMAP.md). Rules:
[../AGENTS.md](../AGENTS.md).

## What the game is

**Double Pump** is a Roblox 5v5 first-person team deathmatch. Every player carries two
identical pump shotguns with independent state; firing one, swapping and firing the
other beats waiting for the pump (the "double pump"). Three maps built from parts in code
(Warehouse, Dust Town, Rooftops) plus a practice range. Progression, a coin shop for
cosmetic skins, leaderboards, KBM/controller/touch. Owner: Aaron
(`aaronmginsburg-code`). Full rules and numbers: `GAME_DESIGN.md`.

## Where everything is

- Repo: <https://github.com/aaronmginsburg-code/double-pump> (public).
- **The game is on branch `claude/full-game-build-3jb3hx` (draft PR #2), not on `main`.**
  `main` only has the empty Rojo scaffold.
- **The shotgun 3D asset is on branch `claude/project-thread-lv25xu` (draft PR #1)**
  under `DoublePump/Weapons/PumpShotgun/` (Blender sources, FBX/GLB, textures, renders,
  build scripts). It is needed for the Studio import step.
- `claude/project-thread-19b8zl` is an older prototype. Ignore it except as reference;
  don't merge it.
- Nothing is published on Roblox. No asset, product, place or universe IDs exist yet.

## State in one paragraph

The complete game remains PR #2, with local, uncommitted repairs on
`fix/studio-gameplay-blockers` in the isolated `complete-game-studio` clone under the
backup directory. Initial solo/two-client Studio testing found three blockers; see
[STUDIO_PLAYTEST_REPORT.md](STUDIO_PLAYTEST_REPORT.md) for historical evidence and
the repair verification section. GameFlow now enables the existing weapon controller;
CharacterService initializes and places characters after LoadCharacterAsync finishes;
the intended -120 destroy height is serialized by Rojo instead of assigned by a
restricted runtime script. Weapon tuning, state rules, maps and damage are unchanged.
All 123 tests (120 original + three lifecycle regressions), direct type analysis,
formatting and source lint pass. Extended lint has one existing warning in
`tests/validation.spec.luau:41`. After the owner cleared the Studio window limit,
the corrected build passed solo range startup, real mouse firing/Q switching/R reload,
target damage, two-client team placement and respawn, and staged real-player damage.
A controlled controller probe measured server-accepted alternating intervals of
0.550/0.783/0.484 seconds versus a 1.116-second single-gun control interval. A raw
premature request was rejected with Cooldown. Reload cancellation preserved inserted
shells. This is local controlled evidence, not full human/latency/device validation.
Assets still use stand-ins; no upload or publish occurred.
Warehouse, Rooftops and Dust Town all loaded through normal match flow with correct
team marker positions. Warehouse/Rooftops respawns were measured. Some spawn views
face nearby walls; camera-facing order needs follow-up, not an assumed map defect.

Build for review: `build/DoublePump_STUDIO_BLOCKER_FIXES.rbxl`. No commit, push or
merge is authorized. Preserve the original prototype checkout and all original
backup files (52/52 backup hashes rechecked). Next: review the completed Studio
report and remaining coverage before any integration.
The separate respawn shot-counter mismatch is now Studio-reproduced: after six
pre-respawn shots, the next local prediction was 1 and the server broadcast was 7.
It remains unfixed; investigate hit-registration impact in a separately scoped fix.
Review [CHANGELOG.md](CHANGELOG.md) before continuing development.

## Onboarding procedure

```sh
git clone https://github.com/aaronmginsburg-code/double-pump.git
cd double-pump
git fetch origin claude/full-game-build-3jb3hx claude/project-thread-lv25xu
git checkout claude/full-game-build-3jb3hx      # or main, after PR #2 is merged
rokit install                                   # rojo 7.4.4, lune 0.11.0, selene 0.31.0, stylua 2.6.0, luau-lsp 1.70.1
curl -fsSLo ~/globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau

lune run tests/run.luau                         # expect: 120 passed, 0 failed
ROBLOX_DEFS=~/globalTypes.d.luau tools/typecheck.sh   # expect: no output
stylua --check src tests tools/*.luau           # expect: exit 0
selene src                                      # expect: 0 errors (first run downloads the API dump)
rojo build -o build/DoublePump.rbxl             # expect: builds
```

If any of these differ from the expected result, stop and report before changing code.
Then read, in order: `GAME_DESIGN.md`, `docs/PROJECT_STATUS.md`, `DEVELOPMENT_REPORT.md`,
`docs/ASSET_PIPELINE.md`, `src/server/init.server.luau` (service start order), and
`src/shared/Config/`.

## Environment

| Tool | Version | Use |
|---|---|---|
| Rokit | any recent | installs the tools below from `rokit.toml` |
| Rojo | 7.4.4 | `rojo serve` (live sync to Studio), `rojo build`, `rojo sourcemap` |
| Lune | 0.11.0 | unit tests, map tools |
| Selene | 0.31.0 | lint |
| StyLua | 2.6.0 | format |
| luau-lsp | 1.70.1 | strict type check (+ `globalTypes.d.luau`) |
| Python 3 | 3.11+ | `tools/upload_assets.py` (stdlib only) |
| numpy, scipy, soundfile | — | only to regenerate sounds (`tools/gen_audio.py`) |
| `bpy` (pip, Blender 5.x, Python 3.13) | — | only to re-render map art (`tools/render_maps.py`) or rebuild the shotgun (`PumpShotgun/scripts/run_all.sh`); Cycles CPU |
| Roblox Studio + Rojo plugin | current | everything in `TESTING.md` "Not yet executed"; Windows or macOS only |

Owner's machine: Windows, clone at `C:\Users\aaron\Documents\double-pump`. It is on the
old prototype branch `claude/project-thread-19b8zl` with **uncommitted prototype
changes that are not on GitHub and unrelated to PR #2** (backed up to
`C:\Users\aaron\Documents\double-pump-backups\2026-10-21-prototype-uncommitted\`; see
PROJECT_STATUS.md). Don't work in that folder and don't reset or clean it; use a fresh
clone for the real game. The
Oct 17 `setup-windows.bat` installed Rokit, Rojo, the Studio plugin and VS Code
extensions there. Nothing about the build environment is stored only in the old Claude
containers that can't be re-downloaded.

Studio integration: `rojo serve`, then Studio **Rojo > Connect** on a Baseplate.
`default.project.json` maps `src/shared` → ReplicatedStorage.Shared, `assets/roblox` →
ReplicatedStorage.Assets, `src/server` → ServerScriptService.Server, `src/client` →
StarterPlayerScripts.Client, `src/character/Health.server.luau` →
StarterCharacterScripts, and sets Workspace/Players/Lighting properties.

## Remaining tasks (in order)

1. **Owner:** review the uncommitted blocker repairs after Studio retesting. Do not
   commit or merge without approval. Subsequently decide whether to merge PR #2
   and how to keep the PR #1 asset (merge, LFS,
   or archive branch); decide repo visibility.
2. Add CI running the checks above (make the type check fail on errors).
3. Fix `tools/upload_assets.py` so it never writes a decal ID as an image ID (see
   PROJECT_STATUS.md known issue 1). Tooling only, not gameplay.
4. **Owner, Studio:** import the shotgun and commit the `.rbxm` files
   (`ASSET_PIPELINE.md` step 1).
5. **Owner approval:** upload 29 sounds + 3 map images (script with an Open Cloud key,
   or Studio Asset Manager); commit `AssetIds.luau`.
6. **Owner approval:** first private publish, enable Studio API access.
7. Playtest per `PLAYTEST.md`; fix bugs found; record results with date and commit.
8. **Owner:** confirm design drift items (shield, swap timing, movement, round length).
9. Release prep (icon, thumbnails, questionnaire). Robux packs and going public are
   owner decisions.

## What automation can and can't do

- **Can be automated (with an owner-created Open Cloud API key, Assets read/write):**
  audio and image uploads via `tools/upload_assets.py`. Never commit the key; pass it in
  `ROBLOX_API_KEY`.
- **Can't be automated from a headless agent:** the FBX import with bones and
  SurfaceAppearance (Studio 3D Importer), Studio playtests, first publish, Game Settings,
  developer products, the maturity questionnaire. These need the owner in Studio or the
  Creator Dashboard. Open Cloud can also publish places, but publishing needs explicit
  approval every time.

## Guardrails

- Don't change gameplay behaviour without the owner asking; tuning numbers live in
  `src/shared/Config/` and the owner decides them.
- Don't upload, publish, create products, change Roblox settings, spend Robux, force-push,
  rewrite history or delete branches without explicit approval.
- Don't rename the DataStore `DoublePump_Profiles_v1` (wipes progress). Change the save
  shape only with a version bump and migration in `src/shared/Progression/Profile.luau`.
- Keep `Products.Enabled = false` until the owner says otherwise.
- Never `rojo build -o "$TMPDIR/..."` when `$TMPDIR` might be empty.
- Record every new asset in `docs/ASSET_SOURCES.md`; nothing ripped from other games
  (the shotgun is an original design, deliberately not a copy of Epic's).
- Don't tick a `PLAYTEST.md` line you didn't observe; don't claim a test passed without
  output.
