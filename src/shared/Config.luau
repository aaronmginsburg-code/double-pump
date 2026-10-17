--!strict
-- All tuning numbers live here so balance changes never need a code change.
-- Values match the design doc's starting baseline (deliberately easy; tighten after playtests).

local Config = {}

Config.Weapon = {
	-- Each shotgun tracks its own cooldown; swapping to the other gun skips it.
	FireCooldown = 1.4, -- seconds between shots from the same gun
	EquipDelay = 0.05, -- seconds after a swap before the new gun can fire
	InputBuffer = 0.10, -- a fire press this early before the swap finishes still counts

	PelletCount = 10,
	PelletDamage = 9, -- 90 total if every pellet hits the body
	FalloffStart = 10, -- studs
	FalloffEnd = 35, -- studs
	FalloffMinMultiplier = 0.3,
}

Config.HitZones = {
	Head = 2.0,
	Torso = 1.0,
	Limbs = 0.8,
}

-- R15 body part name -> hit zone
Config.PartZones = {
	Head = "Head",
	UpperTorso = "Torso",
	LowerTorso = "Torso",
	LeftUpperArm = "Limbs",
	LeftLowerArm = "Limbs",
	LeftHand = "Limbs",
	RightUpperArm = "Limbs",
	RightLowerArm = "Limbs",
	RightHand = "Limbs",
	LeftUpperLeg = "Limbs",
	LeftLowerLeg = "Limbs",
	LeftFoot = "Limbs",
	RightUpperLeg = "Limbs",
	RightLowerLeg = "Limbs",
	RightFoot = "Limbs",
}

Config.Player = {
	MaxHealth = 100,
	MaxShield = 100,
	HealthRegenPerSecond = 5,
	HealthRegenDelay = 5, -- seconds without damage before regen starts
	ShieldOnKill = 50,
	RespawnTime = 3,
	SpawnProtection = 2,
}

Config.Round = {
	TeamSize = 5,
	KillTarget = 40,
	TimeLimit = 8 * 60,
	LobbyTime = 15,
	WarmupTime = 5,
	ResultsTime = 10,
	MapVoteTime = 10,
	MapVoteChoices = 3,
}

return Config
