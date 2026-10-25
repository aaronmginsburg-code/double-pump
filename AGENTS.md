# Agent instructions (Codex and other AI agents)

Double Pump is a Roblox game in a Rojo project. Start with
[docs/AI_HANDOFF.md](docs/AI_HANDOFF.md); current state is in
[docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md).

## Before you change anything

1. **Inspect the actual source.** Docs and notes can be stale. Read the files you'll
   touch, `src/server/init.server.luau` and `src/shared/Config/` first. If a doc
   disagrees with the code, the code is the fact; fix the doc and say so.
2. Verify branch, HEAD and dirty state. Current implementation is on
   `feat/mobile-controls` (checkpoint4505edef), not scaffold `main` or older PR#2.
   Read docs/RELEASE_RECORD.md; preserve later work.
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

## Private development aim assist (2026-10-24)

The private source is `development-copy/source` on `feat/development-aim-assist`. Read `docs/AIM_ASSIST_TEST_REPORT.md` for the current release checkpoint. Developer tuning is restricted to universe10772492892/place139437092998076 and allowlisted UserIds. Production universe10772275012/place82505574993280 must never receive this development console or all-skin overrides.

Keep the intact latest cloud place as the full-scene deployment base (feedback board geometry is not wholly in Rojo). Patch source, remove disposable test probes, compare all118 permanent sources, archive the intact candidate, then publish only after checking both IDs. Never publish INSPECTION_ONLY normalized files. The source-only Rojo build is a verification artifact. Run private tests with `lune run run-compat.luau` from `development-copy/source` when using the bundled Lune0.8.9 runner. Saved-only Studio drafts are not published versions.


## Private training bots (2026-10-24)

Current development branch is `feat/development-training-bots`; see docs/TRAINING_BOTS_UPDATE.md. The full-scene candidate contains123 permanent scripts. Exact DeveloperAccess IDs plus UserId allowlist are mandatory. NPC records are server-registered participants, never fake Players. Preserve physical FIFO/root-center queue admission, training-round progression suppression and ordinary nonlethal human lobby combat. Never copy development bot services or intentional1v2 team rules into production without separate approval. Remove every TemporaryBot probe and runtime-only negative Studio UserId grant before publishing; compare all123 sources with the archived candidate.

## Developer console candidate (2026-10-25)

Read docs/DEVELOPER_CONSOLE_TEST_REPORT.md and DEVELOPER_CONSOLE_PUBLISH_REPORT.md. Private candidate has131 permanent sources. Shared.DeveloperConsole Registry/Config/Runtime/ProfileStore extend the existing service. Schema2 presets use DoublePump_DevConsole_v2/u10772492892, never production profiles. Preserve legacy aim reads. Safe-boundary weapon revisions must not refill ammunition or reset action deadlines. Public src stays unchanged. Owner requires actual desktop/mobile screenshot approval BEFORE commit or publication. Remove temporary probes/grants and compare every131 source before deployment.
