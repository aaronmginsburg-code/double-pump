-- Three R15 target dummies for solo testing. They use the same Health module
-- as players, so shields, falloff and headshots all work the same on them.
-- When one dies it respawns after Config.Dummies.RespawnTime.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Health = require(script.Parent.Health)
local Arena = require(script.Parent.Arena)
local Hitboxes = require(ReplicatedStorage.Shared.Hitboxes)

local Dummies = {}

type DummySpec = {
	name: string,
	position: Vector3, -- where the dummy stands (on the floor)
	behavior: "Stationary" | "Strafe" | "StrafeJump",
	color: Color3,
}

-- Player spawns are at z = 58 and z = -58, so these sit at different ranges.
local SPECS: { DummySpec } = {
	{ name = "Stationary Dummy", position = Vector3.new(0, 0, 20), behavior = "Stationary", color = Color3.fromRGB(230, 170, 60) },
	{ name = "Strafing Dummy", position = Vector3.new(0, 0, 0), behavior = "Strafe", color = Color3.fromRGB(200, 80, 80) },
	{ name = "Jumping Dummy", position = Vector3.new(0, 0, -20), behavior = "StrafeJump", color = Color3.fromRGB(120, 90, 200) },
}

local folder = Instance.new("Folder")
folder.Name = "Dummies"
folder.Parent = workspace

local function makeRig(spec: DummySpec): Model
	-- A blank HumanoidDescription gives the default blocky R15 body.
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = spec.color
	description.TorsoColor = spec.color
	description.LeftArmColor = spec.color
	description.RightArmColor = spec.color
	description.LeftLegColor = spec.color
	description.RightLegColor = spec.color

	local rig = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	rig.Name = spec.name
	return rig
end

-- Walks back and forth along the X axis until the dummy dies.
local function strafe(humanoid: Humanoid, center: Vector3, jump: boolean)
	humanoid.WalkSpeed = Config.Dummies.StrafeSpeed
	local side = 1
	local lastJump = os.clock()

	while humanoid.Parent and humanoid.Health > 0 do
		local target = center + Vector3.new(side * Config.Dummies.StrafeDistance, 0, 0)
		humanoid:MoveTo(target)

		-- Wait until it gets there (or a few seconds pass), jumping on a timer
		local started = os.clock()
		while humanoid.Parent and humanoid.Health > 0 do
			local root = humanoid.RootPart
			if not root then
				break
			end
			local flatDistance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude
			if flatDistance < 1 or os.clock() - started > 4 then
				break
			end
			if jump and os.clock() - lastJump > Config.Dummies.JumpInterval then
				humanoid.Jump = true
				lastJump = os.clock()
			end
			task.wait(0.1)
		end
		side = -side
	end
end

local function spawnDummy(spec: DummySpec)
	local rig = makeRig(spec)
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart

	-- Stand on the floor facing the north spawn
	local standHeight = humanoid.HipHeight + root.Size.Y / 2
	local position = spec.position + Vector3.new(0, Arena.FLOOR_TOP + standHeight, 0)
	rig:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 1)))

	-- Hide the default overhead name/health bar; damage numbers show hits instead
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	if spec.behavior == "Stationary" then
		root.Anchored = true
	end

	Hitboxes.ignoreRootPart(rig)
	rig.Parent = folder
	Health.setup(humanoid)

	if spec.behavior ~= "Stationary" then
		-- The server owns the dummy's physics so every player sees the same movement
		root:SetNetworkOwner(nil)
		task.spawn(strafe, humanoid, position, spec.behavior == "StrafeJump")
	end

	humanoid.Died:Connect(function()
		task.wait(Config.Dummies.RespawnTime)
		rig:Destroy()
		spawnDummy(spec)
	end)
end

function Dummies.spawnAll()
	for _, spec in SPECS do
		task.spawn(spawnDummy, spec)
	end
end

return Dummies
