--!strict
-- Match, team, player and movement tuning. Every number a designer might want to change
-- lives here (weapons are in WeaponConfig, progression in ProgressionConfig).
-- These are starting values for playtesting, not final balance.

local GameConfig = {}

GameConfig.LobbyQueue = {
	Minimum = 2,
	Capacity = 10,
	Countdown = 15,
	PollInterval = 0.1,
	-- Rear corner of the existing range, outside every range spawn and target lane.
	Offset = Vector3.new(-52, 7, 37),
	Size = Vector3.new(18, 14, 10),
}

GameConfig.Match = {
	MaxPlayers = 10, -- also set Max Players to 10 in Game Settings > Places
	MaxTeamSize = 5,
	MinPlayersToStart = 2, -- below this the server stays in practice mode
	Duration = 5 * 60, -- seconds of regulation time
	ScoreToWin = 40, -- team eliminations
	-- Scale the target down for small lobbies so a 1v1 doesn't need 40 kills.
	-- The target is max(ScoreToWinMin, ceil(ScoreToWin * players / MaxPlayers)), rounded up to 5.
	ScaleScoreWithPlayers = true,
	ScoreToWinMin = 15,

	IntermissionTime = 10, -- waiting for more players after the minimum is reached
	StartingCountdown = 5, -- players frozen at spawn while the countdown runs
	ResultsTime = 9,
	VotingTime = 12,

	-- Tie at the end of regulation: sudden death, first elimination wins.
	OvertimeEnabled = true,
	OvertimeDuration = 60,
	-- If overtime also ends tied the match is a draw.
}

GameConfig.Teams = {
	Red = { Name = "Red", Color = Color3.fromRGB(255, 72, 72), BrickColor = "Bright red" },
	Blue = { Name = "Blue", Color = Color3.fromRGB(64, 156, 255), BrickColor = "Bright blue" },
	-- Move a dead player to the smaller team when the size gap reaches this.
	RebalanceGap = 2,
}

GameConfig.Player = {
	MaxHealth = 100,
	RespawnDelay = 2.5,
	SpawnProtection = 2.0, -- seconds of invulnerability, ended early by firing
	-- Spawn picking: avoid points with an enemy within this many studs or in line of sight.
	SpawnEnemyRadius = 30,
	-- Damage older than this doesn't earn an assist.
	AssistWindow = 8,
	AssistMinDamage = 25,
}

GameConfig.Movement = {
	WalkSpeed = 20, -- Roblox default is 16
	CrouchSpeed = 11,
	JumpHeight = 7.6, -- studs (Roblox default 7.2); "moderately high"
	Gravity = 196.2,
	CrouchHipDrop = 1.25, -- studs the body lowers while crouched (hitbox really drops)
	CrouchCameraDrop = 1.6,
	-- Ground acceleration feel: Roblox humanoids already change direction instantly.
	-- Air control is limited by blending the move direction while airborne.
	AirControl = 0.55, -- 0 = no steering in the air, 1 = full
	SprintEnabled = false, -- off by default; the spec only wants it if testing justifies it
	SprintSpeed = 24,
}

GameConfig.Camera = {
	-- Vertical field of view in degrees (Roblox's FieldOfView). 78 vertical is about
	-- 108 horizontal on a 16:9 screen. Players can change it in Settings.
	DefaultFov = 78,
	MinFov = 60,
	MaxFov = 95,
	DefaultSensitivity = 1.0,
	MinSensitivity = 0.1,
	MaxSensitivity = 4.0,
	MouseRadiansPerPixel = 0.0035, -- at sensitivity 1
	GamepadRadiansPerSecond = 4.2, -- full stick deflection at sensitivity 1
	TouchRadiansPerPixel = 0.006,
	MaxPitch = math.rad(80),
	EyeHeight = 1.6, -- eye height above HumanoidRootPart's centre (studs)
	EyeSmoothing = 25, -- higher = snappier vertical follow on steps/crouch
	BobAmount = 0.06, -- studs of vertical bob while running; subtle on purpose
}

GameConfig.Network = {
	-- Remote rate limits (token bucket): burst, then refill per second.
	WeaponActionBurst = 12,
	WeaponActionRate = 8,
	GeneralBurst = 10,
	GeneralRate = 4,
	LookUpdateRate = 12, -- per second, for the third-person aim pitch
}

GameConfig.Practice = {
	TargetRespawn = 2.0,
	MovingTargetSpeed = 12, -- studs/s strafing targets
}

GameConfig.Debug = {
	-- Studio only: lets one player start a real match against nobody (for solo testing).
	AllowSoloMatchInStudio = false,
	-- Hold-to-fire for testing; the spec wants deliberate presses.
	AutoFireWhenHeld = false,
	ShowPelletDebug = false,
}

return GameConfig
