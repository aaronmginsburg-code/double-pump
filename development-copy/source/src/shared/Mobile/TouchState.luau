--!strict
-- No engine events: ownership and gesture decisions can be replayed in tests.
local Layout = require(script.Parent.Layout)
local TouchState = {}
TouchState.__index = TouchState
type Touch = { role: string, x: number, y: number, born: number, consumed: boolean, minY: number, maxX: number }
export type State = typeof(setmetatable(
	{} :: { touches: { [any]: Touch }, owners: { [string]: any }, unit: number },
	TouchState
))

function TouchState.new(unit: number): State
	return setmetatable({ touches = {}, owners = {}, unit = unit }, TouchState)
end

function TouchState.begin(self: State, id: any, role: string, x: number, y: number, now: number): boolean
	if self.touches[id] or self.owners[role] then
		return false
	end
	self.touches[id] = { role = role, x = x, y = y, born = now, consumed = false, minY = y, maxX = 0 }
	self.owners[role] = id
	return true
end

function TouchState.move(self: State, id: any, x: number, y: number, now: number): boolean
	local t = self.touches[id]
	if not t or t.role ~= "Swipe" or t.consumed then
		return false
	end
	local g = Layout.Gesture
	local dx, dy = math.abs(x - t.x), y - t.y
	t.minY = math.min(t.minY, y)
	t.maxX = math.max(t.maxX, dx)
	if now - t.born > g.MaxDuration or t.y - t.minY > g.MaxUpward * self.unit then
		t.consumed = true
		return false
	end
	if dy >= g.MinDistance * self.unit and dy >= t.maxX * g.Dominance then
		t.consumed = true
		return true
	end
	return false
end

function TouchState.finish(self: State, id: any): string?
	local t = self.touches[id]
	if not t then
		return nil
	end
	self.owners[t.role] = nil
	self.touches[id] = nil
	return t.role
end

function TouchState.clear(self: State)
	table.clear(self.touches)
	table.clear(self.owners)
end

function TouchState.stick(x: number, y: number, radius: number): Vector2
	local v = Vector2.new(x, y) / math.max(radius, 1)
	return if v.Magnitude > 1 then v.Unit else v
end

return TouchState
