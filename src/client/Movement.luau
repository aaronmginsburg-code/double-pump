-- Client side of movement: stances, sprint, slide, dolphin dive, jumps, strafing,
-- and aim down sights.
--
-- Controls (all stance keys are toggles):
--   C or Left Ctrl   crouch / stand.  While sprinting: slide
--   Z                prone / stand.   While sprinting: dolphin dive
--   Space            jump (from crouch or prone: stand up; mid-slide: jump out)
--   Left Shift       sprint (hold)
--   Right mouse      aim down sights (hold)
--
-- Roblox's own controls still read WASD / arrow keys; we take the direction
-- they produce and set the speed ourselves: faster sideways (strafe), instant
-- direction changes on the ground, and momentum that carries through the air.
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
	stance = "Stand", -- "Stand" | "Crouch" | "Prone" | "Slide" | "Dive"
	aiming = false,
	sprinting = false,
	aimAmount = 0, -- 0..1, smoothly follows aiming (for the gun and the zoom)
}
local state = Movement.state

local sprintHeld = false
local jumpBlocked = false -- the Space press that stood you up shouldn't also jump
local currentFov = MoveConfig.BaseFov
local lastUsed = { Slide = -math.huge, Dive = -math.huge }

-- A slide or dive in progress: which way, how fast right now, when it started
type Move = { direction: Vector3, speed: number, startedAt: number }
local slide: Move? = nil
local dive: Move? = nil

local CROUCH_KEYS = { [Enum.KeyCode.C] = true, [Enum.KeyCode.LeftControl] = true }
local FLAT = Vector3.new(1, 0, 1) -- multiply by this to ignore up/down

-- True while jumping or falling (more reliable than FloorMaterial right at takeoff)
local function isAirborne(humanoid: Humanoid): boolean
	local humanoidState = humanoid:GetState()
	return humanoidState == Enum.HumanoidStateType.Jumping or humanoidState == Enum.HumanoidStateType.Freefall
end

local function getHumanoidAndRoot(): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

-- Roblox's built-in movement controls (WASD, arrows, jump). Some Studio
-- versions don't put a PlayerModule in PlayerScripts, so never wait for it:
-- if it's missing we read the keys ourselves (readMoveKeys below).
local controls = nil
local function getControls()
	if controls == nil then
		local playerScripts = player:FindFirstChild("PlayerScripts")
		local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
		if playerModule then
			local ok, result = pcall(function()
				return require(playerModule):GetControls()
			end)
			controls = if ok then result else false
		end
	end
	return controls or nil
end

local function setControlsEnabled(enabled: boolean)
	local found = getControls()
	if found then
		if enabled then
			found:Enable()
		else
			found:Disable()
		end
	end
end

-- Same shape as the controls' move vector: X = right, Z = back (forward is negative)
local function readMoveKeys(): Vector3
	local function held(a: Enum.KeyCode, b: Enum.KeyCode): number
		return if UserInputService:IsKeyDown(a) or UserInputService:IsKeyDown(b) then 1 else 0
	end
	if UserInputService:GetFocusedTextBox() then
		return Vector3.zero
	end
	local x = held(Enum.KeyCode.D, Enum.KeyCode.Right) - held(Enum.KeyCode.A, Enum.KeyCode.Left)
	local z = held(Enum.KeyCode.S, Enum.KeyCode.Down) - held(Enum.KeyCode.W, Enum.KeyCode.Up)
	local move = Vector3.new(x, 0, z)
	for _, input in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if input.KeyCode == Enum.KeyCode.Thumbstick1 and input.Position.Magnitude > 0.2 then
			move += Vector3.new(input.Position.X, 0, -input.Position.Y)
		end
	end
	return move
end

local function getMoveInput(): Vector3
	local found = getControls()
	return if found then found:GetMoveVector() else readMoveKeys()
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

-- Slides and dives need you sprinting on the ground, fast enough, off cooldown
local function canStart(moveName: string, minSpeed: number, cooldown: number): boolean
	local humanoid, root = getHumanoidAndRoot()
	if not humanoid or not root or not state.sprinting then
		return false
	end
	local onGround = not isAirborne(humanoid)
	local speed = (root.AssemblyLinearVelocity * FLAT).Magnitude
	return onGround and speed >= minSpeed and os.clock() - lastUsed[moveName] >= cooldown
end

