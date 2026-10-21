# Double Pump

A 5v5 first-person Roblox shooter built around the double pump: everyone carries two pump
shotguns, and swapping to the other gun is faster than pumping the one you just fired.
Team deathmatch on three maps, with progression, a cosmetic shop and keyboard,
controller and touch controls.

- [GAME_DESIGN.md](GAME_DESIGN.md): how the game plays and every rule and number.
- [DEVELOPMENT_REPORT.md](DEVELOPMENT_REPORT.md): what's built, what's been checked, what
  hasn't, and known limitations.
- [docs/ASSET_PIPELINE.md](docs/ASSET_PIPELINE.md): importing the shotgun, uploading
  sounds and map art, enabling saves in Studio.
- [docs/PUBLISHING.md](docs/PUBLISHING.md): publishing and (optional) Robux coin packs.
- [docs/PLAYTEST.md](docs/PLAYTEST.md): playtest checklist and report.
- [docs/ASSET_SOURCES.md](docs/ASSET_SOURCES.md): where every asset came from.

## Setup

1. On Windows, double-click `setup-windows.bat` to install everything below in one go.
   Otherwise install [Rokit](https://github.com/rojo-rbx/rokit) and run `rokit install` in
   this folder. That installs Rojo plus the check tools (Lune, Selene, StyLua, luau-lsp).
2. Run `rojo plugin install` to add the Rojo plugin to Roblox Studio.
3. Open this folder in VS Code and install the recommended extensions (Rojo, Luau
   Language Server).

## Run it

1. `rojo serve` in this folder.
2. Open a Baseplate in Studio, click **Rojo > Connect**. Saved code syncs into Studio live.
3. **Play** puts you alone in the practice range. For a real match use
   **Test > Clients and Servers** with 2 or more players.
4. Press **F2** in game for the debug overlay.

The first time, follow [docs/ASSET_PIPELINE.md](docs/ASSET_PIPELINE.md) to import the
shotgun model and upload the sounds; until then the game runs with a labelled stand-in gun
and mostly silent audio.

To get a place file without Studio syncing: `rojo build -o build/DoublePump.rbxl`.

## Change it

| To change | Edit |
|---|---|
| Gun timing, damage, spread | `src/shared/Config/WeaponConfig.luau` |
| Match length, score, respawn, movement, camera | `src/shared/Config/GameConfig.luau` |
| XP, coins, levels, mastery | `src/shared/Progression/Levels.luau` |
| Challenges | `src/shared/Progression/Challenges.luau` |
| Skins and prices | `src/shared/Progression/Cosmetics.luau` |
| Maps | `src/server/Maps/*.luau` (re-run the tests after) |
| Sounds | `tools/gen_audio.py`, then re-upload |

## Layout

| Folder | Ends up in | Holds |
| --- | --- | --- |
| `src/shared` | ReplicatedStorage.Shared | Config, weapon rules, progression rules, networking |
| `src/server` | ServerScriptService.Server | Services (combat, match, data, shop...), maps, save data |
| `src/client` | StarterPlayerScripts.Client | Input, camera, viewmodel, effects, audio, all UI |
| `src/character` | StarterCharacterScripts | Replaces the default health regen |
| `assets/roblox` | ReplicatedStorage.Assets | Imported shotgun models (`.rbxm`) |
| `assets/audio`, `assets/ui` | (uploaded, not synced) | Original sounds and map art |
| `tests` | (not synced) | Lune tests |
| `tools` | (not synced) | Map report and renders, audio generator, asset uploader |

## Checks

Run these before committing; they all pass on the current branch.

```sh
lune run tests/run.luau          # 120 tests: weapon rules, damage, match, progression, saves, maps
selene src                       # lint
stylua src tests tools/*.luau    # format
tools/typecheck.sh               # strict types (bash; needs the Roblox type definitions)
lune run tools/map_report.luau   # map sightline and symmetry numbers
```

`tools/typecheck.sh` expects the Roblox definitions file at
`~/tools/globalTypes.d.luau` (or set `ROBLOX_DEFS`). Download `globalTypes.d.luau` from
the [luau-lsp repository](https://github.com/JohnnyMorganz/luau-lsp) (`scripts/` folder).

## Publishing

Not published, and Robux sales are off. See [docs/PUBLISHING.md](docs/PUBLISHING.md);
both are your decision.
