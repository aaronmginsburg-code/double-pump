-- Bends R15 characters into poses procedurally (no animation assets).
-- Runs every frame on the server AND on every client, for every player
-- character, reading the "Stance" attribute the server puts on the character:
--   "Stand", "Crouch", "Prone", "Slide" or "Dive"
--
-- Running it on the server matters: the server checks shots against its own
-- copy of each body part, so a crouched or prone player really is smaller there too.
--
-- How it works: each R15 joint has a Transform, the rotation that animations
-- set. Every frame we blend that toward our pose. Older rigs use Motor6D
-- joints; newer Studio avatars use AnimationConstraint joints with the same
-- names, and both work here. The owning client also lowers Humanoid.HipHeight
-- (and the camera) so the body sits on the floor.
--
-- On top of the stance there is always a "hold" pose: both arms forward, as
-- if holding the shotgun, so the gun in your hands points where you aim.

local Config = require(script.Parent.Config)
local Movement = Config.Movement
local Anim = Config.Animation

local Pose = {}

-- Joint name -> the body part it lives in
local JOINTS = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	LeftHip = "LeftUpperLeg",
	RightHip = "RightUpperLeg",
	LeftKnee = "LeftLowerLeg",
	RightKnee = "RightLowerLeg",
	LeftAnkle = "LeftFoot",
	RightAnkle = "RightFoot",
	LeftShoulder = "LeftUpperArm",
	RightShoulder = "RightUpperArm",
	LeftElbow = "LeftLowerArm",
	RightElbow = "RightLowerArm",
}

-- Rotating a joint around X by a positive angle swings a limb forward
-- (or leans the body back); negative leans forward. Angles are in degrees.
local function bend(degrees: number): CFrame
	return CFrame.Angles(math.rad(degrees), 0, 0)
end

-- An arm raised by `pitch` (90 = straight ahead) and swung sideways by `inward`
local function arm(pitch: number, inward: number): CFrame
	return CFrame.Angles(math.rad(pitch), 0, math.rad(inward))
end

-- Always on (for players): arms holding the gun at the hip, blending to
-- aiming down sights. The left arm swings in toward the middle to reach the pump.
-- Right arm: negative inward swings it toward the middle; left arm: positive.
local function holdPose(aim: number): { [string]: CFrame }
	local pitch = Anim.HoldArmPitch + (Anim.AdsArmPitch - Anim.HoldArmPitch) * aim
	return {
		RightShoulder = arm(pitch, -5 - Anim.AdsArmInward * aim),
		LeftShoulder = arm(pitch - 5, 30 + 10 * aim),
		RightElbow = bend(Anim.AdsElbowBend * aim),
		LeftElbow = bend(Anim.AdsElbowBend * 0.4 * aim),
		Neck = CFrame.Angles(math.rad(-Anim.AdsHeadTilt * aim), 0, math.rad(-Anim.AdsHeadTilt * 0.5 * aim)),
	}
end

local thigh, knee = Movement.CrouchThighAngle, Movement.CrouchKneeAngle

-- Crouch, with a walking step cycle. `phase` advances as you move; `amount`
-- (0..1) is how much you're moving, so standing still is the plain crouch.
local function crouchPose(phase: number, amount: number): { [string]: CFrame }
	local swing = math.sin(phase) * Anim.CrouchLegSwing * amount
	local leftHip, rightHip = thigh + swing, thigh - swing
	-- The leg swinging forward lifts its foot by bending the knee more
	local leftKnee = knee + Anim.CrouchKneeLift * amount * math.max(math.cos(phase), 0)
	local rightKnee = knee + Anim.CrouchKneeLift * amount * math.max(-math.cos(phase), 0)
	return {
		Waist = bend(-Movement.CrouchLean),
		LeftHip = bend(leftHip),
		RightHip = bend(rightHip),
		LeftKnee = bend(-leftKnee),
		RightKnee = bend(-rightKnee),
		LeftAnkle = bend(leftKnee - leftHip), -- keeps the feet flat on the floor
		RightAnkle = bend(rightKnee - rightHip),
	}
