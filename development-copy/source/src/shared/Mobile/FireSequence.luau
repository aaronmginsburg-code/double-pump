--!strict
-- One fire press; one outstanding swipe intent. No timers/animation callbacks,
-- retries, remote calls or independent cooldowns. The weapon state decides readiness.
local FireSequence = {}
FireSequence.__index = FireSequence
export type State = typeof(setmetatable({} :: { held: boolean, pending: number? }, FireSequence))
function FireSequence.new(): State
	return setmetatable({ held = false, pending = nil }, FireSequence)
end
function FireSequence.press(self: State, fire: () -> ())
	if self.held then
		return
	end
	self.held = true
	self.pending = nil
	fire()
end
function FireSequence.release(self: State)
	self.held = false
	self.pending = nil
end
function FireSequence.swipe(self: State, swap: () -> number?): boolean
	local slot = swap()
	if not slot then
		return false
	end
	if self.held then
		-- A fresh deliberate gesture may switch again before the previous gun is
		-- ready. Replace that intent; never queue a shot for a holstered weapon.
		self.pending = slot
	end
	return true
end
function FireSequence.step(
	self: State,
	active: boolean,
	equipped: number,
	ready: boolean,
	reason: string?,
	fire: () -> ()
)
	if not active then
		self:release()
	end
	if not self.held or self.pending ~= equipped then
		self.pending = nil
		return
	end
	if ready or reason == "Empty" then
		self.pending = nil -- consume before callback; rejected requests never retry
		fire()
	end
end
return FireSequence