-- Shared start for slides and dives: lock the body facing the way you're
-- going and switch off WASD steering (you can still look around and shoot).
local function beginMove(moveName: string, boost: number): Move?
	local humanoid, root = getHumanoidAndRoot()
	if not humanoid or not root then
		return nil
	end
	local horizontal = root.AssemblyLinearVelocity * FLAT
	local direction = horizontal.Unit
	lastUsed[moveName] = os.clock()
	state.sprinting = false
	humanoid.AutoRotate = false
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	setControlsEnabled(false)
	setStance(moveName)
	return { direction = direction, speed = horizontal.Magnitude * boost, startedAt = os.clock() }
end

local function finishMove(nextStance: string)
	slide = nil
	dive = nil
	local humanoid = getHumanoidAndRoot()
	if humanoid then
		humanoid.AutoRotate = true
	end
	setControlsEnabled(true)
	setStance(nextStance)
end

local function startDive()
	dive = beginMove("Dive", MoveConfig.DiveBoost)
	local humanoid, root = getHumanoidAndRoot()
	if dive and humanoid and root then
		-- Leave the ground and launch forward + up in a low arc
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = dive.direction * dive.speed + Vector3.yAxis * MoveConfig.DiveUpSpeed
	end
end

local function onCrouchKey()
	if dive then
		return -- busy diving; you'll land prone
	elseif slide then
		finishMove("Stand")
	elseif state.stance == "Crouch" then
		setStance("Stand")
	elseif state.stance == "Stand" and canStart("Slide", MoveConfig.SlideMinStartSpeed, MoveConfig.SlideCooldown) then
		slide = beginMove("Slide", MoveConfig.SlideBoost)
	else
		setStance("Crouch")
	end
end

local function onProneKey()
	if dive then
		return
	elseif slide then
		finishMove("Prone")
	elseif state.stance == "Prone" then
		setStance("Stand")
	elseif state.stance == "Stand" and canStart("Dive", MoveConfig.DiveMinStartSpeed, MoveConfig.DiveCooldown) then
		startDive()
	else
		setStance("Prone")
	end
end

local function onJumpKey()
	if slide then
		finishMove("Stand")
		local humanoid = getHumanoidAndRoot()
		if humanoid then
			humanoid.Jump = true
		end
	elseif state.stance == "Crouch" or state.stance == "Prone" then
		setStance("Stand")
		jumpBlocked = true -- stand up only; jump on the next press
	end
end

-- Steps a slide or dive forward one frame. Returns true while it's still going.
local function updateSlide(humanoid: Humanoid, root: BasePart, deltaTime: number): boolean
	local move = slide :: Move
	move.speed -= MoveConfig.SlideFriction * deltaTime
	local elapsed = os.clock() - move.startedAt
	local actualSpeed = (root.AssemblyLinearVelocity * FLAT).Magnitude
	local hitWall = elapsed > 0.15 and actualSpeed < move.speed * 0.4
	if move.speed < MoveConfig.SlideEndSpeed or elapsed > MoveConfig.SlideMaxTime or hitWall then
		finishMove("Crouch")
		return false
	end
	humanoid.WalkSpeed = move.speed
	humanoid:Move(move.direction, false)
	return true
end

local function updateDive(humanoid: Humanoid, root: BasePart, deltaTime: number): boolean
	local move = dive :: Move
	move.speed = math.max(move.speed - MoveConfig.DiveAirDrag * deltaTime, 0)
	local elapsed = os.clock() - move.startedAt
	local landed = elapsed > 0.2 and not isAirborne(humanoid)
	if landed or elapsed > MoveConfig.DiveMaxTime then
		finishMove("Prone")
		return false
	end
	-- Keep the forward speed; gravity handles the arc
	local vertical = root.AssemblyLinearVelocity.Y
	root.AssemblyLinearVelocity = move.direction * move.speed + Vector3.yAxis * vertical
	humanoid.WalkSpeed = move.speed
	humanoid:Move(move.direction, false)
	return true
end