end

-- Belly down: tip the whole body forward 90 degrees and lower it to the floor,
-- lift the chest a little, arms out ahead. While moving it's a commando crawl:
-- the arms take turns reaching forward and the knees take turns pulling up to
-- the side. `yaw` turns the body toward a sideways crawl.
local function pronePose(phase: number, amount: number, yaw: number): { [string]: CFrame }
	local s = math.sin(phase) * amount
	local reach = Anim.CrawlArmReach * s
	local pull = Anim.CrawlLegPull * amount
	return {
		Root = CFrame.new(0, -Movement.ProneBodyDrop, 0) * CFrame.Angles(0, yaw, 0) * bend(-90),
		Waist = bend(25),
		LeftHip = CFrame.Angles(math.rad(-5), 0, math.rad(-pull * math.max(s, 0))),
		RightHip = CFrame.Angles(math.rad(-5), 0, math.rad(pull * math.max(-s, 0))),
		LeftKnee = bend(-1.5 * pull * math.max(s, 0)),
		RightKnee = bend(-1.5 * pull * math.max(-s, 0)),
		LeftShoulder = arm(165 - reach, 15),
		RightShoulder = arm(165 + reach, -5),
		LeftElbow = bend(20 + reach),
		RightElbow = bend(20 - reach),
	}
end

-- Feet-first slide: lean the body back, swing the legs forward until they
-- lie along the floor, tuck the right knee, and curl the head up to see.
local SLIDE_POSE = {
	Root = bend(Movement.SlideLean),
	Waist = bend(-20),
	LeftHip = bend(90 - Movement.SlideLean),
	RightHip = bend(90 - Movement.SlideLean - 20),
	LeftKnee = bend(-10),
	RightKnee = bend(-70),
}

-- Dolphin dive: nearly flat, chest first, legs trailing up behind
local DIVE_POSE = {
	Root = bend(-75),
	Waist = bend(15),
	LeftHip = bend(-20),
	RightHip = bend(-20),
	LeftKnee = bend(-30),
	RightKnee = bend(-30),
	LeftShoulder = arm(165, 15),
	RightShoulder = arm(165, -5),
}

local STANCE_NAMES = { "Crouch", "Slide", "Prone", "Dive" }

-- Getting down to / up from the floor is slower than crouching
local TRANSITION_TIMES = {
	Crouch = Movement.PoseTransitionTime,
	Slide = Movement.PoseTransitionTime,
	Prone = Movement.ProneTransitionTime,
	Dive = Movement.PoseTransitionTime,
}

type State = {
	weights: { [string]: number }, -- 0..1 how far into each stance pose
	joints: { [string]: Joint },
	posed: { [string]: boolean }, -- joints we overrode last frame
	standHipHeight: number,
	hipHeights: { [string]: number }, -- HipHeight for each stance
	aim: number, -- 0..1 eases toward aiming down sights
	moveAmount: number, -- 0..1 eases toward "moving"
	phase: number, -- walk / crawl cycle, in radians
	crawlYaw: number, -- radians the prone body is turned toward a sideways crawl
	swapStartedAt: number, -- when the last swap animation began
	slot: any, -- the equipped slot we last saw (EquippedSlot attribute)
}

-- Motor6D (older rigs) or AnimationConstraint (newer avatars); both have Transform
type Joint = any

local function isJoint(instance: Instance?): boolean
	return instance ~= nil and (instance:IsA("Motor6D") or instance:IsA("AnimationConstraint"))
end

-- Where a joint sits in its parent part (C0) and in its child part (C1)
local function jointOffsets(joint: Joint): (CFrame, CFrame)
	if joint:IsA("Motor6D") then
		return joint.C0, joint.C1
	end
	local a0, a1 = joint.Attachment0, joint.Attachment1
	return if a0 then a0.CFrame else CFrame.identity, if a1 then a1.CFrame else CFrame.identity
