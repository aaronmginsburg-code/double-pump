--!strict
-- Visual and audio feedback for shooting: muzzle flash, smoke, pellet tracers, impacts,
-- shell casings, and the third-person presentation of other players (gun pitch, crouch
-- legs, swap dip, pump animation, their shots). Kept light: pooled parts, short lifetimes,
-- and a "reduced effects" setting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local AnimPlayer = require(Shared.Weapons.AnimPlayer)
local Collision = require(Shared.Collision)
local Combatants = require(Shared.Combatants)
local Net = require(Shared.Net)
local ShotgunModel = require(Shared.Weapons.ShotgunModel)
local Spread = require(Shared.Weapons.Spread)
local WeaponConfig = require(Shared.Config.WeaponConfig)

local AudioController = require(script.Parent.AudioController)
local Settings = require(script.Parent.Settings)
local ViewmodelController = require(script.Parent.ViewmodelController)
local WeaponController = require(script.Parent.WeaponController)

local EffectsController = {}

local player = Players.LocalPlayer
local folder: Folder
local holePool: { BasePart } = {}
local holeIndex = 0
local MAX_HOLES = 60

---------------------------------------------------------------------------------------
-- Building blocks

local function effectPart(size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function fadeOut(part: BasePart, time: number)
	TweenService:Create(part, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
	Debris:AddItem(part, time + 0.05)
end

local function burst(at: CFrame, color: ColorSequence, count: number, speed: NumberRange, size: number, lifetime: number, texture: string?)
	local attachment = Instance.new("Attachment")
	attachment.WorldCFrame = at
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = color
	emitter.Speed = speed
	emitter.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Drag = 4
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.LightEmission = 0.4
	emitter.Rate = 0
	emitter.EmissionDirection = Enum.NormalId.Front
	if texture then
		emitter.Texture = texture
	end
	emitter.Parent = attachment
	emitter:Emit(count)
	Debris:AddItem(attachment, lifetime + 0.2)
end

local SPARK = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 140, 40))
local DUST = ColorSequence.new(Color3.fromRGB(190, 175, 150), Color3.fromRGB(120, 110, 95))
local HIT = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 70, 70))
local SMOKE = ColorSequence.new(Color3.fromRGB(210, 210, 210), Color3.fromRGB(150, 150, 150))

local METALLIC: { [Enum.Material]: boolean } = {
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.CorrodedMetal] = true,
	[Enum.Material.Foil] = true,
}

local function muzzleFlash(at: CFrame, big: boolean)
	local reduced = Settings.values.reducedEffects
	local flash = effectPart(Vector3.new(0.5, 0.5, 0.9) * (if big then 1 else 0.8), Color3.fromRGB(255, 200, 110))
	flash.Shape = Enum.PartType.Ball
	flash.CFrame = at * CFrame.new(0, 0, -0.35) * CFrame.Angles(0, 0, math.random() * math.pi)
	flash.Transparency = 0.15
	flash.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 110)
	light.Range = 14
	light.Brightness = 3
	light.Shadows = false
	light.Parent = flash
	fadeOut(flash, 0.06)
	if not reduced then
		burst(at, SMOKE, 4, NumberRange.new(2, 5), 0.5, 0.7)
		burst(at, SPARK, 6, NumberRange.new(20, 35), 0.12, 0.12)
	end
end

