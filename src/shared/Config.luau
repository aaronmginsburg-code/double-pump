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
	MaxOriginOffset = 12, -- studs a shot's origin may be from the shooter's head (third-person camera sits behind it)
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

-- Movement: stances (stand / crouch / prone), sprint, slide, dolphin dive, jumps
Config.Movement = {
	-- Ground speeds (studs/s) for moving forward
	WalkSpeed = 16,
	SprintSpeed = 24,
	CrouchSpeed = 8,
	ProneSpeed = 3, -- crawling
	-- Sideways (A/D) is faster than forward, so strafing is a real dodge
	StrafeMultiplier = 1.25,
	-- How quickly you can change direction in the air (studs/s per second).
	-- Low = jumps carry their momentum; on the ground direction changes are instant.
	AirAcceleration = 25,

	-- Jumping while sprinting keeps sprint speed and adds this forward push
	SprintJumpBoost = 6,

	BaseFov = 70,
	SprintFovKick = 6, -- degrees wider while sprinting
	SlideFovKick = 8,

	-- Seconds to blend between poses (no snapping)
	PoseTransitionTime = 0.15,
	ProneTransitionTime = 0.3, -- getting down / up from prone is slower

	-- Crouch pose: how far the thighs swing forward and the knees bend (degrees).
	-- The character is lowered to match, so a deeper crouch = smaller hitbox.
	CrouchThighAngle = 80,
	CrouchKneeAngle = 130,
	CrouchLean = 25, -- upper body leans forward this much

	-- Prone: lying on the belly
	-- The invisible root box hovers just above the floor. At 0 the Humanoid
	-- loses track of the ground, thinks it's falling, and the body jitters.
	ProneHipHeight = 0.5,
	-- Lowers the lying body to rest on the floor. Too much sinks it into the
	-- floor, and the physics shoving it back out makes the body jitter.
	ProneBodyDrop = 0.4,
	ProneCameraDrop = 1.9, -- first-person camera moves down...
	ProneCameraForward = 1.2, -- ...and forward, to where the head is

	-- Slide: press crouch (C) while sprinting
	SlideLean = 60, -- whole body leans back this much while sliding feet first
	SlideHipHeight = 0.5, -- how high the hips ride above the floor while sliding
	SlideMinStartSpeed = 8, -- studs/s you must be moving to slide
	SlideBoost = 1.4, -- slide starts at your current speed x this
	SlideFriction = 30, -- studs/s lost every second
	SlideEndSpeed = 7, -- slide ends (into crouch) below this speed
	SlideMaxTime = 1.5,
	SlideCooldown = 1.0, -- seconds from the start of one slide to the next
	SlideCameraTilt = 6, -- degrees the camera rolls while sliding

	-- Dolphin dive: press prone (Z) while sprinting
	DiveMinStartSpeed = 8,
	DiveBoost = 1.3, -- forward speed = current speed x this
	DiveUpSpeed = 16, -- fixed upward launch (studs/s); higher = taller arc
	DiveAirDrag = 4, -- forward speed lost per second in the air
	DiveMaxTime = 2, -- safety: ends the dive if you never land
	DiveCooldown = 1.5,
}

-- Procedural body animations (what other players and your third-person view show).
-- Angles are degrees. Arm pitch: 90 = pointing straight ahead.
Config.Animation = {
	-- Holding the gun at the hip, and aiming down sights
	HoldArmPitch = 90,
	AdsArmPitch = 100, -- arms lift the gun up to the eye
	AdsArmInward = 20, -- right arm swings in so the stock sits at the shoulder
	AdsElbowBend = 25,
	AdsHeadTilt = 12, -- head leans down onto the sights

	-- Swapping guns: the arms dip the gun down and bring the next one up
	SwapTime = 0.25,
	SwapDropAngle = 60,

	-- Crouch walking
	CrouchStepsPerStud = 0.35, -- step cycles per stud moved
	CrouchLegSwing = 25, -- how far each thigh swings forward/back
	CrouchKneeLift = 25, -- extra knee bend on the leg stepping forward

	-- Prone crawling on the stomach
	CrawlCyclesPerStud = 0.45,
	CrawlArmReach = 25, -- arms alternate reaching forward
	CrawlLegPull = 30, -- knees alternate pulling up to the side
	CrawlTurnAngle = 75, -- body turns up to this far toward a sideways crawl
	CrawlTurnTime = 0.25, -- seconds to turn the body
}

-- Third person (V toggles)
Config.Camera = {
	ShoulderOffset = Vector3.new(2, 0.8, 6), -- right, up, back from the head (studs)
	ToggleTime = 0.2, -- seconds to swing between first and third person
	WallPadding = 0.4, -- keeps the camera this far off walls it would clip into
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
