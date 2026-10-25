--!strict
-- Deterministic pellet pattern. Given the aim direction and the shot number, every client
-- and the server compute exactly the same pellet directions, so the server never has to
-- trust the client's pellet list and players can learn the pattern.

local Spread = {}

export type PatternPoint = { radius: number, angle: number }

-- Orthonormal right/up vectors for an aim direction (handles looking straight up/down).
local function basis(aim: Vector3): (Vector3, Vector3)
	local worldUp = if math.abs(aim.Y) > 0.98 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
	local right = aim:Cross(worldUp).Unit
	local up = right:Cross(aim).Unit
	return right, up
end

-- Returns one unit direction per pellet.
--   aim: unit vector the player is looking along
--   shotNumber: from WeaponState.fire, rotates the pattern deterministically
--   multiplier: scales the cone (crouch / airborne)
function Spread.directions(spreadConfig: any, aim: Vector3, shotNumber: number, multiplier: number?): { Vector3 }
	local right, up = basis(aim)
	local roll = math.rad((spreadConfig.RollPerShotDegrees or 0) * shotNumber)
	local scale = multiplier or 1
	local out = table.create(#spreadConfig.Pattern)
	for i, point: PatternPoint in spreadConfig.Pattern do
		local radius = math.rad(point.radius * scale)
		local theta = math.rad(point.angle) + roll
		-- Offset on a plane one stud in front of the muzzle, then normalise.
		local offset = (right * math.cos(theta) + up * math.sin(theta)) * math.tan(radius)
		out[i] = (aim + offset).Unit
	end
	return out
end

-- Cone multiplier from the shooter's movement state.
function Spread.stateMultiplier(spreadConfig: any, crouching: boolean, airborne: boolean): number
	local m = 1
	if crouching then
		m *= spreadConfig.CrouchMultiplier
	end
	if airborne then
		m *= spreadConfig.AirborneMultiplier
	end
	return m
end

return Spread
