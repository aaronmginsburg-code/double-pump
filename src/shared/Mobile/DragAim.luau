--!strict
-- One free-screen drag owns aiming; controls and swipe retain their own fingers.
local DragAim = {}
DragAim.__index = DragAim
export type State = typeof(setmetatable({} :: { owner: any }, DragAim))
function DragAim.new(): State
	return setmetatable({ owner = nil :: any }, DragAim)
end
function DragAim.begin(self: State, id: any, blocked: boolean): boolean
	if blocked or self.owner ~= nil then
		return false
	end
	self.owner = id
	return true
end
function DragAim.move(self: State, id: any, delta: Vector2): Vector2
	return if self.owner == id then delta else Vector2.zero
end
function DragAim.finish(self: State, id: any)
	if self.owner == id then
		self.owner = nil
	end
end
function DragAim.clear(self: State)
	self.owner = nil
end
return DragAim
