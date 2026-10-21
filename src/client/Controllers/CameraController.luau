--!strict
-- First-person camera, written from scratch so sensitivity, FOV, recoil and gamepad /
-- touch aiming behave the same everywhere. The character's body yaw follows the camera.
--
-- Modes:
--   "Combat"  first person at the character's eyes (locked mouse)
--   "Dead"    looks at your body / your eliminator for the respawn delay
--   "Scenic"  slow orbit over the current map (menus, results, voting)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Settings = require(script.Parent.Settings)

local CameraController = {}

local player = Players.LocalPlayer
local C = GameConfig.Camera

export type Mode = "Combat" | "Dead" | "Scenic"
CameraController.mode = "Scenic" :: Mode
CameraController.yaw = 0
CameraController.pitch = 0

local recoil = 0 -- current extra pitch from recoil (radians)
local recoilYaw = 0
local eyeY: number? = nil
local bobTime = 0
local cursorRequests = 0
local gamepadLook = Vector2.zero
local touchDelta = Vector2.zero
local touchLookInputs: { [InputObject]: boolean } = {}
local scenicCenter = Vector3.new(0, 20, 0)
local scenicRadius = 60
local scenicAngle = 0
local deathFocus: Model? = nil
local deathTarget: Model? = nil
local deathTime = 0
local alignOrientation: AlignOrientation? = nil
local fovKick = 0

-- Touches that start on these GUI regions (buttons) don't steer the camera.
CameraController.isTouchOnControl = function(_position: Vector2): boolean
	return false
end

function CameraController.requestCursor(): () -> ()
	cursorRequests += 1
	local released = false
	return function()
		if not released then
			released = true
			cursorRequests -= 1
		end
	end
end

function CameraController.cursorVisible(): boolean
	return cursorRequests > 0 or CameraController.mode ~= "Combat"
end

function CameraController.kick(strength: number?)
	local s = strength or 1
	recoil += math.rad(WeaponConfig.Recoil.ViewKickPitch) * s
	recoilYaw += math.rad(WeaponConfig.Recoil.ViewKickYawRange) * s * (if math.random() < 0.5 then -1 else 1)
	fovKick = 2.5 * s
end

function CameraController.setScenic(center: Vector3, radius: number)
	scenicCenter = center
	scenicRadius = radius
	CameraController.mode = "Scenic"
end

function CameraController.setDead(body: Model?, killer: Model?)
	deathFocus = body
	deathTarget = killer
	deathTime = 0
	CameraController.mode = "Dead"
end

function CameraController.setCombat()
	CameraController.mode = "Combat"
	eyeY = nil
	recoil = 0
	recoilYaw = 0
end

-- Faces the camera along a CFrame's look direction (on spawn).
function CameraController.lookAlong(cf: CFrame)
	local look = cf.LookVector
	CameraController.yaw = math.atan2(-look.X, -look.Z)
	CameraController.pitch = 0
end

function CameraController.aimCFrame(): CFrame
	return workspace.CurrentCamera.CFrame
end

local function applyDeadzone(v: Vector2): Vector2
	local m = v.Magnitude
	if m < 0.15 then
		return Vector2.zero
	end
	local scaled = (m - 0.15) / 0.85
	-- Response curve: fine control near the centre, fast at the edge.
	return v.Unit * math.pow(math.min(scaled, 1), 1.7)
end

