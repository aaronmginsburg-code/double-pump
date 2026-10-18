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

local Pose = {}

-- Joint name -> the body part it lives in
local JOINTS = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	LeftHip = "LeftUpperLeg",
	RightHip = "RightUpperLeg",
	LeftKnee = "LeftLowerLeg",
	RightKnee = "RightLowerLeg",
	LeftAnkle = "LeftFoot",
	RightAnkle = "RightFoot",
	LeftShoulder = "LeftUpperArm",
	RightShoulder = "RightUpperArm",
}

-- Rotating a joint around X by a positive angle swings a limb forward
-- (or leans the body back); negative leans forward. Angles are in degrees.
local function bend(degrees: number): CFrame
	return CFrame.Angles(math.rad(degrees), 0, 0)
end

-- Always on (for players): arms raised forward to hold the gun.
-- The left arm also swings in toward the middle to reach the pump.
local HOLD_POSE = {
	RightShoulder = CFrame.Angles(math.rad(90), 0, math.rad(-5)),
	LeftShoulder = CFrame.Angles(math.rad(85), 0, math.rad(30)),
}

local thigh, knee = Movement.CrouchThighAngle, Movement.CrouchKneeAngle

-- Stance poses. Joints a pose doesn't list stay at the hold pose / animation.
local POSES = {
	Crouch = {
		Waist = bend(-Movement.CrouchLean),
		LeftHip = bend(thigh),
		RightHip = bend(thigh),
		LeftKnee = bend(-knee),
		RightKnee = bend(-knee),
		LeftAnkle = bend(knee - thigh), -- keeps the feet flat on the floor
		RightAnkle = bend(knee - thigh),
	},
	-- Feet-first slide: lean the body back, swing the legs forward until they
	-- lie along the floor, tuck the right knee, and curl the head up to see.
	Slide = {
		Root = bend(Movement.SlideLean),
		Waist = bend(-20),
		LeftHip = bend(90 - Movement.SlideLean),
		RightHip = bend(90 - Movement.SlideLean - 20),
		LeftKnee = bend(-10),
		RightKnee = bend(-70),
	},
	-- Belly down: tip the whole body forward 90 degrees and lower it to the
	-- floor, lift the chest a little, stretch the arms out ahead.
	Prone = {
		Root = CFrame.new(0, -Movement.ProneBodyDrop, 0) * bend(-90),
		Waist = bend(25),
		LeftHip = bend(-5),
		RightHip = bend(-5),
		LeftShoulder = CFrame.Angles(math.rad(165), 0, math.rad(15)),
		RightShoulder = CFrame.Angles(math.rad(165), 0, math.rad(-5)),
	},
	-- Dolphin dive: nearly flat, chest first, legs trailing up behind
	Dive = {
		Root = bend(-75),
		Waist = bend(15),
		LeftHip = bend(-20),
		RightHip = bend(-20),
		LeftKnee = bend(-30),
		RightKnee = bend(-30),
		LeftShoulder = CFrame.Angles(math.rad(165), 0, math.rad(15)),
		RightShoulder = CFrame.Angles(math.rad(165), 0, math.rad(-5)),
	},
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

-- Call every frame (RunService.Stepped) for each player character.
--   stance:      "Stand", "Crouch", "Prone", "Slide" or "Dive"
--   isOwner:     true only on the client that controls this character
--                (it also moves HipHeight and the camera)
--   onServer:    the server has no animations, so it poses from a neutral base
function Pose.step(character: Model, stance: string, deltaTime: number, isOwner: boolean, onServer: boolean)
	local state = states[character] or setup(character)
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

	for jointName, joint in state.joints do
		local holdTarget = HOLD_POSE[jointName]
		local base = holdTarget or CFrame.identity

		-- Weighted average of the active stance poses for this joint
		-- (a stance that doesn't list this joint counts as the base pose)
		local target = base
		local accumulated = 0
		for _, name in STANCE_NAMES do
			local weight = state.weights[name]
			if weight > 0 then
				accumulated += weight
				target = target:Lerp(POSES[name][jointName] or base, weight / accumulated)
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
