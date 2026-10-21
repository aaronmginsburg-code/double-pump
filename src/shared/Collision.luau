--!strict
-- Collision groups and raycast parameters shared by client and server.
--
-- HumanoidRootPart is an invisible upright box; shots must ignore it (it doesn't
-- crouch with the body), so root parts live in "RootParts", which the "Shots" group
-- doesn't collide with. Map pieces marked "ShotsPassThrough" (railings, fences)
-- go in "ShotThrough": players collide with them, pellets fly through.

local PhysicsService = game:GetService("PhysicsService")

local Collision = {}

Collision.ROOT = "RootParts"
Collision.SHOTS = "Shots"
Collision.SHOT_THROUGH = "ShotThrough"
Collision.EFFECTS = "Effects"

function Collision.setup()
	for _, name in { Collision.ROOT, Collision.SHOTS, Collision.SHOT_THROUGH, Collision.EFFECTS } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(Collision.SHOTS, Collision.ROOT, false)
	PhysicsService:CollisionGroupSetCollidable(Collision.SHOTS, Collision.SHOT_THROUGH, false)
	PhysicsService:CollisionGroupSetCollidable(Collision.SHOTS, Collision.EFFECTS, false)
	-- Spent shells and debris bounce on the map but never push players around
	PhysicsService:CollisionGroupSetCollidable(Collision.EFFECTS, Collision.ROOT, false)
	PhysicsService:CollisionGroupSetCollidable(Collision.EFFECTS, "Default", true)
	PhysicsService:CollisionGroupSetCollidable(Collision.EFFECTS, Collision.EFFECTS, false)
end

-- Raycast params for pellets: everything except the given list, in the Shots group.
function Collision.shotParams(exclude: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.CollisionGroup = Collision.SHOTS
	params.IgnoreWater = true
	return params
end

-- Raycast params that only see the map geometry (walls), for occlusion checks.
function Collision.worldParams(mapRoots: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = mapRoots
	params.CollisionGroup = Collision.SHOTS
	params.IgnoreWater = true
	return params
end

return Collision
