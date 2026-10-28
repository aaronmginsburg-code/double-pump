> **Public release v13 — 2026-10-28.** The owner-approved saved **Mobile** preset (schema 2, revision 3) is now the static public-source configuration. Version13 is published; read [PRODUCTION_MOBILE_PROMOTION.md](PRODUCTION_MOBILE_PROMOTION.md) for current evidence and final deployment outcome. Root `src/` is the public build; `development-copy/source/` remains the separate private development build. Older entries below describe historical checkpoints.

# Asset pipeline: getting the shotgun, sounds and map art into Roblox

The code runs without any of these steps. Until they're done the game uses:

- a labelled parts stand-in for the shotgun (the model gets a `StandIn` attribute and the
  output prints one warning),
- a few built-in Roblox sounds for hits, swaps and UI clicks, and silence for the rest,
- plain coloured vote cards instead of the map renders.

None of these are meant to ship. Do the three steps below before publishing.

## 1. Import the pump shotgun (Studio, about 15 minutes)

Source files are on the GitHub branch `claude/project-thread-lv25xu` (draft PR #1;
`git fetch origin claude/project-thread-lv25xu`) and in the Claude project folder,
both under `DoublePump/Weapons/PumpShotgun/exports/`
(`first_person/PumpShotgun_FP.fbx`, `third_person/PumpShotgun_TP.fbx`,
`props/Shell_Spent.fbx`) with textures in `textures/roblox_1024/` (first person) and
`textures/third_person/`.

1. Open the place in Studio and connect Rojo (`rojo serve`, then **Rojo > Connect**).
2. **Avatar** tab (or **Home**) > **Import 3D**. Pick `PumpShotgun_FP.fbx`.
3. In the import window (option names as of Studio's current 3D Importer; if a name
   differs slightly, look for the same setting):
   - **Rig General > Rig Type**: **Custom**, so the 13 bones come through as `Bone`
     instances.
   - **File General > Scale Unit**: **Meter** (the gun is 1.035 m long, about 3.7 studs).
   - Leave meshes un-merged so the shell meshes stay separate parts.
   - Click **Import**.
4. The result is a Model. Rename it exactly **`PumpShotgun_FP`**.
5. Select the `FP_PumpShotgun` MeshPart inside it and add a **SurfaceAppearance**. Set its
   four maps from `textures/roblox_1024/`:
   `ColorMap` = `T_PumpShotgun_BaseColor.png`, `NormalMap` = `..._Normal.png`,
   `RoughnessMap` = `..._Roughness.png`, `MetalnessMap` = `..._Metalness.png`.
   (Studio uploads each image when you pick it.) Do the same for the two shell meshes.
6. Repeat steps 2 to 5 for `PumpShotgun_TP.fbx` (rename to **`PumpShotgun_TP`**, use the
   `textures/third_person/` set) and `Shell_Spent.fbx` (rename the MeshPart to
   **`Shell_Spent`**; it needs no bones, so Rig Type *No Rig* is fine).
7. Save each one into the repo so Rojo keeps it:
   right-click the model > **Save to File...** and save as
   - `assets/roblox/Weapons/PumpShotgun_FP.rbxm`
   - `assets/roblox/Weapons/PumpShotgun_TP.rbxm`
   - `assets/roblox/Props/Shell_Spent.rbxm`
8. Delete the copies from Workspace. Rojo now syncs them into
   `ReplicatedStorage.Assets.Weapons` and `.Props`.
9. Press **Play**. The output should **not** print "Shotgun asset not found", and the gun
   should look like the Blender renders. Fire, pump, swap and reload once each and check the
   pump slides back and the spent shell ejects.

If the gun appears rotated or offset, check the Scale Unit was Meter and that the bones
are named as in `README.md` of the asset folder (`ViewmodelRoot`, `Weapon`, `Pump`, ...).
The code finds bones by name.

## 2. Upload the sounds and map art

There are 29 sounds in `assets/audio/` and three vote-card images in `assets/ui/maps/`.
Their IDs go in `src/shared/Config/AssetIds.luau`. Either way below works.

### Option A: the upload script (fast, needs an API key)

1. Go to <https://create.roblox.com/dashboard/credentials> > **Create API Key**.
2. Name it "Double Pump assets". Under **Access Permissions** add **Assets API** with
   **Read** and **Write**. Under **Security** add your IP (or `0.0.0.0/0` for a short time).
   Pick an expiry. **Save & Generate Key** and copy it (you only see it once).
3. Find your user ID: it's the number in your profile URL on roblox.com.
4. In a terminal in the repo folder:

   ```powershell
   $env:ROBLOX_API_KEY = "paste-key-here"
   python tools/upload_assets.py --user-id 123456789 --dry-run   # shows what will upload
   python tools/upload_assets.py --user-id 123456789
   ```

   For a group-owned game use `--group-id` instead (the key must belong to the group).
5. The script writes each new ID into `AssetIds.luau`. Commit that file.
6. Audio needs moderation before it plays. New uploads may show as pending for a few
   minutes; if a sound stays silent, check it in **Creator Dashboard > Development Items >
   Audio**.

The script was written from Roblox's Open Cloud documentation but hasn't been run against
the live API yet (there was no key in the build environment). If it fails, it prints
Roblox's error, keeps going, and skips finished files when you re-run it. Option B always
works.

### Option B: Studio's Asset Manager (no key)

1. **View > Asset Manager > Bulk Import**. Select every `.ogg` in `assets/audio/`, then
   the three PNGs in `assets/ui/maps/`.
2. For each item: right-click > **Copy Asset ID**, and paste the number into the matching
   entry in `AssetIds.luau` (the file names match the keys: `Fire.ogg` goes in
   `Sounds.Fire`, `Warehouse.png` goes in `Images.MapWarehouse`).
3. Images imported this way are already image IDs. If you upload a PNG as a **Decal** on
   the website instead, insert the decal in Studio and copy the `Texture` ID from it,
   because an ImageLabel needs the image ID, not the decal ID.

Uploaded audio is private to your account by default, which is fine as long as the game
is owned by the same account (or group) that owns the audio.

## 3. Enable DataStores in Studio

Saving, leaderboards and the shop's coin balance use DataStores. In Studio they only work
after the place is published once and API access is on:

1. **File > Publish to Roblox** (keep it private for now; see `PUBLISHING.md`).
2. **Home > Game Settings > Security > Enable Studio Access to API Services**: on. Save.

Without this the game still runs: it keeps progress in memory for the session and shows
"Progress won't save in this session" once.

## Regenerating assets

- Sounds: `python tools/gen_audio.py` (needs numpy, scipy, soundfile). Re-upload changed
  files with `upload_assets.py --only Name --force`.
- Map art: `lune run tools/export_map.luau Warehouse build/maps/Warehouse.json` for each
  map, then `python tools/render_maps.py build/maps assets/ui/maps docs/images/maps`
  (needs the `bpy` module; `SAMPLES=16` for quick previews).
- Shotgun animations: `tools/extract_anims.py` bakes the Blender actions into
  `src/shared/Weapons/ShotgunAnimData.luau`.

Record any new asset in `docs/ASSET_SOURCES.md`.
