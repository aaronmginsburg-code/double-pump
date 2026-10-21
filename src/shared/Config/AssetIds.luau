--!strict
-- Roblox asset ids for uploaded content. Fill these in after uploading (see
-- docs/ASSET_PIPELINE.md, or run tools/upload_assets.py which rewrites this file).
-- An empty string means "not uploaded yet": the game falls back to a built-in sound or
-- stays silent for that effect, and prints one warning listing what is missing.

local AssetIds = {}

-- Original sounds synthesised by tools/gen_audio.py (files in assets/audio/).
AssetIds.Sounds = {
	Fire = "",
	Pump = "",
	Equip = "",
	Swap = "",
	ShellInsert = "",
	ReloadStart = "",
	EmptyClick = "",
	ShellBounce = "",
	HitBody = "",
	HitHead = "",
	Elimination = "",
	DoublePumpElim = "",
	DamageTaken = "",
	Death = "",
	Spawn = "",
	CountdownTick = "",
	MatchStart = "",
	MatchEnd = "",
	Victory = "",
	Defeat = "",
	UIClick = "",
	UIHover = "",
	Vote = "",
	Reward = "",
	LevelUp = "",
	AmbWarehouse = "",
	AmbDustTown = "",
	AmbRooftops = "",
	MusicMenu = "",
}

-- Map vote card art (assets/ui/maps/*.png, rendered from the map geometry).
AssetIds.Images = {
	MapWarehouse = "",
	MapDustTown = "",
	MapRooftops = "",
	Logo = "",
}

return AssetIds
