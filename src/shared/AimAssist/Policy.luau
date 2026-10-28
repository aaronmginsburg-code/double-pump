--!strict
-- Pure camera response and target policy; never knows about firing/damage remotes.
local Policy = {}
function Policy.context(a: any, b: any): boolean
	if a.id == b.id or not a.alive or not b.alive or a.frozen or b.frozen then
		return false
	end
	if a.context == "Lobby" then
		return b.dummy or b.context == "Lobby"
	end
	return a.context == "Match"
		and b.context == "Match"
		and a.matchId == b.matchId
		and a.team ~= nil
		and b.team ~= nil
		and a.team ~= b.team
end
function Policy.choose(candidates: { any }, current: any, threshold: number): any
	local best, old = nil, nil
	for _, candidate in candidates do
		if not best or candidate.score < best.score then
			best = candidate
		end
		if candidate.id == current then
			old = candidate
		end
	end
	if old and best and best.id ~= old.id and best.score >= old.score * (1 - threshold) then
		return old
	end
	return best
end
function Policy.inRadius(x: number, y: number, width: number, height: number, fraction: number): (boolean, number)
	local radius = math.max(1, math.min(width, height) * fraction)
	local normalized = math.sqrt((x - width / 2) ^ 2 + (y - height / 2) ^ 2) / radius
	return normalized <= 1, normalized
end
function Policy.response(
	config: any,
	previous: number,
	proximity: number?,
	dt: number,
	device: string,
	aiming: boolean,
	yawError: number,
	pitchError: number
): (number, number, number)
	if not config.enabled or (device ~= "Touch" and device ~= "Gamepad") then
		return 1, 0, 0
	end
	dt = math.clamp(dt, 0, 0.05) -- never catch up a stall with a camera jump
	local weight = if proximity then (1 - math.clamp(proximity, 0, 1)) ^ 2 else 0
	local wanted = if config.slowdownEnabled then 1 - config.slowdownStrength * weight else 1
	local scale = previous + (wanted - previous) * (1 - math.exp(-dt * 18))
	if not config.slowdownEnabled then
		scale = 1
	end
	if not config.rotationEnabled or not aiming or weight == 0 then
		return math.clamp(scale, 0.2, 1), 0, 0
	end
	local alpha = 1 - math.exp(-config.trackingSpeed * config.rotationStrength * weight * dt)
	local y, p = yawError * alpha, pitchError * alpha
	local magnitude = math.sqrt(y * y + p * p)
	local cap = math.rad(35) * config.rotationStrength * dt
	if magnitude > cap and magnitude > 0 then
		y *= cap / magnitude
		p *= cap / magnitude
	end
	return math.clamp(scale, 0.2, 1), y, p
end
return Policy