end

-- character -> State. Weak keys: entries vanish when a character is destroyed.
local states: { [Model]: State } = setmetatable({}, { __mode = "k" }) :: any

local function setup(character: Model): State?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local joints = {}
	for jointName, partName in JOINTS do
		local part = character:FindFirstChild(partName)
		local joint = part and part:FindFirstChild(jointName)
		if not isJoint(joint) then
			return nil -- not an R15 rig (or still loading)
		end
		joints[jointName] = joint
	end

	-- Measure the legs so the crouch drop matches the bent-knee pose:
	-- a bent thigh/shin covers less height than a straight one.
	local _, hipInThigh = jointOffsets(joints.LeftHip)
	local kneeInThigh, kneeInShin = jointOffsets(joints.LeftKnee)
	local ankleInShin = jointOffsets(joints.LeftAnkle)
	local thighLength = (hipInThigh.Position - kneeInThigh.Position).Magnitude
	local shinLength = (kneeInShin.Position - ankleInShin.Position).Magnitude
	local shinAngle = knee - thigh -- how far the shin tilts back from straight down
	local crouchDrop = thighLength * (1 - math.cos(math.rad(thigh))) + shinLength * (1 - math.cos(math.rad(shinAngle)))

	local stand = humanoid.HipHeight
	local state: State = {
		weights = { Crouch = 0, Slide = 0, Prone = 0, Dive = 0 },
		joints = joints,
		posed = {},
		standHipHeight = stand,
		hipHeights = {
			Crouch = stand - crouchDrop,
			Slide = Movement.SlideHipHeight,
			Prone = Movement.ProneHipHeight,
			Dive = Movement.ProneHipHeight,
		},
		aim = 0,
		moveAmount = 0,
		phase = 0,
		crawlYaw = 0,
		swapStartedAt = -math.huge,
		slot = character:GetAttribute("EquippedSlot"),
	}
	states[character] = state
	return state
end

local function moveToward(current: number, target: number, step: number): number
	if current < target then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end

-- Walk / crawl cycle and the prone body's turn, from how the character is
-- actually moving (works for every character, on every machine)
local function updateMotion(state: State, character: Model, stance: string, deltaTime: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local velocity = if root then root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity) else Vector3.zero
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = flat.Magnitude
	local moving = speed > 0.5
	state.moveAmount = moveToward(state.moveAmount, if moving then 1 else 0, deltaTime / 0.15)

	-- Moving backward plays the cycle in reverse
	local backward = velocity.Z > 0.5 and math.abs(velocity.Z) >= math.abs(velocity.X)
	local direction = if backward then -1 else 1
	local cyclesPerStud = if stance == "Prone" then Anim.CrawlCyclesPerStud else Anim.CrouchStepsPerStud
	state.phase = (state.phase + speed * cyclesPerStud * 2 * math.pi * deltaTime * direction) % (2 * math.pi)

	-- Prone: turn the body toward a sideways crawl (head leads), never past
	-- CrawlTurnAngle; crawling backward stays facing forward.
	local targetYaw = 0
	if stance == "Prone" and moving and not backward then
		local yaw = math.atan2(-flat.X, -flat.Z)
		local limit = math.rad(Anim.CrawlTurnAngle)
		targetYaw = math.clamp(yaw, -limit, limit)
	end
	local turnStep = math.rad(Anim.CrawlTurnAngle) * deltaTime / Anim.CrawlTurnTime
	state.crawlYaw = moveToward(state.crawlYaw, targetYaw, turnStep)
end

