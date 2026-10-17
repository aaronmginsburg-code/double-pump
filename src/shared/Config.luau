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

	SpreadAngle = 5, -- degrees from the aim line to the outer ring of pellets
	MaxRange = 80, -- studs; pellets do nothing past this

	-- Server-side cheat checks (generous so laggy players aren't punished)
	ServerTimingTolerance = 0.1, -- seconds of slack on cooldown/equip checks
	MaxOriginOffset = 6, -- studs a shot's origin may be from the shooter's head
	HitTolerance = 4, -- studs a claimed hit may be off the server's pellet line
}

Config.HitZones = {
	Head = 2.0,
	Torso = 1.0,
	Limbs = 0.8,
}

-- R15 body part name -> hit zone
Config.PartZones = {
	Head = "Head",
	HumanoidRootPart = "Torso", -- invisible box around the torso; rays can hit it first
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
	StartingShield = 100, -- shield on spawn; shield absorbs damage before health
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

-- Aim down sights (hold right mouse)
Config.Ads = {
	SpreadMultiplier = 0.35, -- pellet cone is this fraction of the hip-fire cone
	FalloffRangeMultiplier = 1.6, -- FalloffStart/End are stretched by this when aiming
	MoveSpeedMultiplier = 0.6, -- walk speed while aiming
	FovReduction = 12, -- degrees of zoom
	TransitionTime = 0.12, -- seconds for the gun to move to the center
}

-- Crouch, sprint, slide
Config.Movement = {
	WalkSpeed = 16,
	SprintSpeed = 24,
	CrouchSpeed = 8,
	CrouchToggle = false, -- true: press C/Ctrl to toggle crouch; false: hold it

	BaseFov = 70,
	SprintFovKick = 6, -- degrees wider while sprinting
	SlideFovKick = 8,

	-- Seconds to blend between standing, crouching and sliding poses
	PoseTransitionTime = 0.12,
	-- Crouch pose: how far the thighs swing forward and the knees bend (degrees).
	-- The character is lowered to match, so a deeper crouch = smaller hitbox.
	CrouchThighAngle = 80,
	CrouchKneeAngle = 130,
	CrouchLean = 25, -- upper body leans forward this much
	SlideLean = 60, -- whole body leans back this much while sliding feet first
	SlideHipHeight = 0.5, -- how high the hips ride above the floor while sliding

	-- Slide: press crouch while moving
	SlideMinStartSpeed = 8, -- studs/s you must be moving to slide instead of crouch
	SlideBoost = 1.4, -- slide starts at your current speed x this
	SlideFriction = 30, -- studs/s lost every second
	SlideEndSpeed = 7, -- slide ends (into crouch/stand) below this speed
	SlideMaxTime = 1.5,
	SlideCooldown = 1.0, -- seconds from the start of one slide to the next
	SlideCameraTilt = 6, -- degrees the camera rolls while sliding
}

-- Sounds. Asset IDs look like "rbxassetid://1234567890".
Config.Audio = {
	-- Played only for the killer when they get a kill (players and dummies).
	-- Placeholder: a beep that ships with every Roblox client. To use your own,
	-- upload a sound you have the rights to (Creator Hub > Audio) and paste its
	-- ID here. Don't upload game rips (e.g. Battlefield sounds): Roblox removes
	-- copyrighted audio and can moderate the account. Set to "" for no sound.
	EliminationSound = "rbxasset://sounds/electronicpingshort.wav",
	EliminationVolume = 0.8,
	EliminationPitch = 1.3,
}

-- Target dummies in the feel-test room
Config.Dummies = {
	RespawnTime = 3,
	StrafeDistance = 12, -- studs each side of the start point
	StrafeSpeed = 14, -- WalkSpeed while strafing (players default to 16)
	JumpInterval = 1.5, -- seconds between jumps for the jumping dummy
}

-- Client-only look and feel
Config.Feel = {
	TracerLifetime = 0.08, -- seconds a pellet tracer stays visible
	ImpactLifetime = 0.4,
	HitmarkerTime = 0.15,
	DamageNumberTime = 0.8,
	RecoilKickTime = 0.12, -- seconds the gun kicks back after a shot
	RecoilAngle = 8, -- degrees the gun tips up on a shot
	SwapDropDistance = 0.6, -- studs the incoming gun rises from on a swap
	SwapRaiseTime = 0.12, -- seconds the raise animation takes (purely visual)
	PumpTravel = 0.35, -- studs the pump slides back while cycling
}

return Config
