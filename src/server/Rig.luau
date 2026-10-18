-- Newer Studio avatars join their body parts with physics constraints
-- (AnimationConstraint + BallSocketConstraint) and simulate each part on its
-- own. Our procedural poses bend the body a lot (lying flat, sliding), and on
-- a physics rig that shoves the character around, makes it jitter, and can
-- leave the Humanoid stuck. So every player character is switched to the
-- classic rigid R15 joints (Motor6D): same joint names, same animations, and
-- the server's copy of the body matches the poses for hit checks.

local Rig = {}

-- Replaces one AnimationConstraint with an equivalent Motor6D
local function convert(constraint: AnimationConstraint)
	local a0, a1 = constraint.Attachment0, constraint.Attachment1
	local part0 = a0 and a0.Parent
	local part1 = a1 and a1.Parent
	if not (part0 and part0:IsA("BasePart") and part1 and part1:IsA("BasePart")) then
		return
	end
	local motor = Instance.new("Motor6D")
	motor.Name = constraint.Name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = a0.CFrame
	motor.C1 = a1.CFrame
	-- Add the new joint before removing the old one: a character with no Neck
	-- joint, even for an instant, dies
	motor.Parent = constraint.Parent
	constraint:Destroy()
end

local function check(instance: Instance)
	if instance:IsA("AnimationConstraint") then
		convert(instance)
	elseif instance:IsA("BallSocketConstraint") and not instance:FindFirstAncestorOfClass("Accessory") then
		-- The joint limits that went with the physics joints; Motor6Ds don't need them
		instance:Destroy()
	end
end

function Rig.useClassicJoints(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local requiresNeck = humanoid and humanoid.RequiresNeck
	if humanoid then
		humanoid.RequiresNeck = false -- belt and braces while we swap the joints
	end
	for _, descendant in character:GetDescendants() do
		check(descendant)
	end
	if humanoid then
		humanoid.RequiresNeck = requiresNeck
	end
	character:SetAttribute("ClassicJoints", true)
	-- Body parts can be rebuilt as the avatar's appearance loads
	character.DescendantAdded:Connect(function(descendant)
		task.defer(function()
			if descendant.Parent then
				check(descendant)
			end
		end)
	end)
end

return Rig
