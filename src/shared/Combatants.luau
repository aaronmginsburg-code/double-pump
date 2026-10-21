--!strict
-- Identifies things that can be shot: player characters and practice dummies.
-- Both are Models with a Humanoid, tagged "Combatant". The server sets a "Team"
-- attribute ("Red"/"Blue") on player characters in a match; dummies have "Dummy" = true.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Combatants = {}

Combatants.TAG = "Combatant"

-- The combatant model + humanoid that a hit part belongs to, if any.
function Combatants.fromPart(part: Instance?): (Model?, Humanoid?)
	local current = part
	while current and current ~= workspace do
		if current:IsA("Model") and CollectionService:HasTag(current, Combatants.TAG) then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			if humanoid then
				return current, humanoid
			end
			return nil, nil
		end
		current = current.Parent
	end
	return nil, nil
end

function Combatants.player(model: Model): Player?
	return Players:GetPlayerFromCharacter(model)
end

function Combatants.isDummy(model: Model): boolean
	return model:GetAttribute("Dummy") == true
end

function Combatants.team(model: Model): string?
	return model:GetAttribute("Team") :: string?
end

-- Can `attacker` damage `target`?
function Combatants.isEnemy(attacker: Model, target: Model): boolean
	if attacker == target then
		return false
	end
	if Combatants.isDummy(target) then
		return true
	end
	local a, b = Combatants.team(attacker), Combatants.team(target)
	if a == nil or b == nil then
		-- Outside a match (practice range) players can't hurt each other
		return false
	end
	return a ~= b
end

function Combatants.isAlive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and model:GetAttribute("Dead") ~= true
end

function Combatants.all(): { Model }
	local list = {}
	for _, inst in CollectionService:GetTagged(Combatants.TAG) do
		if inst:IsA("Model") and inst:IsDescendantOf(workspace) then
			table.insert(list, inst)
		end
	end
	return list
end

-- Body parts tracked for lag compensation (R15 + R6 names).
Combatants.HitParts = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"Torso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
}

return Combatants
