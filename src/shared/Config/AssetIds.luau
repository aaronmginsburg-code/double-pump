--!strict
-- Roblox asset ids for uploaded content. Fill these in after uploading (see
-- docs/ASSET_PIPELINE.md, or run tools/upload_assets.py which rewrites this file).
-- An empty string means "not uploaded yet": the game falls back to a built-in sound or
-- stays silent for that effect, and prints one warning listing what is missing.

local AssetIds = {}

-- Fifty-one owner-selected ElevenLabs cues promoted to public version13.
-- AudioReferences retains concrete dependencies for experience permission checks.
AssetIds.Sounds = {
	StepConcrete = "127480360069744",
	StepMetal = "87968940009629",
	StepSand = "96114396174087",
	StepWood = "118025107093825",
	Landing = "119227276951004",

	RangeAir = "107314588536789",
	Assist = "72366323452361",
	Unlock = "132043275280472",
	Confirm = "119959350292311",
	Error = "133238281799902",
	TimeWarning = "107321103973404",
	Overtime = "131993078530333",
	ImpactWood = "125794832817300",
	ImpactMetal = "82455709298224",
	ImpactHard = "128202319714882",
	ReloadEnd = "91588700050239",
	MasteryMilestone = "85511675749835",
	ReturnToRange = "111267390132943",
	Admitted = "73939245280780",
	QueueCancel = "90412393185987",
	QueueCountdown = "136743664945691",
	QueueLeave = "124530677310844",
	QueueJoin = "109535765491493",
	Fire = "76270373964419",
	Pump = "", -- Legacy full-cycle cue unused by the split marker presentation.
	PumpBack = "110029776273911",
	PumpForward = "82334124029040",
	Equip = "76066705752904",
	Swap = "120708988258180",
	ShellInsert = "102336135537532",
	ReloadStart = "95926422694750",
	EmptyClick = "129023358510589",
	ShellBounce = "85310208341495",
	HitBody = "122067256034974",
	HitHead = "105275885463350",
	Elimination = "93718579667184",
	DoublePumpElim = "83664872569347",
	DamageTaken = "103016997503788",
	Death = "105465906827933",
	Spawn = "81574290995171",
	CountdownTick = "95699893390042",
	MatchStart = "100823336379034",
	MatchEnd = "128914040219922",
	Victory = "128338264574038",
	Defeat = "74379053980430",
	UIClick = "97692260400881",
	UIHover = "",
	Vote = "83424934876088",
	Reward = "90581179107431",
	LevelUp = "130023511315158",
	AmbWarehouse = "95360702770922",
	AmbDustTown = "130680677216207",
	AmbRooftops = "127043544223367",
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
