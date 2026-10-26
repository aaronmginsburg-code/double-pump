--!strict
-- Pure trigger and optional swap decisions. No damage, timing bypass or reload interruption.
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
-- Only swap when doing so improves the earliest legal shot. No mid-raise
-- ping-pong, reload cancellation, empty-to-empty swaps or cooldown resets.
function A.swapSlot(c: any, state: any, now: number): number?
	local slot = state.slots[state.equipped]
	if not c.autoSwap or slot.reloading or now < state.readyAt then
		return nil
	end
	local other = if state.equipped == 1 then 2 else 1
	local incoming = state.slots[other]
	if not incoming or incoming.reloading or incoming.ammo <= 0 then
		return nil
	end
	local currentAt = if slot.ammo > 0 then math.max(now, state.nextShotTime, slot.nextFireTime) else math.huge
	local otherAt = math.max(now + state.rules.timing.SwapTime, state.nextShotTime, incoming.nextFireTime)
	return if otherAt + 0.001 < currentAt then other else nil
end
return A
