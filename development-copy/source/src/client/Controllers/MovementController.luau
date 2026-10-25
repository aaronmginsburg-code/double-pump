--!strict
-- Local movement feel on top of Roblox's Humanoid:
--   * crouch (hold or toggle): lowers the body for real (HipHeight) so the hitbox drops
--   * limited air control: steering mid-air blends toward the input instead of snapping
--   * hides your own body in first person
--   * sends your aim pitch (throttled) so others see where you're looking
-- No sprint/slide/double-jump by design (see GAME_DESIGN.md).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local InputController = require(script.Parent.InputController)
local Settings = require(script.Parent.Settings)
local CameraController = require(script.Parent.CameraController)

local MovementController = {}
MovementController.crouching = false

local player = Players.LocalPlayer
local M = GameConfig.Movement
local playerAction: RemoteEvent
local baseHipHeight = 2
local airVelocity: Vector3? = nil
local lastLookSent = 0
local lastPitchSent = 0

local function humanoidAndRoot(): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.RootPart and humanoid.Health > 0 then
		return humanoid, humanoid.RootPart
	end
	return nil, nil
end

function MovementController.setCrouch(on: boolean)
	if MovementController.crouching == on then
		return
	end
	local humanoid = humanoidAndRoot()
	if not humanoid then
		return
	end
	MovementController.crouching = on
	local character = player.Character :: Model
	humanoid.HipHeight = if on then baseHipHeight - M.CrouchHipDrop else baseHipHeight
	if character:GetAttribute("Frozen") ~= true then
		humanoid.WalkSpeed = if on then M.CrouchSpeed else M.WalkSpeed
	end
	playerAction:FireServer("Crouch", on)
end

local function onCharacter(character: Model)
	MovementController.crouching = false
	airVelocity = nil
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		baseHipHeight = humanoid.HipHeight
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = M.JumpHeight
	end
	-- First person: hide our own body, hats and world gun from ourselves
	local function hide(d: Instance)
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
			d:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
				if d.LocalTransparencyModifier ~= 1 and character:GetAttribute("Dead") ~= true then
					d.LocalTransparencyModifier = 1
				end
			end)
		elseif d:IsA("Decal") then
			d.Transparency = 1
		end
	end
	for _, d in character:GetDescendants() do
		hide(d)
	end
	character.DescendantAdded:Connect(hide)
	-- Show the ragdoll when dead
	character:GetAttributeChangedSignal("Dead"):Connect(function()
		if character:GetAttribute("Dead") == true then
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 0
				end
			end
		end
	end)
end

-- Runs after Roblox's control script each frame so we can shape the move direction.
local function shapeMovement(dt: number)
	local humanoid, root = humanoidAndRoot()
	if not humanoid or not root then
		return
	end
	if InputController.tuningOpen then
		humanoid:Move(Vector3.zero, false)
		humanoid.Jump = false
		airVelocity = Vector3.zero
		return
	end
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
	if airborne then
		-- Limited air control: keep most of the take-off momentum, steer a little
		local wanted = humanoid.MoveDirection
		local current = airVelocity or wanted
		local blend = 1 - math.exp(-dt * 6 * M.AirControl)
		local blended = current:Lerp(wanted, blend)
		airVelocity = blended
		humanoid:Move(blended, false)
	else
		airVelocity = humanoid.MoveDirection
	end

	-- Aim pitch for third-person poses (throttled)
	local now = os.clock()
	local pitch = CameraController.pitch
	if now - lastLookSent > 1 / GameConfig.Network.LookUpdateRate and math.abs(pitch - lastPitchSent) > 0.02 then
		lastLookSent = now
		lastPitchSent = pitch
		playerAction:FireServer("Look", math.floor(pitch * 100 + 0.5) / 100)
	end
end

function MovementController.start()
	playerAction = Net.event("PlayerAction")
	InputController.Action:Connect(function(action, pressed)
		if action ~= "Crouch" then
			return
		end
		if Settings.values.crouchToggle then
			if pressed then
				MovementController.setCrouch(not MovementController.crouching)
			end
		else
			MovementController.setCrouch(pressed)
		end
	end)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService:BindToRenderStep("DoublePumpMovement", Enum.RenderPriority.Input.Value + 1, shapeMovement)
end

return MovementController
