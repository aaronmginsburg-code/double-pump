--!strict
-- Pure trigger state. No damage application, auto switching, buffering or reload interruption.
local A = {}
function A.new(): any
	return { target = nil, acquired = 0, lastShot = -math.huge, reason = "Disabled", remaining = 0 }
end
function A.step(
	s: any,
	c: any,
	now: number,
	target: any,
	device: string,
	active: boolean,
	ready: boolean,
	reloading: boolean
): boolean
	local eligible = if device == "Touch"
		then c.touchEligible
		elseif device == "Gamepad" then c.controllerEligible
		else c.mouseEligible
	if not c.enabled or not eligible or not active or not target then
		s.target = nil
		s.remaining = 0
		s.reason = if not c.enabled
			then "Disabled"
			elseif not eligible then "Input not eligible"
			elseif not active then "Not in combat / UI focused"
			else "No visible target"
		return false
	end
	if s.target ~= target then
		s.target = target
		s.acquired = now
	end
	s.remaining = math.max(0, math.max(c.delay, c.persistence) - (now - s.acquired))
	if s.remaining > 0 then
		s.reason = "Acquiring"
		return false
	end
	if reloading then
		s.reason = "Reloading (not interrupted)"
		return false
	end
	if not ready then
		s.reason = "Weapon not ready"
		return false
	end
	if now - s.lastShot < c.cooldown then
		s.reason = "Auto-fire interval"
		return false
	end
	s.lastShot = now
	s.reason = "Ordinary fire request"
	return true
end
return A
