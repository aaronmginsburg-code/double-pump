--!strict
-- Player characters: spawning at a chosen CFrame, health, movement stats, crouch,
-- aim pitch, the third-person shotgun on the body, spawn protection, death ragdoll.
-- Characters are spawned manually (Players.CharacterAutoLoads = false) by MatchService.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Collision = require(Shared.Collision)
local Combatants = require(Shared.Combatants)
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)
local RateLimiter = require(Shared.Util.RateLimiter)
local ShotgunModel = require(Shared.Weapons.ShotgunModel)
local Signal = require(Shared.Util.Signal)

local CharacterService = {}

CharacterService.Spawned = Signal.new() :: Signal.Signal<Player, Model>
CharacterService.Died = Signal.new() :: Signal.Signal<Player, Model>

local pendingSpawn: { [Player]: CFrame } = {}
local limiter = RateLimiter.new(GameConfig.Network.GeneralBurst * 3, GameConfig.Network.LookUpdateRate + 4)
local skinProvider: ((Player) -> any)? = nil

local MOUNT_C0 = CFrame.new(0.45, 0.25, -0.55) -- right of the chest, from UpperTorso centre

local function setupHumanoid(humanoid: Humanoid)
	local move = GameConfig.Movement
	humanoid.MaxHealth = GameConfig.Player.MaxHealth
	humanoid.Health = GameConfig.Player.MaxHealth
	humanoid.WalkSpeed = move.WalkSpeed
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = move.JumpHeight
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	-- Hard crouch/swim/climb states we don't use
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
end

-- Newer avatars can use AnimationConstraint physics joints; swap to classic Motor6Ds so
-- poses (crouch, aim) and hit boxes behave the same on every client and the server.
local function useClassicJoints(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("AnimationConstraint") then
			local a0, a1 = d.Attachment0, d.Attachment1
			local p0 = a0 and a0.Parent
			local p1 = a1 and a1.Parent
			if a0 and a1 and p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				local motor = Instance.new("Motor6D")
				motor.Name = d.Name
				motor.Part0 = p0
				motor.Part1 = p1
				motor.C0 = a0.CFrame
				motor.C1 = a1.CFrame
				motor.Parent = d.Parent
				d:Destroy()
			end
		elseif d:IsA("BallSocketConstraint") and not d:FindFirstAncestorOfClass("Accessory") then
			d:Destroy()
		end
	end
end

local function prepareBody(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "HumanoidRootPart" then
				d.CollisionGroup = Collision.ROOT
			elseif d:FindFirstAncestorOfClass("Accessory") then
				-- Hats and hair don't block pellets and have no hit zone
				d.CanQuery = false
				d.CanTouch = false
			end
		end
	end
end

-- The third-person shotgun (what other players see), on a Motor6D from the chest so
-- each client can tilt it with the aim pitch.
local function mountWorldGun(player: Player, character: Model)
	local upperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not upperTorso or not upperTorso:IsA("BasePart") then
		return
	end
	local gun = ShotgunModel.new("ThirdPerson")
	if skinProvider then
		gun:applySkin(skinProvider(player))
	end
	local rootPart = gun:weldForThirdPerson()
	gun:syncRoot()
	gun.model.Name = "WorldShotgun"
	-- Place the gun so the Grip point is at the mount, muzzle forward
	local gripOffset = gun.root:ToObjectSpace(gun:point("Grip"))
	local rootToPart = gun.root:ToObjectSpace(rootPart.CFrame)
	local motor = Instance.new("Motor6D")
	motor.Name = "GunMount"
	motor.Part0 = upperTorso
	motor.Part1 = rootPart
	motor.C0 = MOUNT_C0
	motor.C1 = rootToPart:Inverse() * gripOffset
	motor.Parent = rootPart
	for _, d in gun.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
			d.CanCollide = false
			d.Massless = true
		end
	end
	gun.model.Parent = character

	-- Hands on the gun, solved on every client by Roblox's IK
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local function addIK(name: string, chainRoot: string, effector: string, pointName: string)
		local root = character:FindFirstChild(chainRoot)
		local hand = character:FindFirstChild(effector)
		if not (humanoid and root and hand) then
			return
		end
		local target = Instance.new("Attachment")
		target.Name = pointName .. "Target"
		target.WorldCFrame = gun:point(pointName)
		target.Parent = rootPart
		local ik = Instance.new("IKControl")
		ik.Name = name
		ik.Type = Enum.IKControlType.Position
		ik.ChainRoot = root :: Instance
		ik.EndEffector = hand :: Instance
		ik.Target = target
		ik.Weight = 1
		ik.Parent = humanoid
	end
	addIK("RightHandIK", "RightUpperArm", "RightHand", "Grip")
	addIK("LeftHandIK", "LeftUpperArm", "LeftHand", "SupportHand")
end

-- Death presentation: the body goes limp (ball sockets at each joint) and stops blocking shots.
local function ragdoll(character: Model)
	for _, motor in character:GetDescendants() do
		if motor:IsA("Motor6D") and motor.Name ~= "GunMount" and motor.Name ~= "RootJoint" and motor.Name ~= "Root" then
			local p0, p1 = motor.Part0, motor.Part1
			if p0 and p1 then
				local a0 = Instance.new("Attachment")
				a0.CFrame = motor.C0
				a0.Parent = p0
				local a1 = Instance.new("Attachment")
				a1.CFrame = motor.C1
				a1.Parent = p1
				local socket = Instance.new("BallSocketConstraint")
				socket.Attachment0 = a0
				socket.Attachment1 = a1
				socket.LimitsEnabled = true
				socket.TwistLimitsEnabled = true
				socket.UpperAngle = 60
				socket.Parent = p1
				motor.Enabled = false
			end
		end
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
			if
				d.Name ~= "HumanoidRootPart"
				and not d:FindFirstAncestorOfClass("Accessory")
				and not d:FindFirstAncestor("WorldShotgun")
			then
				d.CanCollide = true
				d.CollisionGroup = Collision.EFFECTS
			end
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.CanCollide = false
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local spawnAt = pendingSpawn[player]
	pendingSpawn[player] = nil
	if spawnAt then
		character:PivotTo(spawnAt)
	end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	character:WaitForChild("HumanoidRootPart", 10)
	useClassicJoints(character)
	setupHumanoid(humanoid)
	prepareBody(character)
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d:FindFirstAncestorOfClass("Accessory") then
			d.CanQuery = false
			d.CanTouch = false
		end
	end)
	if player.Team then
		character:SetAttribute("Team", player.Team.Name)
	end
	character:SetAttribute("EquippedSlot", 1)
	character:SetAttribute("AimPitch", 0)
	CollectionService:AddTag(character, Combatants.TAG)
	CharacterService.protect(character, GameConfig.Player.SpawnProtection)
	task.defer(mountWorldGun, player, character)

	humanoid.Died:Once(function()
		character:SetAttribute("Dead", true)
		ragdoll(character)
		CharacterService.Died:Fire(player, character)
	end)
	CharacterService.Spawned:Fire(player, character)
end

function CharacterService.protect(character: Model, duration: number)
	local untilTime = workspace:GetServerTimeNow() + duration
	character:SetAttribute("ProtectedUntil", untilTime)
end

function CharacterService.isProtected(character: Model): boolean
	local untilTime = character:GetAttribute("ProtectedUntil")
	return typeof(untilTime) == "number" and workspace:GetServerTimeNow() < untilTime
end

function CharacterService.endProtection(character: Model)
	character:SetAttribute("ProtectedUntil", 0)
end

-- Spawns (or respawns) a player's character at `cframe`.
function CharacterService.spawn(player: Player, cframe: CFrame)
	if not player.Parent then
		return
	end
	pendingSpawn[player] = cframe + Vector3.new(0, 3, 0)
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
	end)
	if not ok then
		warn(`[Double Pump] couldn't spawn {player.Name}: {err}`)
	end
end

function CharacterService.despawn(player: Player)
	pendingSpawn[player] = nil
	local character = player.Character
	if character then
		player.Character = nil
		character:Destroy()
	end
end

function CharacterService.setFrozen(character: Model, frozen: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	character:SetAttribute("Frozen", frozen)
	if humanoid then
		local crouching = character:GetAttribute("Crouching") == true
		humanoid.WalkSpeed = if frozen
			then 0
			elseif crouching then GameConfig.Movement.CrouchSpeed
			else GameConfig.Movement.WalkSpeed
		humanoid.JumpHeight = if frozen then 0 else GameConfig.Movement.JumpHeight
	end
end

function CharacterService.setSkinProvider(fn: (Player) -> any)
	skinProvider = fn
end

local function onPlayerAction(player: Player, action: any, value: any)
	if not limiter:allow(player, os.clock()) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	if action == "Crouch" and typeof(value) == "boolean" then
		if character:GetAttribute("Crouching") == value then
			return
		end
		character:SetAttribute("Crouching", value)
		if character:GetAttribute("Frozen") ~= true then
			humanoid.WalkSpeed = if value then GameConfig.Movement.CrouchSpeed else GameConfig.Movement.WalkSpeed
		end
	elseif action == "Look" and typeof(value) == "number" and value == value then
		character:SetAttribute("AimPitch", math.clamp(value, -1.5, 1.5))
	end
end

function CharacterService.start()
	Players.CharacterAutoLoads = false
	Net.event("PlayerAction").OnServerEvent:Connect(onPlayerAction)
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		pendingSpawn[player] = nil
		limiter:forget(player)
	end)
end

return CharacterService
