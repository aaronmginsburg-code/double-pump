--!strict
-- Pump shotgun tuning. Both slots (A and B) use these numbers; each slot keeps its own
-- state (ammo, cooldown, reload). Starting values from the design brief, to be playtested.

local WeaponConfig = {}

WeaponConfig.Timing = {
	-- Time between two shots from the SAME shotgun (fire + pump cycle).
	FireCooldown = 1.0,
	-- Minimum time between ANY two shots by a player, even across both shotguns.
	-- This is the "effective switch-to-fire interval": a perfect double pump lands
	-- the second shot this long after the first.
	MinShotInterval = 0.4,
	-- Time from pressing swap until the incoming shotgun is raised and can fire.
	-- Matches the SwapIn animation's Ready event (0.117 s) plus a little.
	SwapTime = 0.15,
	-- Raise time on spawn / first equip (Equip animation's Ready event is 0.333 s).
	EquipTime = 0.35,
	-- A fire press up to this long before the gun is ready is remembered and fires
	-- the moment it becomes ready (client only; the server still checks the timing).
	InputBuffer = 0.1,

	-- Shell-by-shell reload. Total for an empty gun = Start + 5 * Insert.
	ReloadStartTime = 0.3,
	ReloadInsertTime = 0.5, -- per shell (animation is 0.6 s at speed 1; played faster)
	ReloadEndTime = 0.3, -- visual only; the gun can fire during it
	-- Firing or swapping interrupts a reload. Shells already inserted are kept.

	-- Server leniency for network jitter. A shot may arrive up to this much "early"
	-- compared with the server clock. This does not accumulate (see WeaponState).
	ServerTolerance = 0.08,
}

WeaponConfig.Ammo = {
	MagazineSize = 5,
	-- Infinite reserve: every reload refills from an unlimited supply.
	AutoReloadWhenEmpty = true,
}

-- Fixed, learnable pellet pattern (no randomness). Angles in degrees from the aim line.
-- 1 centre pellet, an inner ring of 3 and an outer ring of 6 = 10 pellets.
-- Pellets spread apart linearly with distance (the cone gets wider the further away).
WeaponConfig.Spread = {
	Pattern = {
		{ radius = 0, angle = 0 },
		{ radius = 1.6, angle = 90 },
		{ radius = 1.6, angle = 210 },
		{ radius = 1.6, angle = 330 },
		{ radius = 3.6, angle = 30 },
		{ radius = 3.6, angle = 90 },
		{ radius = 3.6, angle = 150 },
		{ radius = 3.6, angle = 210 },
		{ radius = 3.6, angle = 270 },
		{ radius = 3.6, angle = 330 },
	},
	-- Each shot rotates the whole pattern by a small amount derived from the shot number,
	-- so pellets don't land in exactly the same holes. Deterministic; 0 disables it.
	RollPerShotDegrees = 17,
	-- Crouching tightens the pattern a little (rewards stopping to aim). 1 = no change.
	CrouchMultiplier = 0.9,
	-- Airborne widens it a little. 1 = no change.
	AirborneMultiplier = 1.15,
}

WeaponConfig.Damage = {
	PelletCount = 10,
	PelletDamage = 9,
	Multipliers = {
		Head = 1.75,
		Torso = 1.0,
		Arm = 0.9,
		Leg = 0.8,
	},
	-- Linear falloff: full damage up to Start, down to MinMultiplier at End.
	FalloffStart = 9, -- studs
	FalloffEnd = 45,
	FalloffMinMultiplier = 0.25,
	MaxRange = 150, -- pellets stop here
	-- Hard cap on damage one shot may deal to one target (all pellets headshots, no falloff).
	-- Computed in Damage.maxShotDamage(); kept here for reference.
}

-- A kill counts as a "double pump" when the killing shot follows a hit on the same target
-- from the OTHER shotgun within this window.
WeaponConfig.DoublePumpWindow = 1.2

WeaponConfig.Validation = {
	-- How far the claimed shot origin may be from the server's view of the shooter's head.
	-- Covers movement during latency; grows with ping (see CombatService).
	MaxOriginOffset = 4,
	MaxOriginOffsetPerSecondPing = 30, -- studs per second of ping, capped below
	MaxOriginOffsetCap = 14,
	-- How far a claimed hit point may sit from the pellet's line (studs), for rounding.
	RayTolerance = 1.25,
	-- How far a claimed hit point may sit from the target part's rewound position.
	HitboxTolerance = 3.0,
	HitboxTolerancePerSecondPing = 20,
	HitboxToleranceCap = 9,
	-- Lag compensation: how far back the server rewinds target positions at most.
	MaxRewind = 0.4,
	HistoryRate = 20, -- position snapshots per second
	MaxHitsPerShot = 10,
}

WeaponConfig.Recoil = {
	ViewKickPitch = 2.2, -- degrees
	ViewKickYawRange = 0.6, -- +/- degrees, alternates per shot (deterministic)
	RecoverTime = 0.18,
}

WeaponConfig.Slots = {
	{ id = 1, name = "Pump A", short = "A" },
	{ id = 2, name = "Pump B", short = "B" },
}

return WeaponConfig
