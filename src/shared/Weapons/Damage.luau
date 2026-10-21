--!strict
-- Pellet damage maths: hit zones, distance falloff, caps. Pure functions.

local Damage = {}

export type Zone = "Head" | "Torso" | "Arm" | "Leg"

-- R15 and R6 body part names -> zone. Anything else (accessories, tools) is not a hit.
local PART_ZONES: { [string]: Zone } = {
	Head = "Head",
	UpperTorso = "Torso",
	LowerTorso = "Torso",
	Torso = "Torso",
	HumanoidRootPart = "Torso",
	LeftUpperArm = "Arm",
	LeftLowerArm = "Arm",
	LeftHand = "Arm",
	RightUpperArm = "Arm",
	RightLowerArm = "Arm",
	RightHand = "Arm",
	["Left Arm"] = "Arm",
	["Right Arm"] = "Arm",
	LeftUpperLeg = "Leg",
	LeftLowerLeg = "Leg",
	LeftFoot = "Leg",
	RightUpperLeg = "Leg",
	RightLowerLeg = "Leg",
	RightFoot = "Leg",
	["Left Leg"] = "Leg",
	["Right Leg"] = "Leg",
}

function Damage.zoneForPart(partName: string): Zone?
	return PART_ZONES[partName] :: Zone?
end

-- 1 up to FalloffStart, linear down to FalloffMinMultiplier at FalloffEnd, flat after.
function Damage.falloff(damageConfig: any, distance: number): number
	local start, finish = damageConfig.FalloffStart, damageConfig.FalloffEnd
	if distance <= start then
		return 1
	end
	if distance >= finish then
		return damageConfig.FalloffMinMultiplier
	end
	local alpha = (distance - start) / (finish - start)
	return 1 + (damageConfig.FalloffMinMultiplier - 1) * alpha
end

function Damage.pellet(damageConfig: any, zone: Zone, distance: number): number
	if distance > damageConfig.MaxRange then
		return 0
	end
	local multiplier = damageConfig.Multipliers[zone] or 0
	return damageConfig.PelletDamage * multiplier * Damage.falloff(damageConfig, distance)
end

-- Most damage one shot can do to one target: every pellet a point-blank headshot.
function Damage.maxShotDamage(damageConfig: any): number
	local best = 0
	for _, m in damageConfig.Multipliers do
		best = math.max(best, m)
	end
	return damageConfig.PelletCount * damageConfig.PelletDamage * best
end

-- Sums a list of pellet hits on one target: { {zone=, distance=} } -> total, headshot?
function Damage.total(damageConfig: any, hits: { { zone: Zone, distance: number } }): (number, boolean)
	local sum, head = 0, false
	for _, hit in hits do
		sum += Damage.pellet(damageConfig, hit.zone, hit.distance)
		if hit.zone == "Head" then
			head = true
		end
	end
	return math.min(sum, Damage.maxShotDamage(damageConfig)), head
end

return Damage
