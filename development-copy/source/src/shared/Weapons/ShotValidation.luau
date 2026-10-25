--!strict
-- Geometry checks the server runs on each pellet hit a client claims. Pure maths on
-- Roblox datatypes so it is unit-testable; CombatService supplies the world queries.

local ShotValidation = {}

export type HitCheck = {
	origin: Vector3, -- validated shot origin
	direction: Vector3, -- this pellet's unit direction, computed by the server
	hitPosition: Vector3, -- where the client says the pellet hit
	partCFrame: CFrame, -- the target part where the server thinks it was (rewound)
	partSize: Vector3,
	maxRange: number,
	rayTolerance: number,
	hitboxTolerance: number,
}

-- Distance from a point to an oriented box (0 if inside).
function ShotValidation.distanceToBox(point: Vector3, boxCFrame: CFrame, size: Vector3): number
	local localPoint = boxCFrame:PointToObjectSpace(point)
	local half = size / 2
	local dx = math.max(math.abs(localPoint.X) - half.X, 0)
	local dy = math.max(math.abs(localPoint.Y) - half.Y, 0)
	local dz = math.max(math.abs(localPoint.Z) - half.Z, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Returns ok, reason, distanceAlongRay
function ShotValidation.checkHit(c: HitCheck): (boolean, string?, number)
	local toHit = c.hitPosition - c.origin
	local along = toHit:Dot(c.direction)
	if along <= 0 then
		return false, "Behind", along
	end
	if along > c.maxRange then
		return false, "Range", along
	end
	-- The claimed point must lie on this pellet's line.
	local off = (toHit - c.direction * along).Magnitude
	if off > c.rayTolerance then
		return false, "OffRay", along
	end
	-- And on (or near) the target part, where the server last saw it.
	if ShotValidation.distanceToBox(c.hitPosition, c.partCFrame, c.partSize) > c.hitboxTolerance then
		return false, "OffTarget", along
	end
	return true, nil, along
end

-- Sanity checks on a vector from the network (NaN / inf / huge values).
function ShotValidation.isFiniteVector(v: any, maxMagnitude: number?): boolean
	if typeof(v) ~= "Vector3" then
		return false
	end
	local x, y, z = v.X, v.Y, v.Z
	if x ~= x or y ~= y or z ~= z then
		return false
	end
	local m = v.Magnitude
	if m == math.huge or m ~= m then
		return false
	end
	return maxMagnitude == nil or m <= maxMagnitude
end

-- Tolerance that grows with the shooter's ping, capped.
function ShotValidation.scaled(base: number, perSecond: number, cap: number, ping: number): number
	return math.min(base + perSecond * math.clamp(ping, 0, 1), cap)
end

return ShotValidation
