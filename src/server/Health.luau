-- Health + shield for anything with a Humanoid (players and dummies).
-- Health is the Humanoid's normal Health. Shield is stored as a "Shield"
-- attribute on the Humanoid so clients can read it for the HUD.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Health = {}

-- Humanoid -> os.clock() time it last took damage (used for regen delay)
local lastDamaged: { [Humanoid]: number } = {}

-- Call once when a character or dummy spawns.
function Health.setup(humanoid: Humanoid)
	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	humanoid:SetAttribute("Shield", Config.Player.StartingShield)
	lastDamaged[humanoid] = 0

	humanoid.Died:Connect(function()
		lastDamaged[humanoid] = nil
	end)
	humanoid.Destroying:Connect(function()
		lastDamaged[humanoid] = nil
	end)
end

function Health.addShield(humanoid: Humanoid, amount: number)
	local shield = humanoid:GetAttribute("Shield") or 0
	humanoid:SetAttribute("Shield", math.min(shield + amount, Config.Player.MaxShield))
end

-- Deals damage, shield first. Returns true if this hit killed the target.
-- attacker is the Humanoid of whoever shot (gets shield on a kill).
function Health.damage(humanoid: Humanoid, amount: number, attacker: Humanoid?): boolean
	if humanoid.Health <= 0 then
		return false
	end

	-- Spawn protection: Roblox puts a ForceField on players who just spawned
	local character = humanoid.Parent
	if character and character:FindFirstChildOfClass("ForceField") then
		return false
	end

	local shield = humanoid:GetAttribute("Shield") or 0
	local absorbed = math.min(shield, amount)
	humanoid:SetAttribute("Shield", shield - absorbed)
	humanoid.Health = math.max(humanoid.Health - (amount - absorbed), 0)
	lastDamaged[humanoid] = os.clock()

	local killed = humanoid.Health <= 0
	if killed and attacker and attacker.Health > 0 then
		Health.addShield(attacker, Config.Player.ShieldOnKill)
	end
	return killed
end

-- Health regen: after HealthRegenDelay seconds without damage, heal slowly.
-- Shield does not regen; you earn it back by getting kills.
RunService.Heartbeat:Connect(function(deltaTime)
	local now = os.clock()
	for humanoid, damagedAt in lastDamaged do
		local regenStarted = now - damagedAt >= Config.Player.HealthRegenDelay
		if regenStarted and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = math.min(
				humanoid.Health + Config.Player.HealthRegenPerSecond * deltaTime,
				humanoid.MaxHealth
			)
		end
	end
end)

return Health