local function ensureAlign(root: BasePart)
	if alignOrientation and alignOrientation.Parent == root then
		return
	end
	local attachment = root:FindFirstChild("DPYawAttachment") :: Attachment?
	if not attachment then
		local a = Instance.new("Attachment")
		a.Name = "DPYawAttachment"
		a.Parent = root
		attachment = a
	end
	local align = Instance.new("AlignOrientation")
	align.Name = "DPYaw"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.RigidityEnabled = true
	align.Parent = root
	alignOrientation = align
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local values = Settings.values
	local mode = CameraController.mode
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart

	-- Mouse
	local wantLock = mode == "Combat" and cursorRequests == 0
	UserInputService.MouseBehavior = if wantLock then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = not wantLock

	if mode == "Combat" and root and humanoid then
		-- Look input
		if wantLock then
			local delta = UserInputService:GetMouseDelta()
			local k = C.MouseRadiansPerPixel * values.sensitivity
			CameraController.yaw -= delta.X * k
			CameraController.pitch -= delta.Y * k
		end
		local stick = applyDeadzone(gamepadLook)
		if stick.Magnitude > 0 then
			local k = C.GamepadRadiansPerSecond * values.gamepadSensitivity * dt
			CameraController.yaw -= stick.X * k
			CameraController.pitch += stick.Y * k
		end
		if touchDelta.Magnitude > 0 then
			local k = C.TouchRadiansPerPixel * values.touchSensitivity
			CameraController.yaw -= touchDelta.X * k
			CameraController.pitch -= touchDelta.Y * k
			touchDelta = Vector2.zero
		end
		CameraController.pitch = math.clamp(CameraController.pitch, -C.MaxPitch, C.MaxPitch)

		-- Recoil springs back
		local recover = math.exp(-dt / (WeaponConfig.Recoil.RecoverTime / 3))
		recoil *= recover
		recoilYaw *= recover
		fovKick *= math.exp(-dt * 14)

		-- Eye position, smoothed vertically (steps, crouch)
		local targetY = root.Position.Y + C.EyeHeight
		if not eyeY or math.abs((eyeY :: number) - targetY) > 6 then
			eyeY = targetY
		else
			eyeY = (eyeY :: number) + (targetY - (eyeY :: number)) * (1 - math.exp(-dt * C.EyeSmoothing))
		end
		local bob = 0
		local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		if values.cameraBob and humanoid.FloorMaterial ~= Enum.Material.Air and speed > 2 then
			bobTime += dt * speed * 0.55
			bob = math.sin(bobTime) * C.BobAmount * math.min(speed / 16, 1.2)
		end
		local eye = Vector3.new(root.Position.X, (eyeY :: number) + bob, root.Position.Z)
		camera.CFrame = CFrame.new(eye)
			* CFrame.Angles(0, CameraController.yaw + recoilYaw, 0)
			* CFrame.Angles(CameraController.pitch + recoil, 0, 0)
		camera.FieldOfView = values.fov + fovKick

		-- Body faces where you look
		humanoid.AutoRotate = false
		ensureAlign(root)
		if alignOrientation then
			alignOrientation.CFrame = CFrame.Angles(0, CameraController.yaw, 0)
		end
	elseif mode == "Dead" then
		deathTime += dt
		local focus = deathFocus and deathFocus:FindFirstChild("HumanoidRootPart") :: BasePart?
		local killerRoot = deathTarget and deathTarget:FindFirstChild("Head") :: BasePart?
		local base = if focus then focus.Position else camera.CFrame.Position
		local look = if killerRoot then killerRoot.Position else base
		local back = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if back.Magnitude < 0.1 then
			back = Vector3.new(0, 0, -1)
		end
		local pos = base - back.Unit * (6 + deathTime * 1.5) + Vector3.new(0, 5 + deathTime, 0)
		camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(pos, look), 1 - math.exp(-dt * 4))
		camera.FieldOfView = values.fov
	else
		scenicAngle += dt * 0.06
		local pos = scenicCenter
			+ Vector3.new(
				math.cos(scenicAngle) * scenicRadius,
				scenicRadius * 0.45,
				math.sin(scenicAngle) * scenicRadius
			)
		camera.CFrame = CFrame.lookAt(pos, scenicCenter)
		camera.FieldOfView = 60
	end
end

function CameraController.start()
	RunService:BindToRenderStep("DoublePumpCamera", Enum.RenderPriority.Camera.Value + 1, update)

	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			gamepadLook = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.UserInputType == Enum.UserInputType.Touch and touchLookInputs[input] then
			touchDelta += Vector2.new(input.Delta.X, input.Delta.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			gamepadLook = Vector2.zero
		end
		touchLookInputs[input] = nil
	end)
	UserInputService.TouchStarted:Connect(function(input, processed)
		if processed then
			return
		end
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		local viewport = workspace.CurrentCamera.ViewportSize
		-- Left 40% of the screen belongs to the movement thumbstick
		if pos.X > viewport.X * 0.4 and not CameraController.isTouchOnControl(pos) then
			touchLookInputs[input] = true
		end
	end)
	player.CharacterAdded:Connect(function()
		alignOrientation = nil
		eyeY = nil
	end)
end

return CameraController
