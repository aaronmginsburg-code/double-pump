## Release transition — 2026-10-22

Implementation4505edef:245 automated tests and21/21 staged three-client Studio assertions pass; LSP/Selene/StyLua/Rojo clean.81scripts match saved Studio source. Published privately as version10; existing icon/five thumbnails preserved. No gameplay, balance, asset uploads or Public change. See RELEASE_RECORD.md for fresh evidence and unverified live/device boundaries. Earlier entries are historical.

## 2026-10-21 - Lobby queue addition

The physical queue uses only code-created Roblox parts, BillboardGui and text. No new mesh, image, sound, animation, external asset source or upload is required. Existing asset limitations remain unchanged. See `LOBBY_AND_MATCHMAKING_UPDATE.md`.

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

## Current mobile release note — 2026-10-21

Private version 5 reuses all existing models, animations and UI glyphs; no new
assets/IDs/uploads are required. Creator is supersnapstudios (11808586604), universe
10772275012, place 82505574993280. The historical inventory below predates the first
private publication. Existing missing/moderated audio warnings remain; observed
Practice/combat was usable. See ../MOBILE_CONTROLS_UPDATE.md for current evidence.

# Asset upload manifest

Everything that still has to be uploaded to Roblox, or configured on Roblox, before
Double Pump can ship. Audited 2026-10-21 against commit `534df2e` on branch
`claude/full-game-build-3jb3hx` (draft PR #2). **Nothing on this list has been uploaded
or configured yet.** No Roblox asset ID exists anywhere in the repo
(`src/shared/Config/AssetIds.luau` is all empty strings, `assets/roblox/` has no `.rbxm`
files, `src/shared/Config/Products.luau` has no product IDs).

Step-by-step instructions for each upload are in [ASSET_PIPELINE.md](ASSET_PIPELINE.md);
licensing is in [ASSET_SOURCES.md](ASSET_SOURCES.md). This file is the checklist.

## Who owns the uploads

- **Creator account / group:** not recorded. The only known account is the project
  owner's personal Roblox account (Aaron). No group has been mentioned. The Roblox user ID
  is not written down anywhere in the repo.
- **Rule:** every asset must be owned by the same user or group that will own the
  published experience. Audio and meshes owned by a different creator won't load (audio)
  or need explicit permission grants. Decide the owner **before** the first upload; moving
  assets between owners later means re-uploading.
- **Who may upload:** only the owner, after explicit approval. Codex must not upload,
  create API keys, create products or publish without that approval (see `AGENTS.md`).

## Where the source files are

The shotgun files are **not** on the PR #2 branch. They exist in two places:

1. GitHub branch `claude/project-thread-lv25xu` (draft PR #1), under
   `DoublePump/Weapons/PumpShotgun/`. Verified 2026-10-21: every file in the project
   folder below is on that branch; non-image files are byte-identical and every PNG is
   pixel-identical (only PNG metadata/compression differs).
2. The Claude project folder `/mnt/project-files/DoublePump/Weapons/PumpShotgun/`
   (Claude-only shared storage, not reachable by Codex).

Codex should take them from the PR #1 branch:

```sh
git fetch origin claude/project-thread-lv25xu
git checkout origin/claude/project-thread-lv25xu -- DoublePump/Weapons/PumpShotgun/exports DoublePump/Weapons/PumpShotgun/textures
# (or `git worktree add ../pumpshotgun origin/claude/project-thread-lv25xu` to avoid touching the working tree)
```

Below, `PS/` means `DoublePump/Weapons/PumpShotgun/` on that branch.

## Required for release

### 1. Shotgun models (Studio 3D Importer, needs Studio on Windows/Mac)

| File | Path | Exists | Asset type | Purpose | Destination | Asset ID handling |
|---|---|---|---|---|---|---|
| `PumpShotgun_FP.fbx` | `PS/exports/first_person/` | yes (19.1 MB) | Mesh (skinned, 13 bones) + 2 shell meshes | First-person viewmodel for both gun slots | Import 3D → Model named `PumpShotgun_FP` → **Save to File** `assets/roblox/Weapons/PumpShotgun_FP.rbxm` | Mesh IDs are created by the importer and stored inside the `.rbxm`; no code edit. Code finds it by name (`ReplicatedStorage.Assets.Weapons.PumpShotgun_FP`, `src/shared/Weapons/ShotgunModel.luau`). |
| `PumpShotgun_TP.fbx` | `PS/exports/third_person/` | yes (3.8 MB) | Mesh (skinned, 7 bones) | Third-person world model other players see | Model `PumpShotgun_TP` → `assets/roblox/Weapons/PumpShotgun_TP.rbxm` | Same as above. |
| `Shell_Spent.fbx` | `PS/exports/props/` | yes (45 KB) | Mesh (static) | Ejected shell physics prop | MeshPart `Shell_Spent` → `assets/roblox/Props/Shell_Spent.rbxm` | Same; looked up in `EffectsController.luau` as `Assets.Props.Shell_Spent`. |

Special requirements: Studio signed in as the owning account; importer Rig Type
**Custom**, Scale Unit **Meter**; keep meshes un-merged. Original asset (made in Blender
for this project). Until imported, the game runs a parts stand-in flagged with the
`StandIn` attribute and prints "Shotgun asset not found".

### 2. Shotgun textures (uploaded by Studio when set on a SurfaceAppearance)

| File | Path | Exists | Type | Used on | Asset ID handling |
|---|---|---|---|---|---|
| `T_PumpShotgun_BaseColor.png` | `PS/textures/roblox_1024/` | yes | Image (1024²) | `FP_PumpShotgun` + FP shell meshes, `SurfaceAppearance.ColorMap` | Stored in the `.rbxm` |
| `T_PumpShotgun_Normal.png` | same | yes | Image | `NormalMap` | Stored in the `.rbxm` |
| `T_PumpShotgun_Roughness.png` | same | yes | Image | `RoughnessMap` | Stored in the `.rbxm` |
| `T_PumpShotgun_Metalness.png` | same | yes | Image | `MetalnessMap` | Stored in the `.rbxm` |
| `T_PumpShotgun_TP_BaseColor.png` | `PS/textures/third_person/` | yes | Image (1024²) | `TP_PumpShotgun` `ColorMap` | Stored in the `.rbxm` |
| `T_PumpShotgun_TP_Normal.png` | same | yes | Image | `NormalMap` | Stored in the `.rbxm` |
| `T_PumpShotgun_TP_Roughness.png` | same | yes | Image | `RoughnessMap` | Stored in the `.rbxm` |
| `T_PumpShotgun_TP_Metalness.png` | same | yes | Image | `MetalnessMap` | Stored in the `.rbxm` |

The 2048² set in `PS/textures/first_person/` is source quality, not for upload (Roblox
caps SurfaceAppearance at 1024²). Skins tint the SurfaceAppearance in code
(`ShotgunModel.applySkin`), so no per-skin textures exist or are needed.

### 3. Sounds (29 files, Audio assets)

All in `assets/audio/` on the PR #2 branch, all exist (840 KB total), all original
(synthesised by `tools/gen_audio.py`). Each ID goes into
`src/shared/Config/AssetIds.luau` → `AssetIds.Sounds.<Name>` (key = filename without
`.ogg`). `tools/upload_assets.py` writes these automatically.

| Key / file | Purpose |
|---|---|
| `Fire` | Shotgun shot |
| `Pump` | Pump cycle |
| `Equip` | Raise gun on spawn |
| `Swap` | Swap to other gun |
| `ShellInsert` | One shell loaded |
| `ReloadStart` | Reload begins |
| `EmptyClick` | Fire on empty |
| `ShellBounce` | Ejected shell hits floor |
| `HitBody` / `HitHead` | Hitmarker sounds |
| `Elimination` / `DoublePumpElim` | Kill confirm / double-pump kill callout |
| `DamageTaken` / `Death` / `Spawn` | Player feedback |
| `CountdownTick` / `MatchStart` / `MatchEnd` / `Victory` / `Defeat` | Match flow |
| `UIClick` / `UIHover` / `Vote` / `Reward` / `LevelUp` | UI |
| `AmbWarehouse` / `AmbDustTown` / `AmbRooftops` | Map ambience loops |
| `MusicMenu` | Menu music loop |

Special requirements: audio is moderated after upload (may be pending for minutes);
Roblox applies monthly audio-upload quotas per account (higher for ID-verified
accounts), so 29 uploads may hit an unverified account's limit; check the current quota
in Creator Dashboard before starting. Audio is private to its owner, so it must be owned
by the experience owner or explicitly shared with the experience. Fallback until
uploaded: built-in `rbxasset://sounds/...` for HitBody, HitHead, UIClick, Swap, Equip,
Death; silence for the rest.

### 4. Map vote-card images (3 files, Image assets)

| File | Path | Exists | Insert ID at | Purpose |
|---|---|---|---|---|
| `Warehouse.png` | `assets/ui/maps/` | yes | `AssetIds.Images.MapWarehouse` | Map vote card |
| `DustTown.png` | `assets/ui/maps/` | yes | `AssetIds.Images.MapDustTown` | Map vote card |
| `Rooftops.png` | `assets/ui/maps/` | yes | `AssetIds.Images.MapRooftops` | Map vote card |

Original (Blender renders of the in-code map geometry). The value must be the **image**
ID, not the decal ID. `tools/upload_assets.py` uploads these as Decals and then tries to
resolve the image ID through `assetdelivery.roblox.com`; if that lookup fails it
**still writes the decal ID** into `AssetIds.luau` and only prints a warning (see
Known issues in `PROJECT_STATUS.md`). Check these three values by hand after any scripted
upload. Fallback until uploaded: plain coloured vote cards.

### 5. Roblox configuration (no file, but required)

| Item | Where | Needed for | Status |
|---|---|---|---|
| Create the experience (first publish, **private**) | Studio > File > Publish to Roblox | DataStores in Studio, any real-server test | Not done; requires owner approval |
| Enable Studio Access to API Services | Game Settings > Security | Saving, leaderboards, shop balance in Studio | Not done |
| Max players 10, Avatar R15 | Game Settings | 5v5 | Not done |
| Experience Questionnaire (maturity) | Creator Dashboard > Audience | Going public | Not done |
| Open Cloud API key with Assets read/write | create.roblox.com/dashboard/credentials | Only for `tools/upload_assets.py` | Not created; secret, never commit it |

## Optional

### Robux coin packs (off by design)

`src/shared/Config/Products.luau`: `Products.Enabled = false`, three packs with
`productId = nil` (`Coins500`, `Coins1200`, `Coins3000`). To enable: create three
Developer Products in Creator Dashboard, paste each numeric ID into its `productId`,
set `Enabled = true`. This involves real money: **owner decision only.**

### Promotional material (not needed for the game to run)

| Item | Exists | Notes |
|---|---|---|
| Experience icon 512×512 | **no** | Nothing made yet |
| Thumbnails | partly | `docs/images/maps/*_overview.png` are Blender renders, not gameplay; take real screenshots once the shotgun is imported |
| `AssetIds.Images.Logo` | **no file** | Slot exists, empty; no logo art |
| Description text | no | `GAME_DESIGN.md` has material for it |
| Shotgun presentation renders | yes | `PS/renders/` on PR #1 branch; useful for marketing |

## Not needed (exists but doesn't get uploaded)

- **Animations.** The Blender actions are baked into
  `src/shared/Weapons/ShotgunAnimData.luau` by `tools/extract_anims.py` and played from
  code, so no Animation asset upload. `PS/exports/animations/*.fbx` are reference only.
- `PS/exports/props/Shell_Live.fbx`: the live shell is a mesh inside the FP model; no code
  references a separate Shell_Live prop.
- `PS/exports/*/*.glb`, `PS/blender/*.blend`, `PS/renders/`, `PS/textures/first_person/`:
  source and QA material.
- `docs/images/maps/*`: documentation images.
- Fonts and the HUD vignette are built-in `rbxasset://` content.

## Mobile controls candidate — 2026-10-21

The mobile update adds only locally drawn UI glyphs and reuses existing shotgun
models/animations. It requires no new uploaded images, meshes, audio or asset IDs.
No assets were uploaded or replaced. Existing missing cosmetic assets remain as
recorded above. See ../MOBILE_CONTROLS_UPDATE.md for validation status.