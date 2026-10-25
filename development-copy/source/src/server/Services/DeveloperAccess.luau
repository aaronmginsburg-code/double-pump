--!strict
-- Server-only explicit allowlist. No Studio/creator/group-rank shortcut.
local Access = {}
Access.UserIds = { [11808586604] = true } -- existing private Feedback IntegrationConfig moderator
function Access.environment(universeId: number, placeId: number): boolean
	return universeId == 10772492892 and placeId == 139437092998076
end
function Access.allowed(userId: number, universeId: number, placeId: number): boolean
	return Access.environment(universeId, placeId) and Access.UserIds[userId] == true
end
return Access
