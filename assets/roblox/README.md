Save the imported shotgun models here as .rbxm files (see docs/ASSET_PIPELINE.md):

- Weapons/PumpShotgun_FP.rbxm  (first-person viewmodel, imported from PumpShotgun_FP.fbx)
- Weapons/PumpShotgun_TP.rbxm  (third-person world model, imported from PumpShotgun_TP.fbx)
- Props/Shell_Spent.rbxm       (MeshPart from props/Shell_Spent.fbx)

Rojo syncs this folder into ReplicatedStorage.Assets. Until these files exist the game
uses a labelled stand-in model built from parts.
