--!strict
-- Public build never grants development privileges or registers training NPCs.
local Access = { UserIds = {} }
function Access.environment(_universeId: number, _placeId: number): boolean
	return false
end
function Access.allowed(_userId: number, _universeId: number, _placeId: number): boolean
	return false
end
return Access
