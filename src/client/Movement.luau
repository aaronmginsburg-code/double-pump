-- Client side of crouch, sprint, slide and aim down sights.
--
-- Controls:
--   C or Left Ctrl   crouch (hold; or toggle if Config.Movement.CrouchToggle)
--                    pressing it while moving starts a slide instead
--   Left Shift       sprint (hold)
--   Right mouse      aim down sights (hold)
--   Space            jumping cancels a slide
--
-- The client changes stance instantly (so it feels responsive) and tells the
-- server, which stores it on the character for everyone else to see.
-- None of this blocks the guns: you can fire and swap in any stance.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Pose = require(ReplicatedStorage.Shared.Pose)

local Remotes = ReplicatedStorage.Remotes
local MoveConfig = Config.Movement
local player = Players.LocalPlayer

local Movement = {}

-- Read by the Weapons, Viewmodel and Hud modules
Movement.state = {
	stance = "Stand", -- "Stand" | "Crouch" | "Slide"
	aiming = false,
	sprinting = false,
	aimAmount = 0, -- 0..1, smoothly follows aiming (for the gun and the zoom)
}
local state = Movement.state

local crouchHeld = false
local crouchToggled = false
local sprintHeld = false
local currentFov = MoveConfig.BaseFov
local lastSlideAt = -math.huge

-- While sliding: which way, how fast right now, and when it started
local slide: { direction: Vector3, speed: number, startedAt: number }? = nil

local CROUCH_KEYS = { [Enum.KeyCode.C] = true, [Enum.KeyCode.LeftControl] = true }

local function getHumanoidAndRoot(): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

-- Roblox's built-in movement controls. We switch them off during a slide so
-- the slide steers itself instead of following WASD.
local function getControls()
	local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
	return require(playerModule):GetControls()
end

local function wantsCrouch(): boolean
	return if MoveConfig.CrouchToggle then crouchToggled else crouchHeld
end

local function setStance(stance: string)
	if state.stance ~= stance then
		state.stance = stance
		Remotes.Stance:FireServer(stance)
	end
end

local function setAiming(aiming: boolean)
	if state.aiming ~= aiming then
		state.aiming = aiming
		Remotes.Aim:FireServer(aiming)
	end
end

local function startSlide(humanoid: Humanoid, root: BasePart, horizontalVelocity: Vector3)
	local direction = horizontalVelocity.Unit
	slide = {
		direction = direction,
		speed = horizontalVelocity.Magnitude * MoveConfig.SlideBoost,
		startedAt = os.clock(),
	}
	lastSlideAt = os.clock()

	-- Face the slide direction and stop turning with the camera, so you can
	-- look around (and shoot) while your body slides straight.
	humanoid.AutoRotate = false
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	getControls():Disable()
	setStance("Slide")
end

local function endSlide(humanoid: Humanoid?)
	if not slide then
		return
	end
	slide = nil
	if humanoid then
		humanoid.AutoRotate = true
	end
	getControls():Enable()
	setStance(if wantsCrouch() then "Crouch" else "Stand")
end

local function onCrouchPressed()
	if MoveConfig.CrouchToggle then
		crouchToggled = not crouchToggled
	else
		crouchHeld = true
	end
	if slide then
		return
	end

	local humanoid, root = getHumanoidAndRoot()
	if not humanoid or not root then
		return
	end
	if not wantsCrouch() then
		setStance("Stand") -- toggled crouch off
		return
	end

	-- Moving fast enough on the ground (and slide off cooldown)? Slide. Otherwise crouch.
	local horizontalVelocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
	local slideReady = os.clock() - lastSlideAt >= MoveConfig.SlideCooldown
	if onGround and slideReady and state.stance == "Stand" and horizontalVelocity.Magnitude >= MoveConfig.SlideMinStartSpeed then
		startSlide(humanoid, root, horizontalVelocity)
	else
		setStance("Crouch")
	end
end

