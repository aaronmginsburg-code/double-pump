## Release transition â€” 2026-10-22

Implementation4505edef:245 automated tests and21/21 staged three-client Studio assertions pass; LSP/Selene/StyLua/Rojo clean.81scripts match saved Studio source. Published privately as version10; existing icon/five thumbnails preserved. No gameplay, balance, asset uploads or Public change. See RELEASE_RECORD.md for fresh evidence and unverified live/device boundaries. Earlier entries are historical.

## 2026-10-21 - Lobby queue addition

The physical queue uses only code-created Roblox parts, BillboardGui and text. No new mesh, image, sound, animation, external asset source or upload is required. Existing asset limitations remain unchanged. See `LOBBY_AND_MATCHMAKING_UPDATE.md`.

## Marketing asset delivery — 2026-10-21

Owner reports the latest mobile camera/independent-hand revision works properly.
Created marketing-only assets: three icon concepts, six thumbnail concepts, one
refined 512-square icon and three refined 1920x1080 thumbnails, with Studio captures,
editable SVG typography, generated masters and source prompts. Files are under
marketing/. No gameplay code, combat settings, maps, cloud version, access or
monetization was changed; no promotional art was uploaded. 197 tests pass and all
78 local scripts still match the previously verified candidate. See
[marketing report](../marketing/MARKETING_ASSET_REPORT.md) for provenance, capture
limitations, final files and upload instructions. Earlier sections are historical.

# Asset sources and licensing record

Every asset in Double Pump, where it came from, and what you may do with it. Nothing in
the game was copied or extracted from Fortnite, Arsenal or any other game.

## Made for this project

All of these were created for Double Pump in this project and belong to the project
owner.

| Asset | Where it lives | How it was made |
|---|---|---|
| Pump shotgun model (first- and third-person), PBR textures, rig | `/mnt/project-files/DoublePump/Weapons/PumpShotgun/` (exports), imported to `assets/roblox/` | Modelled and textured in Blender for this project. It's an original design in the spirit of a classic pump shotgun, not a copy of any game's weapon. See that folder's `README.md` and `references/REFERENCES.md`. |
| Shotgun animations (fire, pump, equip, reload, third-person) | `src/shared/Weapons/ShotgunAnimData.luau` | Keyframed in the same Blender file, then baked to data by `tools/extract_anims.py`. They play from code, so nothing needs uploading. |
| All 29 sound effects, ambiences and the menu music loop | `assets/audio/*.ogg` | Synthesised from noise, oscillators and envelopes by `tools/gen_audio.py` (numpy/scipy). No samples or sound libraries were used. |
| Maps: Warehouse, Dust Town, Rooftops, Practice Range | `src/server/Maps/*.luau` | Built from parts in code with `MapKit`. "PUMP-O COLA", "DPX" containers and every other sign or brand is made up. |
| Map preview art (vote cards, overviews) | `assets/ui/maps/*.png`, `docs/images/maps/*.png` | Offline Blender (Cycles) renders of the exact map geometry (`tools/export_map.luau` then `tools/render_maps.py`). These are renders, not in-game screenshots. |
| UI layout, HUD, icons drawn with frames | `src/client/UI/` | Built in code. No image assets apart from the engine textures listed below. |
| Skins (colour schemes) | `src/shared/Progression/Cosmetics.luau` | Colour palettes defined in code. |

## Supplied by Roblox

These come with the Roblox engine and may be used in any Roblox experience.

| Asset | Used for |
|---|---|
| Fonts `LuckiestGuy`, `GothamSSm`, `RobotoMono` (`rbxasset://fonts/...`) | UI text |
| `rbxasset://textures/ui/TopBar/WhiteOverlay.png` | Low-health vignette in the HUD |
| `rbxasset://sounds/electronicpingshort.wav`, `clickfast.wav`, `swoosh.wav`, `uuhhh.mp3` | Stand-in sounds, only until the original sounds are uploaded (see `docs/ASSET_PIPELINE.md`) |
| Default character rig, thumbstick and jump button | Characters and mobile movement |

## Tools used (not shipped)

Blender and its Python module `bpy` (GPL; the GPL doesn't cover images or models you
make with it), numpy, scipy and soundfile (BSD), Rojo, Lune, Selene, StyLua and luau-lsp
(MPL/MIT). None of their code ends up in the game.

## When you add assets

Add a row here for every new asset: what it is, where it lives, who made it and under
what licence. Don't add anything ripped from another game, and keep marketplace items
to ones whose licence allows use in your experience.
