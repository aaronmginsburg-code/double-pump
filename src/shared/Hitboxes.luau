-- Makes shots ignore each character's HumanoidRootPart.
--
-- The root part is an invisible upright 2x2x1 box Roblox uses for movement.
-- It stays upright even when the body is crouched or lying prone, so if shots
-- could hit it, prone players would still have a standing-sized hitbox.
-- We put root parts in their own collision group that shot raycasts skip.
-- (We can't just turn off CanQuery: Roblox only allows that on non-colliding parts.)

local PhysicsService = game:GetService("PhysicsService")

local Hitboxes = {}

local ROOT_GROUP = "RootParts"
local SHOT_GROUP = "Shots"

-- Server only, once at startup
function Hitboxes.setupGroups()
	PhysicsService:RegisterCollisionGroup(ROOT_GROUP)
	PhysicsService:RegisterCollisionGroup(SHOT_GROUP)
	PhysicsService:CollisionGroupSetCollidable(SHOT_GROUP, ROOT_GROUP, false)
end

-- Server only: call for every player character and dummy
function Hitboxes.ignoreRootPart(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.CollisionGroup = ROOT_GROUP
	end
end

-- Raycast settings for anything shot-related: skips root parts and the
-- given instances (like the shooter's own character).
function Hitboxes.shotParams(exclude: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.CollisionGroup = SHOT_GROUP
	return params
end

return Hitboxes