local function onCrouchReleased()
	if MoveConfig.CrouchToggle then
		return
	end
	crouchHeld = false
	if not slide then
		setStance("Stand")
	end
	-- (A slide keeps going; when it ends you'll stand because crouch is up.)
end

local function moveToward(current: number, target: number, step: number): number
	if current < target then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end

-- Called every frame from init.client
function Movement.update(deltaTime: number)
	local humanoid, root = getHumanoidAndRoot()
	if not humanoid or not root then
		return
	end

	-- Slide: speed decays with friction; the humanoid walks us along at that speed
	if slide then
		slide.speed -= MoveConfig.SlideFriction * deltaTime
		local elapsed = os.clock() - slide.startedAt
		local actualSpeed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		local hitWall = elapsed > 0.15 and actualSpeed < slide.speed * 0.4
		if slide.speed < MoveConfig.SlideEndSpeed or elapsed > MoveConfig.SlideMaxTime or hitWall then
			endSlide(humanoid)
		else
			humanoid.WalkSpeed = slide.speed
			humanoid:Move(slide.direction, false)
		end
	end

	-- Walk speed for everything except sliding
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	state.sprinting = sprintHeld and moving and not state.aiming and state.stance == "Stand"
	if not slide then
		local speed = MoveConfig.WalkSpeed
		if state.stance == "Crouch" then
			speed = MoveConfig.CrouchSpeed
		elseif state.sprinting then
			speed = MoveConfig.SprintSpeed
		end
		if state.aiming then
			speed *= Config.Ads.MoveSpeedMultiplier
		end
		humanoid.WalkSpeed = speed
	end

	-- Smoothly move the gun to/from the sights, and zoom the camera to match
	state.aimAmount = moveToward(state.aimAmount, if state.aiming then 1 else 0, deltaTime / Config.Ads.TransitionTime)
	local targetFov = MoveConfig.BaseFov - Config.Ads.FovReduction * state.aimAmount
	if state.sprinting then
		targetFov += MoveConfig.SprintFovKick
	elseif slide then
		targetFov += MoveConfig.SlideFovKick
	end
	currentFov += (targetFov - currentFov) * math.min(deltaTime * 10, 1)
	workspace.CurrentCamera.FieldOfView = currentFov
end

function Movement.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if CROUCH_KEYS[input.KeyCode] then
			onCrouchPressed()
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			sprintHeld = true
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			setAiming(true)
		elseif input.KeyCode == Enum.KeyCode.Space and slide then
			local humanoid = getHumanoidAndRoot()
			endSlide(humanoid)
			if humanoid then
				humanoid.Jump = true
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if CROUCH_KEYS[input.KeyCode] then
			onCrouchReleased()
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			sprintHeld = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			setAiming(false)
		end
	end)

	-- Fresh start on respawn (the server's attributes reset with the new character)
	player.CharacterAdded:Connect(function()
		if slide then
			slide = nil
			getControls():Enable()
		end
		state.stance = "Stand"
		state.aiming = false
		crouchToggled = false
	end)

	-- Pose every player's character before physics each frame. Our own
	-- character uses our instant local stance; others use the server's attribute.
	RunService.Stepped:Connect(function(_, deltaTime)
		for _, other in Players:GetPlayers() do
			local character = other.Character
			if character then
				local isMe = other == player
				local stance = if isMe then state.stance else character:GetAttribute("Stance") or "Stand"
				Pose.step(character, stance, deltaTime, isMe, false)
			end
		end
	end)

	-- Roll the camera a little while sliding (runs right after the camera updates)
	RunService:BindToRenderStep("SlideTilt", Enum.RenderPriority.Camera.Value + 1, function()
		local character = player.Character
		if character then
			local tilt = math.rad(MoveConfig.SlideCameraTilt) * Pose.getSlideAmount(character)
			if tilt > 0 then
				local camera = workspace.CurrentCamera
				camera.CFrame *= CFrame.Angles(0, 0, tilt)
			end
		end
	end)
end

return Movement
