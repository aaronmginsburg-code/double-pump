-- The placeholder shotguns you see in first person, built from plain parts.
-- Both guns exist all the time; only the active one is visible.
--
-- Each frame we place every part relative to the camera. Animations are just
-- extra offsets worked out from timestamps:
--   - recoil: the gun kicks up right after a shot
--   - pump:   the wooden pump slides back and forward while on cooldown,
--             and the light on top is red until the gun can fire again
--   - swap:   the incoming gun rises from below

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Feel = Config.Feel

local Viewmodel = {}

-- Where the gun sits relative to the camera (right, down, forward)
local HOLD_OFFSET = CFrame.new(0.9, -0.85, -1.7)
-- Aiming down sights: centered, with the top of the gun just under the crosshair
local ADS_OFFSET = CFrame.new(0, -0.32, -1.5)
-- Muzzle tip relative to the gun's center
local MUZZLE_OFFSET = CFrame.new(0, 0.08, -2.25)

local READY_COLOR = Color3.fromRGB(80, 255, 120)
local PUMPING_COLOR = Color3.fromRGB(255, 70, 50)

-- Each gun piece: name, size, offset from the gun's center, color.
-- -Z is forward (toward the muzzle).
local PIECES = {
	{ "Receiver", Vector3.new(0.26, 0.32, 1.0), CFrame.new(0, 0, 0), Color3.fromRGB(45, 45, 50) },
	{ "Barrel", Vector3.new(0.13, 0.13, 1.7), CFrame.new(0, 0.08, -1.35), Color3.fromRGB(30, 30, 33) },
	{ "Tube", Vector3.new(0.11, 0.11, 1.3), CFrame.new(0, -0.07, -1.15), Color3.fromRGB(35, 35, 38) },
	{ "Pump", Vector3.new(0.22, 0.2, 0.55), CFrame.new(0, -0.08, -1.05), Color3.fromRGB(120, 75, 40) },
	{ "Stock", Vector3.new(0.22, 0.36, 0.9), CFrame.new(0, -0.12, 0.9), Color3.fromRGB(120, 75, 40) },
	{ "Light", Vector3.new(0.08, 0.04, 0.3), CFrame.new(0, 0.18, 0.15), READY_COLOR },
}

type Gun = { parts: { [string]: Part }, offsets: { [string]: CFrame } }

local guns: { Gun } = {}
local muzzlePosition = Vector3.zero

local function buildGun(): Gun
	local gun: Gun = { parts = {}, offsets = {} }
	for _, piece in PIECES do
		local name, size, offset, color = piece[1], piece[2], piece[3], piece[4]
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = if name == "Light" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false -- our own raycasts must pass through the gun
		part.CanTouch = false
		part.CastShadow = false
		gun.parts[name] = part
		gun.offsets[name] = offset
	end
	return gun
end

function Viewmodel.init()
	guns = { buildGun(), buildGun() }
end

-- 0 -> 1 -> 0 over the course of a cycle (a smooth bump)
local function bump(alpha: number): number
	return math.sin(math.clamp(alpha, 0, 1) * math.pi)
end

-- state: { activeSlot, equippedAt, lastFired = {slot -> time}, now }
-- All times are os.clock() values from the client weapon state.
-- aimAmount: 0 = hip fire, 1 = fully aimed down sights
function Viewmodel.update(camera: Camera, state, alive: boolean, aimAmount: number)
	local holdOffset = HOLD_OFFSET:Lerp(ADS_OFFSET, aimAmount)
	for slot, gun in guns do
		local visible = alive and slot == state.activeSlot
		-- Parts live in the camera so only this player sees them
		local parent = if visible then camera else nil
		for _, part in gun.parts do
			if part.Parent ~= parent then
				part.Parent = parent
			end
		end
		if not visible then
			continue
		end

		local sinceShot = state.now - state.lastFired[slot]
		local cooldownAlpha = sinceShot / Config.Weapon.FireCooldown -- 0 at the shot, 1 when ready
		local sinceSwap = state.now - state.equippedAt

		-- Recoil kick right after firing
		local kick = if sinceShot < Feel.RecoilKickTime then bump(sinceShot / Feel.RecoilKickTime) else 0
		local recoil = CFrame.new(0, 0, kick * 0.3) * CFrame.Angles(math.rad(Feel.RecoilAngle) * kick, 0, 0)

		-- Pump stroke happens after the kick, while the gun is still cooling down
		local pumpAlpha = (sinceShot - Feel.RecoilKickTime) / (Config.Weapon.FireCooldown - Feel.RecoilKickTime)
		local pump = if cooldownAlpha < 1 then bump(pumpAlpha) else 0
		local pumpTilt = CFrame.Angles(0, 0, math.rad(-12) * pump) -- tilt the gun as you rack it

		-- Swap: rise up from below
		local raise = 1 - math.clamp(sinceSwap / Feel.SwapRaiseTime, 0, 1)
		local swapDrop = CFrame.new(0, -Feel.SwapDropDistance * raise, 0)

		local gunCFrame = camera.CFrame * holdOffset * swapDrop * recoil * pumpTilt
		for name, part in gun.parts do
			local offset = gun.offsets[name]
			if name == "Pump" then
				offset = offset * CFrame.new(0, 0, Feel.PumpTravel * pump)
			end
			part.CFrame = gunCFrame * offset
		end
		gun.parts.Light.Color = if cooldownAlpha < 1 then PUMPING_COLOR else READY_COLOR

		muzzlePosition = (gunCFrame * MUZZLE_OFFSET).Position
	end
end

-- Where tracers start (the tip of the visible barrel)
function Viewmodel.getMuzzlePosition(): Vector3
	return muzzlePosition
end

return Viewmodel