-- Starts the swap animation (the owning client calls this the moment you swap;
-- everyone else sees it when the server's EquippedSlot attribute changes)
function Pose.playSwap(character: Model)
	local state = states[character]
	if state then
		state.swapStartedAt = os.clock()
	end
end

-- 0..1..0 over a swap: the arms dip the gun down, then bring it back up
local function swapAmount(state: State): number
	local t = (os.clock() - state.swapStartedAt) / Anim.SwapTime
	return if t >= 0 and t < 1 then math.sin(t * math.pi) else 0
end

-- Call every frame (RunService.Stepped) for each player character.
--   stance:      "Stand", "Crouch", "Prone", "Slide" or "Dive"
--   isOwner:     true only on the client that controls this character
--                (it also moves HipHeight and the camera)
--   onServer:    the server has no animations, so it poses from a neutral base
--   aiming:      aiming down sights
function Pose.step(character: Model, stance: string, deltaTime: number, isOwner: boolean, onServer: boolean, aiming: boolean)
	local state = states[character]
	if state and state.joints.Root.Parent == nil then
		-- The joints were replaced (the server swaps physics joints for Motor6Ds)
		state = nil
	end
	state = state or setup(character)
	if not state then
		return
	end

	-- Ease each stance weight toward 1 (current stance) or 0 (others)
	local total = 0
	for _, name in STANCE_NAMES do
		local target = if stance == name then 1 else 0
		state.weights[name] = moveToward(state.weights[name], target, deltaTime / TRANSITION_TIMES[name])
		total += state.weights[name]
	end
	local stanceWeight = math.min(total, 1)

	state.aim = moveToward(state.aim, if aiming then 1 else 0, deltaTime / Config.Ads.TransitionTime)
	updateMotion(state, character, stance, deltaTime)

	-- Other players' swaps arrive as a change to the server's attribute
	local slot = character:GetAttribute("EquippedSlot")
	if slot ~= state.slot then
		state.slot = slot
		if not isOwner then
			state.swapStartedAt = os.clock()
		end
	end
	local swapDip = bend(-Anim.SwapDropAngle * swapAmount(state))

	local hold = holdPose(state.aim)
	local poses = {
		Crouch = crouchPose(state.phase, state.moveAmount),
		Slide = SLIDE_POSE,
		Prone = pronePose(state.phase, state.moveAmount, state.crawlYaw),
		Dive = DIVE_POSE,
	}

	for jointName, joint in state.joints do
		local holdTarget = hold[jointName]
		local base = holdTarget or CFrame.identity

		-- Weighted average of the active stance poses for this joint
		-- (a stance that doesn't list this joint counts as the base pose)
		local target = base
		local accumulated = 0
		for _, name in STANCE_NAMES do
			local weight = state.weights[name]
			if weight > 0 then
				accumulated += weight
				target = target:Lerp(poses[name][jointName] or base, weight / accumulated)
			end
		end

		-- How strongly we override the animation for this joint
		local influence
		if holdTarget then
			target = base:Lerp(target, stanceWeight)
			influence = 1
		else
			influence = stanceWeight
		end

		-- Swapping dips both arms, whatever the stance
		if jointName == "RightShoulder" or jointName == "LeftShoulder" then
			target *= swapDip
		end

		if influence > 0 then
			local animation = if onServer then CFrame.identity else joint.Transform
			joint.Transform = animation:Lerp(target, influence)
			state.posed[jointName] = true
		elseif state.posed[jointName] then
			-- Back to standing: hand this joint back to the normal animations
			joint.Transform = CFrame.identity
			state.posed[jointName] = nil
		end
	end

	if isOwner then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- Blend HipHeight and the camera offset the same way as the poses
			local height = state.standHipHeight
			for name, weight in state.weights do
				height += weight * (state.hipHeights[name] - state.standHipHeight)
			end
			humanoid.HipHeight = height

			local lyingDown = state.weights.Prone + state.weights.Dive
			humanoid.CameraOffset = Vector3.new(0, -Movement.ProneCameraDrop, -Movement.ProneCameraForward) * lyingDown
		end
	end
end

-- 0..1 how far into a stance pose a character is (e.g. for camera tilt)
function Pose.getWeight(character: Model, stance: string): number
	local state = states[character]
	return if state then state.weights[stance] or 0 else 0
end

return Pose
