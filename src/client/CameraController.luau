-- Camera extras on top of Roblox's first-person camera:
--   - V toggles an over-the-shoulder third-person view
--   - the camera rolls a little while sliding
--
-- Roblox keeps the camera locked in first person (so the mouse stays locked
-- and the body turns with the view). Every frame, right after Roblox places
-- the camera in your head, we slide it back over your shoulder, stopping
-- short of any wall in the way.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Pose = require(ReplicatedStorage.Shared.Pose)

local CameraConfig = Config.Camera
local player = Players.LocalPlayer

local CameraController = {}

CameraController.state = {
	thirdPerson = false,
	amount = 0, -- 0 = first person, 1 = fully over the shoulder (animates between)
}
local state = CameraController.state

-- true while the view is far enough back that we should see our own body
function CameraController.isThirdPerson(): boolean
	return state.amount > 0.5
end

-- Roblox hides your own body in first person. In third person we un-hide it
-- every frame (Roblox would hide it again otherwise).
local function setBodyVisible(character: Model, visible: boolean)
	local modifier = if visible then 0 else 1
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = modifier
		end
	end
end

local function update(deltaTime: number)
	local camera = workspace.CurrentCamera
	local character = player.Character
	if not character then
		return
	end

	local target = if state.thirdPerson then 1 else 0
	local step = deltaTime / CameraConfig.ToggleTime
	state.amount = if state.amount < target then math.min(state.amount + step, target) else math.max(state.amount - step, target)

	if state.amount > 0 then
		-- Roblox just put the camera at the head; move it out over the shoulder
		local headView = camera.CFrame
		local offset = CameraConfig.ShoulderOffset * state.amount
		local wanted = headView * CFrame.new(offset.X, offset.Y, offset.Z)
		local path = wanted.Position - headView.Position

		-- Don't let the camera go through walls: stop just before anything in the way
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit = workspace:Raycast(headView.Position, path, params)
		local position = wanted.Position
		if hit then
			position = headView.Position + path.Unit * math.max(hit.Distance - CameraConfig.WallPadding, 0)
		end
		camera.CFrame = CFrame.new(position) * headView.Rotation
	end

	setBodyVisible(character, CameraController.isThirdPerson())

	-- Roll a little while sliding
	local tilt = math.rad(Config.Movement.SlideCameraTilt) * Pose.getWeight(character, "Slide")
	if tilt > 0 then
		camera.CFrame *= CFrame.Angles(0, 0, tilt)
	end
end

function CameraController.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.V then
			state.thirdPerson = not state.thirdPerson
		end
	end)

	-- Runs right after Roblox's camera update each frame
	RunService:BindToRenderStep("DoublePumpCamera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController
