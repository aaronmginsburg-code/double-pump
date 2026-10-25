--!strict
-- Each client renders locally observed movement for every character. No remotes,
-- position/velocity writes, or changes to the movement controller. Engine Running
-- and Landing are muted locally so approved one-shots replace, never layer.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cues = require(ReplicatedStorage.Shared.Audio.MovementCues)
local Audio = require(script.Parent.AudioController)

local MovementAudio = {}
local records: { [Player]: any } = {}
local started = false

local function dispose(record: any)
	for _, connection in record.connections do
		connection:Disconnect()
	end
end

local function bind(player: Player, character: Model): any
	local record: any = {
		character = character,
		state = Cues.new(),
		previous = nil,
		revision = nil,
		connections = {},
		defaults = {},
	}
	local function mute(item: Instance)
		if not item:IsA("Sound") or (item.Name ~= "Running" and item.Name ~= "Landing") then
			return
		end
		local name = item.Name
		local mix = {
			volume = item.Volume,
			minimum = item.RollOffMinDistance,
			maximum = item.RollOffMaxDistance,
			mode = item.RollOffMode,
		}
		record.defaults[name] = mix
		table.insert(
			record.connections,
			item:GetPropertyChangedSignal("Volume"):Connect(function()
				if item.Volume ~= 0 then
					mix.volume = item.Volume
					item.Volume = 0
				end
			end)
		)
		item.Volume = 0
	end
	for _, item in character:GetDescendants() do
		mute(item)
	end
	table.insert(record.connections, character.DescendantAdded:Connect(mute))
	records[player] = record
	return record
end

local function update(player: Player, record: any, dt: number, excluded: { Instance })
	local character = record.character :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end
	local revision = character:GetAttribute("SpawnRevision")
	if record.revision ~= revision then
		record.state, record.previous, record.revision = Cues.new(), nil, revision
	end
	local position = root.Position
	local previous = record.previous or position
	record.previous = position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded
	params.RespectCanCollide = true
	local leg = character:FindFirstChild("Left Leg") :: BasePart?
	local height = root.Size.Y / 2 + humanoid.HipHeight
	if humanoid.RigType == Enum.HumanoidRigType.R6 and leg then
		height += leg.Size.Y
	end
	local floor = workspace:Raycast(position, Vector3.new(0, -height - 0.7, 0), params)
	local state = humanoid:GetState()
	local grounded = floor ~= nil
		and state ~= Enum.HumanoidStateType.Jumping
		and state ~= Enum.HumanoidStateType.Freefall
	local floorVelocity = Vector3.zero
	if floor and floor.Instance:IsA("BasePart") then
		floorVelocity = floor.Instance.AssemblyLinearVelocity
	end
	local velocity = root.AssemblyLinearVelocity - floorVelocity
	local delta = position - previous - floorVelocity * dt
	local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local mode = player:GetAttribute("Mode")
	local enabled = (mode == "Practice" or mode == "Match")
		and humanoid.Health > 0
		and character:GetAttribute("Dead") ~= true
		and character:GetAttribute("Frozen") ~= true
		and not root.Anchored
		and (
			state == Enum.HumanoidStateType.Running
			or state == Enum.HumanoidStateType.RunningNoPhysics
			or state == Enum.HumanoidStateType.Landed
			or state == Enum.HumanoidStateType.Jumping
			or state == Enum.HumanoidStateType.Freefall
		)
	local event = Cues.advance(record.state, dt, distance, grounded, speed, velocity.Y, enabled)
	if not event or not floor then
		return
	end
	local cue = if event == "Landing" then "Landing" else Cues.surface(floor.Material.Name)
	if not cue then
		return
	end
	local mix = record.defaults[if event == "Landing" then "Landing" else "Running"]
	-- Wait for the engine sound's audibility settings instead of inventing a range.
	if not mix then
		return
	end
	local sound = Audio.play(cue, { parent = root, volume = mix.volume / 0.65 })
	if sound then
		sound.RollOffMinDistance = mix.minimum
		sound.RollOffMaxDistance = mix.maximum
		sound.RollOffMode = mix.mode
	end
end

function MovementAudio.start()
	if started then
		return
	end
	for _, name in { "StepConcrete", "StepMetal", "StepSand", "StepWood", "Landing" } do
		if not Audio.configured(name) then
			return -- Keep defaults when this replacement set is unavailable.
		end
	end
	started = true
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.05 then
			return
		end
		local step = elapsed
		elapsed = 0
		local excluded: { Instance } = {}
		local active: { [Player]: boolean } = {}
		for _, player in Players:GetPlayers() do
			active[player] = true
			if player.Character then
				table.insert(excluded, player.Character)
			end
		end
		for player, record in records do
			if not active[player] or player.Character ~= record.character then
				dispose(record)
				records[player] = nil
			end
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				update(player, records[player] or bind(player, character), step, excluded)
			end
		end
	end)
end

return MovementAudio
