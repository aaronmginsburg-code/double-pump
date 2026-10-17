-- Bends R15 characters into crouch and slide poses, procedurally (no animation
-- assets). Runs every frame on the server AND on every client, for every
-- player character, reading the "Stance" attribute the server puts on the
-- character ("Stand", "Crouch" or "Slide").
--
-- Running it on the server matters: the server checks shots against its own
-- copy of each body part, so a crouched player's head really is lower there too.
--
-- How it works: each R15 joint (Motor6D) has a Transform, the rotation
-- animations set. We blend that toward our pose every frame. The owning
-- client also lowers Humanoid.HipHeight so the whole body (and camera) drops
-- to match the bent legs.

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
}

-- Rotating a joint around X by a positive angle swings the limb forward
-- (or leans the body back). Angles are in degrees.
local function bend(degrees: number): CFrame
	return CFrame.Angles(math.rad(degrees), 0, 0)
end

local thigh, knee = Movement.CrouchThighAngle, Movement.CrouchKneeAngle
local CROUCH_POSE = {
	Waist = bend(-Movement.CrouchLean),
	LeftHip = bend(thigh),
	RightHip = bend(thigh),
	LeftKnee = bend(-knee),
	RightKnee = bend(-knee),
	LeftAnkle = bend(knee - thigh), -- keeps the feet flat on the floor
	RightAnkle = bend(knee - thigh),
}

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

type State = {
	crouch: number, -- 0..1 how far into the crouch pose
	slide: number, -- 0..1 how far into the slide pose
	joints: { [string]: Motor6D },
	standHipHeight: number,
	crouchDrop: number, -- how much lower the hips sit when fully crouched
	posed: boolean,
}

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
		if not joint or not joint:IsA("Motor6D") then
			return nil -- not an R15 rig (or still loading)
		end
		joints[jointName] = joint
	end

	-- Measure the legs so the crouch drop matches the bent-knee pose:
	-- a bent thigh/shin covers less height than a straight one.
	local thighLength = (joints.LeftHip.C1.Position - joints.LeftKnee.C0.Position).Magnitude
	local shinLength = (joints.LeftKnee.C1.Position - joints.LeftAnkle.C0.Position).Magnitude
	local shinAngle = knee - thigh -- how far the shin tilts back from straight down
	local crouchDrop = thighLength * (1 - math.cos(math.rad(thigh))) + shinLength * (1 - math.cos(math.rad(shinAngle)))

	local state: State = {
		crouch = 0,
		slide = 0,
		joints = joints,
		standHipHeight = humanoid.HipHeight,
		crouchDrop = crouchDrop,
		posed = false,
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

-- Call every frame (RunService.Stepped) for each character.
--   stance:         "Stand", "Crouch" or "Slide"
--   ownsHipHeight:  true only on the client that controls this character
--   onServer:       the server has no animations, so it poses from a neutral base
function Pose.step(character: Model, stance: string, deltaTime: number, ownsHipHeight: boolean, onServer: boolean)
	local state = states[character] or setup(character)
	if not state then
		return
	end

	local step = deltaTime / Movement.PoseTransitionTime
	state.crouch = moveToward(state.crouch, if stance == "Crouch" then 1 else 0, step)
	state.slide = moveToward(state.slide, if stance == "Slide" then 1 else 0, step)
	local weight = math.min(state.crouch + state.slide, 1)

	if weight <= 0 then
		-- Fully standing: hand the joints back to the normal animations
		if state.posed then
			state.posed = false
			for _, joint in state.joints do
				joint.Transform = CFrame.identity
			end
			if ownsHipHeight then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.HipHeight = state.standHipHeight
				end
			end
		end
		return
	end
	state.posed = true

	-- How much of the target pose is slide vs crouch (while blending between them)
	local slideShare = state.slide / (state.crouch + state.slide)
	for jointName, joint in state.joints do
		local crouchTarget = CROUCH_POSE[jointName] or CFrame.identity
		local slideTarget = SLIDE_POSE[jointName] or CFrame.identity
		local target = crouchTarget:Lerp(slideTarget, slideShare)
		local base = if onServer then CFrame.identity else joint.Transform -- this frame's animation
		joint.Transform = base:Lerp(target, weight)
	end

	if ownsHipHeight then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local crouchHeight = state.standHipHeight - state.crouchDrop * state.crouch
			humanoid.HipHeight = crouchHeight + (Movement.SlideHipHeight - crouchHeight) * state.slide
		end
	end
end

-- 0..1 how far into the slide pose a character is (for camera tilt)
function Pose.getSlideAmount(character: Model): number
	local state = states[character]
	return if state then state.slide else 0
end

return Pose
