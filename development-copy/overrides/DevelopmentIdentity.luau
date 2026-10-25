--!strict
-- Development artifact only. Never include this override in the public project.
local Identity = { UniverseId = 10772492892, PlaceId = 139437092998076 }
function Identity.allowed(universeId: number, placeId: number): boolean
	return universeId == Identity.UniverseId and placeId == Identity.PlaceId
end
return Identity