-- Normal walking/running/crawling, and air control
local function updateWalk(humanoid: Humanoid, root: BasePart, deltaTime: number)
	-- Which way the player is pushing, from Roblox's controls:
	-- X = right/left, Z = back/forward (forward is negative)
	local input = getMoveInput()
	if input.Magnitude > 1 then
		input = input.Unit
	end
	local moving = input.Magnitude > 0.1

	state.sprinting = sprintHeld and moving and not state.aiming and state.stance == "Stand"
	local speed = MoveConfig.WalkSpeed
	if state.stance == "Crouch" then
		speed = MoveConfig.CrouchSpeed
	elseif state.stance == "Prone" then
		speed = MoveConfig.ProneSpeed
	elseif state.sprinting then
		speed = MoveConfig.SprintSpeed
	end
	if state.aiming then
		speed *= Config.Ads.MoveSpeedMultiplier
	end

	-- Turn the input into a world direction relative to where the camera faces
	local look = workspace.CurrentCamera.CFrame.LookVector * FLAT
	local forward = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local right = forward:Cross(Vector3.yAxis)
	local wanted = forward * (-input.Z * speed) + right * (input.X * speed * MoveConfig.StrafeMultiplier)

	local velocity = root.AssemblyLinearVelocity
	local horizontal = velocity * FLAT
	local onGround = not isAirborne(humanoid)
	local newHorizontal
	if onGround then
		-- Instant: no speeding up or sliding to a stop, so A-D reversals are snappy
		newHorizontal = wanted
	else
		-- In the air you can only nudge your momentum a little
		local change = wanted - horizontal
		local maxChange = MoveConfig.AirAcceleration * deltaTime
		if change.Magnitude > maxChange then
			change = change.Unit * maxChange
		end
		newHorizontal = horizontal + change
	end

	root.AssemblyLinearVelocity = newHorizontal + Vector3.yAxis * velocity.Y
	-- Tell the humanoid the same thing so it doesn't fight us
	humanoid.WalkSpeed = newHorizontal.Magnitude
	humanoid:Move(if newHorizontal.Magnitude > 0.01 then newHorizontal.Unit else Vector3.zero, false)
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

	local busy = false
	if slide then
		busy = updateSlide(humanoid, root, deltaTime)
	elseif dive then
		busy = updateDive(humanoid, root, deltaTime)
	end
	if not busy then
		updateWalk(humanoid, root, deltaTime)
	end

	-- Jumping only from standing (Space from crouch/prone stands you up instead)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, state.stance == "Stand" and not jumpBlocked)

	-- Smoothly move the gun to/from the sights, and zoom the camera to match
	state.aimAmount = moveToward(state.aimAmount, if state.aiming then 1 else 0, deltaTime / Config.Ads.TransitionTime)
	local targetFov = MoveConfig.BaseFov - Config.Ads.FovReduction * state.aimAmount
	if state.sprinting then
		targetFov += MoveConfig.SprintFovKick
	elseif slide or dive then
		targetFov += MoveConfig.SlideFovKick
	end
	currentFov += (targetFov - currentFov) * math.min(deltaTime * 10, 1)
	workspace.CurrentCamera.FieldOfView = currentFov
end

local function onCharacterAdded(character: Model)
	-- Fresh start on respawn (the server's attributes reset with the new character)
	if slide or dive then
		slide = nil
		dive = nil
		setControlsEnabled(true)
	end
	state.stance = "Stand"
	state.aiming = false
	jumpBlocked = false

	-- Sprint jump: keep sprint speed into the air and add a forward push
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.StateChanged:Connect(function(_, newState)
		local root = humanoid.RootPart
		if newState == Enum.HumanoidStateType.Jumping and state.sprinting and root then
			local horizontal = root.AssemblyLinearVelocity * FLAT
			if horizontal.Magnitude > 0.1 then
				root.AssemblyLinearVelocity += horizontal.Unit * MoveConfig.SprintJumpBoost
			end
		end
	end)
end

function Movement.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- Roblox's controls already use Space (for jumping), which marks it
		-- "processed", so we check it before that filter; just not while typing in chat.
		if input.KeyCode == Enum.KeyCode.Space and not UserInputService:GetFocusedTextBox() then
			onJumpKey()
			return
		end
		if gameProcessed then
			return
		end
		if CROUCH_KEYS[input.KeyCode] then
			onCrouchKey()
		elseif input.KeyCode == Enum.KeyCode.Z then
			onProneKey()
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			sprintHeld = true
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			setAiming(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			sprintHeld = false
		elseif input.KeyCode == Enum.KeyCode.Space then
			jumpBlocked = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			setAiming(false)
		end
	end)

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

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
end

return Movement