local function tracer(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	if length < 1 then
		return
	end
	local part = effectPart(Vector3.new(0.04, 0.04, math.min(length, 40)), Color3.fromRGB(255, 225, 150))
	local dir = (to - from).Unit
	local start = from + dir * math.min(2, length * 0.2)
	local shown = math.min(length, 40)
	part.CFrame = CFrame.lookAt(start + dir * shown / 2, to)
	part.Transparency = 0.35
	part.Parent = folder
	fadeOut(part, 0.07)
end

local function impact(position: Vector3, normal: Vector3, material: Enum.Material?, isCharacter: boolean)
	local at = CFrame.lookAt(position, position + normal)
	if isCharacter then
		burst(at, HIT, 5, NumberRange.new(6, 12), 0.18, 0.25)
		return
	end
	if Settings.values.reducedEffects then
		return
	end
	if material and METALLIC[material] then
		burst(at, SPARK, 5, NumberRange.new(12, 22), 0.1, 0.18)
	else
		burst(at, DUST, 3, NumberRange.new(3, 8), 0.35, 0.5)
	end
	-- Pellet mark, recycled from a small pool
	holeIndex = holeIndex % MAX_HOLES + 1
	local hole = holePool[holeIndex]
	if not hole then
		local newHole = effectPart(Vector3.new(0.14, 0.14, 0.02), Color3.fromRGB(25, 22, 20), Enum.Material.SmoothPlastic)
		newHole.Shape = Enum.PartType.Cylinder
		holePool[holeIndex] = newHole
		hole = newHole
	end
	hole.Size = Vector3.new(0.02, 0.16, 0.16)
	hole.CFrame = CFrame.lookAt(position + normal * 0.01, position + normal * 2) * CFrame.Angles(0, math.rad(90), 0)
	hole.Transparency = 0.1
	hole.Parent = folder
end

local function spawnShell(at: CFrame)
	local template = ReplicatedStorage:FindFirstChild("Assets")
	local props = template and template:FindFirstChild("Props")
	local shellTemplate = props and props:FindFirstChild("Shell_Spent")
	local shell: BasePart
	if shellTemplate and shellTemplate:IsA("BasePart") then
		shell = shellTemplate:Clone()
	else
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.25, 0.085, 0.085)
		part.Color = Color3.fromRGB(175, 32, 32)
		part.Material = Enum.Material.SmoothPlastic
		local brass = Instance.new("Part")
		brass.Shape = Enum.PartType.Cylinder
		brass.Size = Vector3.new(0.06, 0.09, 0.09)
		brass.Color = Color3.fromRGB(205, 165, 75)
		brass.Material = Enum.Material.Metal
		brass.CanCollide = false
		brass.Massless = true
		brass.CFrame = part.CFrame * CFrame.new(-0.11, 0, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = brass
		weld.Parent = brass
		brass.Parent = part
		shell = part
	end
	shell.Anchored = false
	shell.CanCollide = true
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CollisionGroup = Collision.EFFECTS
	shell.CFrame = at * CFrame.Angles(0, math.rad(90), 0)
	shell.Parent = folder
	local camera = workspace.CurrentCamera.CFrame
	shell.AssemblyLinearVelocity = camera.RightVector * (7 + math.random() * 3) + camera.UpVector * (6 + math.random() * 2) + camera.LookVector * -1
	shell.AssemblyAngularVelocity = Vector3.new(math.random() * 20 - 10, 15, math.random() * 20 - 10)
	Debris:AddItem(shell, 2.5)
	task.delay(0.35, function()
		if shell.Parent then
			AudioController.play("ShellBounce", { position = shell.Position, pitch = 0.9 + math.random() * 0.2 })
		end
	end)
end

---------------------------------------------------------------------------------------
-- Local player's shots

local function onLocalFired(info: WeaponController.FireInfo)
	local muzzle = ViewmodelController.muzzle(info.slot)
	local from = if muzzle then muzzle.Position else info.origin + info.aim * 2
	if muzzle then
		muzzleFlash(muzzle, true)
	end
	AudioController.play("Fire", { pitch = 0.97 + math.random() * 0.06 })
	for _, pellet in info.pellets do
		tracer(from, pellet.position)
		if pellet.instance then
			impact(pellet.position, pellet.normal, pellet.material, pellet.isCharacter)
		end
	end
end

---------------------------------------------------------------------------------------
-- Other players: third-person gun, poses, shots

type Remote = {
	character: Model,
	gun: ShotgunModel.ShotgunModel?,
	anim: AnimPlayer.AnimPlayer,
	slot: number,
	swapDip: number, -- 1 right after a swap, decays to 0
	kick: number,
	crouch: number, -- 0..1 blended
}

local remotes: { [Model]: Remote } = {}

local function getRemote(character: Model): Remote?
	if character == player.Character then
		return nil
	end
	local entry = remotes[character]
	if entry then
		return entry
	end
	entry = {
		character = character,
		gun = nil,
		anim = AnimPlayer.new("ThirdPerson"),
		slot = (character:GetAttribute("EquippedSlot") :: number?) or 1,
		swapDip = 0,
		kick = 0,
		crouch = 0,
	}
	remotes[character] = entry
	character:GetAttributeChangedSignal("EquippedSlot"):Connect(function()
		local e = remotes[character]
		if e then
			e.swapDip = 1
			AudioController.play("Swap", { parent = character.PrimaryPart })
		end
	end)
	character.Destroying:Once(function()
		remotes[character] = nil
	end)
	return entry
end

local function remoteGun(entry: Remote): ShotgunModel.ShotgunModel?
	if entry.gun and entry.gun.model.Parent == entry.character then
		return entry.gun
	end
	local model = entry.character:FindFirstChild("WorldShotgun")
	if model and model:IsA("Model") then
		entry.gun = ShotgunModel.wrap(model)
		return entry.gun
	end
	return nil
end

local function onRemoteShot(character: Model, info: any)
	if typeof(info) ~= "table" or not character or not character.Parent then
		return
	end
	local entry = getRemote(character)
	if not entry then
		return
	end
	entry.kick = 1
	local gun = remoteGun(entry)
	local muzzle = if gun then gun:point("Muzzle") else CFrame.new(info.origin)
	local distance = (workspace.CurrentCamera.CFrame.Position - muzzle.Position).Magnitude
	if distance < 300 then
		muzzleFlash(muzzle, false)
		AudioController.play("Fire", { position = muzzle.Position, pitch = 0.95 + math.random() * 0.08 })
		-- Pellet traces: same deterministic pattern the shooter used
		if typeof(info.aim) == "Vector3" and typeof(info.origin) == "Vector3" and typeof(info.shot) == "number" then
			local dirs = Spread.directions(WeaponConfig.Spread, info.aim, info.shot, info.mult or 1)
			local params = Collision.shotParams({ character, folder })
			for _, d in dirs do
				local result = workspace:Raycast(info.origin, d * WeaponConfig.Damage.MaxRange, params)
				local to = if result then result.Position else info.origin + d * 80
				tracer(muzzle.Position, to)
				if result then
					impact(result.Position, result.Normal, result.Material, Combatants.fromPart(result.Instance) ~= nil)
				end
			end
		end
	end
	-- Pump after the recoil, like the first-person model
	task.delay(0.2, function()
		if entry.character.Parent then
			entry.anim:play("TP_Pump", { fadeIn = 0.03 })
			AudioController.play("Pump", { parent = character.PrimaryPart })
		end
	end)
end

local function poseRemotes(dt: number)
	for character, entry in remotes do
		if not character.Parent or character:GetAttribute("Dead") == true then
			continue
		end
		local pitch = (character:GetAttribute("AimPitch") :: number?) or 0
		entry.swapDip = math.max(0, entry.swapDip - dt / 0.3)
		entry.kick = math.max(0, entry.kick - dt / 0.2)
		local crouchTarget = if character:GetAttribute("Crouching") == true then 1 else 0
		entry.crouch += (crouchTarget - entry.crouch) * (1 - math.exp(-dt * 14))

		local waist = character:FindFirstChild("Waist", true) :: Motor6D?
		local neck = character:FindFirstChild("Neck", true) :: Motor6D?
		if waist and waist:IsA("Motor6D") then
			waist.Transform = CFrame.Angles(pitch * 0.45, 0, 0)
		end
		if neck and neck:IsA("Motor6D") then
			neck.Transform = CFrame.Angles(pitch * 0.4, 0, 0)
		end
		local gunPart = nil
		local gun = remoteGun(entry)
		if gun then
			gunPart = gun.model.PrimaryPart
		end
		local mount = gunPart and gunPart:FindFirstChild("GunMount") :: Motor6D?
		if mount then
			local dip = math.sin(entry.swapDip * math.pi)
			mount.Transform = CFrame.new(0, -0.6 * dip, 0.25 * entry.kick)
				* CFrame.Angles(pitch * 0.15 + 0.12 * entry.kick - 0.9 * dip, 0, 0)
		end
		if gun then
			gun:setPose(entry.anim:update(dt))
		end
		if entry.crouch > 0.01 then
			local c = entry.crouch
			for _, side in { "Left", "Right" } do
				local hip = character:FindFirstChild(side .. "Hip", true) :: Motor6D?
				local knee = character:FindFirstChild(side .. "Knee", true) :: Motor6D?
				local ankle = character:FindFirstChild(side .. "Ankle", true) :: Motor6D?
				if hip and hip:IsA("Motor6D") then
					hip.Transform = CFrame.Angles(math.rad(62) * c, 0, 0)
				end
				if knee and knee:IsA("Motor6D") then
					knee.Transform = CFrame.Angles(math.rad(-105) * c, 0, 0)
				end
				if ankle and ankle:IsA("Motor6D") then
					ankle.Transform = CFrame.Angles(math.rad(43) * c, 0, 0)
				end
			end
		end
	end
end

local function track(character: Model)
	task.defer(function()
		if character.Parent then
			getRemote(character)
		end
	end)
end

function EffectsController.elimination(position: Vector3, color: Color3?)
	local c = color or Color3.fromRGB(255, 80, 80)
	burst(CFrame.new(position), ColorSequence.new(c, Color3.new(1, 1, 1)), if Settings.values.reducedEffects then 10 else 24, NumberRange.new(8, 18), 0.35, 0.6)
end

function EffectsController.start()
	folder = Instance.new("Folder")
	folder.Name = "Effects"
	folder.Parent = workspace
	table.insert(WeaponController.excluded, folder)

	WeaponController.Fired:Connect(onLocalFired)
	WeaponController.DryFire:Connect(function()
		AudioController.play("EmptyClick")
	end)
	WeaponController.Equipped:Connect(function(_, _, isSpawn)
		AudioController.play(if isSpawn then "Equip" else "Swap")
	end)
	WeaponController.ReloadStarted:Connect(function()
		AudioController.play("ReloadStart")
	end)
	WeaponController.ShellInserted:Connect(function()
		AudioController.play("ShellInsert", { pitch = 0.95 + math.random() * 0.1 })
	end)
	ViewmodelController.ShellEjected:Connect(function(_, at)
		spawnShell(at)
	end)
	ViewmodelController.PumpStarted:Connect(function(_, speed)
		AudioController.play("Pump", { pitch = speed })
	end)

	Net.event("WeaponEvent").OnClientEvent:Connect(function(kind, a, b)
		if kind == "Shot" then
			onRemoteShot(a, b)
		end
	end)

	local function watchPlayer(other: Player)
		if other == player then
			return
		end
		other.CharacterAdded:Connect(track)
		if other.Character then
			track(other.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	RunService.Stepped:Connect(function(_, dt)
		poseRemotes(dt)
	end)
end

return EffectsController
