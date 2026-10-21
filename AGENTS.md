# Agent instructions (Codex and other AI agents)

Double Pump is a Roblox game in a Rojo project. Start with
[docs/AI_HANDOFF.md](docs/AI_HANDOFF.md); current state is in
[docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md).

## Before you change anything

1. **Inspect the actual source.** Docs and notes can be stale. Read the files you'll
   touch, `src/server/init.server.luau` and `src/shared/Config/` first. If a doc
   disagrees with the code, the code is the fact; fix the doc and say so.
2. Check which branch you're on. Until PR #2 is merged, the game lives on
   `claude/full-game-build-3jb3hx`, not `main`.
3. Run the checks and confirm they match `docs/TESTING.md` before you start:

   ```sh
   lune run tests/run.luau
   tools/typecheck.sh            # needs ROBLOX_DEFS or ~/tools/globalTypes.d.luau; no output = clean
   stylua --check src tests tools/*.luau
   selene src
   rojo build -o build/DoublePump.rbxl
   ```

## While working

- **Preserve existing gameplay.** Don't change rules, timings, damage, rewards or prices
  unless the owner asked for that change. Tuning numbers live in `src/shared/Config/`
  and `src/shared/Progression/`.
- Match the existing style: `--!strict` Luau, tabs, StyLua formatting, services with a
  `start()` function in `src/server/Services/`, UI built in code.
- Add or update Lune tests in `tests/` for logic you change.
- Never rename the DataStore `DoublePump_Profiles_v1`; bump the profile version and add
  a migration in `src/shared/Progression/Profile.luau` for save-shape changes.
- Never write to `$TMPDIR` paths with `rojo build` (an empty `$TMPDIR` resolves to `/`).

## After working

- Run every check above; all must pass. Report real output, never assumed results.
- **Update the docs** your change affects: `docs/PROJECT_STATUS.md`, `docs/TESTING.md`
  (with the date and commit of the run), `docs/ASSET_UPLOAD_MANIFEST.md`,
  `docs/ROADMAP.md`, `GAME_DESIGN.md`, `docs/ASSET_SOURCES.md` for new assets.
- Don't tick `docs/PLAYTEST.md` lines you didn't observe in Roblox.

## Requires the owner's explicit approval every time

- Publishing or updating the game on Roblox, or changing any Roblox/Creator Dashboard
  setting.
- Uploading any asset, creating API keys, creating developer products, enabling
  `Products.Enabled`, or anything that spends or earns Robux.
- Merging PRs, force-pushing, rewriting history, deleting branches (especially
  `claude/project-thread-lv25xu`, which holds the shotgun asset).
- Changing repository visibility.

Never commit secrets (Open Cloud API keys go in `ROBLOX_API_KEY`, never in a file).
