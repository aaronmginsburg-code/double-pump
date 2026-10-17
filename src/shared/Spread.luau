-- Turns one aim direction into PelletCount pellet directions.
-- The pattern comes from a seed, so the client and server get the exact same
-- pellets from the same (seed, direction, aiming) without sending every pellet.

local Config = require(script.Parent.Config)

local Spread = {}

-- The spread angle in degrees, tighter when aiming down sights
function Spread.getSpreadAngle(aiming: boolean): number
	local multiplier = if aiming then Config.Ads.SpreadMultiplier else 1
	return Config.Weapon.SpreadAngle * multiplier
end

function Spread.getPelletDirections(seed: number, aim: Vector3, aiming: boolean): { Vector3 }
	local rng = Random.new(seed)
	local count = Config.Weapon.PelletCount
	local maxSpread = math.tan(math.rad(Spread.getSpreadAngle(aiming)))

	-- A frame looking down the aim line, so we can offset sideways/up from it
	local frame = CFrame.lookAt(Vector3.zero, aim.Unit)

	local directions = {}
	for i = 1, count do
		local offsetX, offsetY = 0, 0
		if i > 1 then
			-- Pellet 1 goes dead center. The rest sit on an inner and outer ring,
			-- evenly spaced around the circle, with a little random jitter.
			local ringSize = if i % 2 == 0 then 0.5 else 1.0
			local angle = (i - 2) / (count - 1) * 2 * math.pi + rng:NextNumber(-0.25, 0.25)
			local radius = maxSpread * ringSize * rng:NextNumber(0.85, 1.0)
			offsetX = math.cos(angle) * radius
			offsetY = math.sin(angle) * radius
		end
		local direction = frame.LookVector + frame.RightVector * offsetX + frame.UpVector * offsetY
		table.insert(directions, direction.Unit)
	end
	return directions
end

return Spread
