--!strict
-- The first-person view: two copies of the imported high-detail shotgun (one per slot,
-- each with its own animation state), simple arms, weapon sway, walk bob and wall
-- avoidance. Purely visual: it listens to WeaponController and never changes game state,
-- so cancelling an animation can't affect cooldowns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local AnimPlayer = require(Shared.Weapons.AnimPlayer)
local ShotgunModel = require(Shared.Weapons.ShotgunModel)
local ShotgunRig = require(Shared.Weapons.ShotgunRig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Signal = require(Shared.Util.Signal)

local WeaponController = require(script.Parent.WeaponController)
local CameraController = require(script.Parent.CameraController)
local MovementController = require(script.Parent.MovementController)

local ViewmodelController = {}

-- (slot, worldCFrame) when a spent shell leaves the port
ViewmodelController.ShellEjected = Signal.new() :: Signal.Signal<number, CFrame>
-- (slot, event) animation beats for sounds: "PumpBack", "PumpForward", "ShellInserted", ...
ViewmodelController.AnimEvent = Signal.new() :: Signal.Signal<number, string>
-- (slot, playbackSpeed) when a pump cycle starts (the pump sound is timed to the animation)
ViewmodelController.PumpStarted = Signal.new() :: Signal.Signal<number, number>

local player = Players.LocalPlayer
local T = WeaponConfig.Timing

type Gun = {
	slot: number,
	model: ShotgunModel.ShotgunModel,
	anim: AnimPlayer.AnimPlayer,
	visible: boolean,
	lowering: boolean,
	needsPump: boolean,
	reloading: boolean,
}

local guns: { Gun } = {}
local folder: Folder
local arms: { [string]: { BasePart } } = { right = {}, left = {} }
local swayRot = CFrame.identity
local lastCamLook: CFrame? = nil
local moveOffset = Vector3.zero
local wallPush = 0
local swayTime = 0
local enabled = false
local skinDef: any = nil

local SWAP_SPEED = 0.1167 / T.SwapTime -- SwapIn's Ready event lands at the end of SwapTime
local EQUIP_SPEED = 0.3333 / T.EquipTime
local INSERT_SPEED = 0.6 / T.ReloadInsertTime

local function onEvent(gun: Gun)
	return function(event: string)
		ViewmodelController.AnimEvent:Fire(gun.slot, event)
		if event == "EjectShell" then
			gun.model:setShellVisible("Spent", false)
			ViewmodelController.ShellEjected:Fire(gun.slot, gun.model:point("ShellEject"))
		elseif event == "PumpForward" then
			gun.needsPump = false
		elseif event == "ShellInserted" then
			gun.model:setShellVisible("Live", false)
		end
	end
end

local function playPump(gun: Gun)
	gun.model:setShellVisible("Spent", true)
	-- Fit the pump into whatever is left of this gun's cooldown (never slower than 1x)
	local view = WeaponController.view(gun.slot)
	local remaining = math.max(view.cooldownRemaining - 0.05, 0.25)
	local speed = math.max(1, gun.anim:duration("Pump") / remaining)
	gun.anim:play("Pump", { speed = speed, fadeIn = 0.04, onEvent = onEvent(gun) })
	ViewmodelController.PumpStarted:Fire(gun.slot, speed)
end

local function setVisible(gun: Gun, visible: boolean)
	gun.visible = visible
	gun.model:setVisible(visible)
	if not visible then
		gun.model:setShellVisible("Spent", false)
		gun.model:setShellVisible("Live", false)
	end
end

local function playInsert(gun: Gun)
	gun.model:setShellVisible("Live", true)
	gun.anim:play("ReloadInsert", {
		speed = INSERT_SPEED,
		fadeIn = 0.03,
		onEvent = onEvent(gun),
		onEnd = function()
			if gun.reloading then
				playInsert(gun)
			end
		end,
	})
end

local function onEquipped(slot: number, previous: number?, isSpawn: boolean)
	for _, gun in guns do
		if gun.slot == slot then
			setVisible(gun, true)
			gun.lowering = false
			gun.reloading = false
			gun.model:setShellVisible("Live", false)
			local name = if isSpawn then "Equip" else "SwapIn"
			gun.anim:play(name, {
				speed = if isSpawn then EQUIP_SPEED else SWAP_SPEED,
				fadeIn = 0,
				onEvent = onEvent(gun),
				onEnd = function()
					if gun.needsPump and WeaponController.state.equipped == gun.slot then
						playPump(gun)
					end
				end,
			})
		elseif gun.visible and (gun.slot == previous or isSpawn) then
			gun.reloading = false
			if isSpawn then
				setVisible(gun, false)
			else
				gun.lowering = true
				gun.anim:play("Unequip", {
					speed = SWAP_SPEED,
					fadeIn = 0.02,
					hold = true,
					onEvent = function(event)
						if event == "Hidden" and gun.lowering then
							setVisible(gun, false)
						end
					end,
				})
			end
		end
	end
end

local function onFired(info: WeaponController.FireInfo)
	local gun = guns[info.slot]
	if not gun then
		return
	end
	gun.reloading = false
	gun.needsPump = true
	gun.model:setShellVisible("Live", false)
	CameraController.kick(if MovementController.crouching then 0.8 else 1)
	gun.anim:play("Fire", {
		fadeIn = 0,
		onEvent = function(event)
			if event == "RecoverEnd" and WeaponController.state.equipped == gun.slot then
				playPump(gun)
			end
		end,
	})
end

function ViewmodelController.muzzle(slot: number?): CFrame?
	local gun = guns[slot or WeaponController.state.equipped]
	if gun and gun.visible then
		return gun.model:point("Muzzle")
	end
	return nil
end

local function makeArmPart(name: string, color: Color3, material: Enum.Material, size: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	return part
end

local function buildArms()
	for _, list in arms do
		for _, p in list do
			p:Destroy()
		end
		table.clear(list)
	end
	local team = player.Team
	local sleeve = if team then team.TeamColor.Color:Lerp(Color3.new(0.1, 0.1, 0.12), 0.35) else Color3.fromRGB(60, 64, 76)
	local glove = Color3.fromRGB(32, 32, 36)
	for _, side in { "right", "left" } do
		local list = arms[side]
		table.insert(list, makeArmPart("Sleeve", sleeve, Enum.Material.Fabric, Vector3.new(0.42, 0.42, 1)))
		table.insert(list, makeArmPart("Cuff", glove, Enum.Material.SmoothPlastic, Vector3.new(0.36, 0.36, 0.25)))
		table.insert(list, makeArmPart("Glove", glove, Enum.Material.SmoothPlastic, Vector3.new(0.3, 0.26, 0.4)))
	end
end

local function placeArm(list: { BasePart }, shoulder: Vector3, hand: CFrame)
	local handPos = hand.Position
	local delta = handPos - shoulder
	local length = delta.Magnitude
	if length < 0.05 then
		return
	end
	local dir = delta.Unit
	local elbowEnd = handPos - dir * 0.3
	local sleeveLen = math.max((elbowEnd - shoulder).Magnitude, 0.1)
	local sleeve, cuff, glove = list[1], list[2], list[3]
	sleeve.Size = Vector3.new(0.42, 0.42, sleeveLen)
	sleeve.CFrame = CFrame.lookAt(shoulder:Lerp(elbowEnd, 0.5), elbowEnd)
	cuff.CFrame = CFrame.lookAt(elbowEnd, handPos)
	glove.CFrame = CFrame.lookAt(handPos - dir * 0.1, handPos + dir)
end

local function update(dt: number)
	if not enabled or #guns == 0 then
		return
	end
	local camera = workspace.CurrentCamera
	local camCF = camera.CFrame
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

	-- Sway: the gun lags slightly behind fast camera turns
	if lastCamLook then
		local delta = (lastCamLook :: CFrame):ToObjectSpace(camCF)
		local rx, ry = delta:ToEulerAnglesYXZ()
		local target = CFrame.Angles(math.clamp(rx * 0.6, -0.08, 0.08), math.clamp(ry * 0.6, -0.08, 0.08), math.clamp(-ry * 0.8, -0.1, 0.1))
		swayRot = swayRot:Lerp(target, 1 - math.exp(-dt * 12))
	end
	lastCamLook = camCF

	-- Walk bob + crouch dip
	local speed = if root then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0
	swayTime += dt * (2 + speed * 0.45)
	local walk = math.min(speed / 20, 1)
	local targetMove = Vector3.new(
		math.sin(swayTime) * 0.035 * walk,
		math.abs(math.cos(swayTime)) * -0.04 * walk + (if MovementController.crouching then -0.05 else 0),
		0
	)
	moveOffset = moveOffset:Lerp(targetMove, 1 - math.exp(-dt * 10))

	-- Wall avoidance: pull the gun back and down when standing against geometry
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, character :: Instance }
	local hit = workspace:Raycast(camCF.Position, camCF.LookVector * 3.2, params)
	local targetPush = if hit then math.clamp(1 - (hit.Distance - 0.6) / 2.6, 0, 1) else 0
	wallPush += (targetPush - wallPush) * (1 - math.exp(-dt * 12))

	local base = camCF
		* CFrame.new(moveOffset)
		* swayRot
		* ShotgunRig.ViewmodelOffset
		* CFrame.new(0, -0.25 * wallPush, 0.9 * wallPush)
		* CFrame.Angles(-0.5 * wallPush, 0.25 * wallPush, 0)

	local equipped = WeaponController.state.equipped
	for _, gun in guns do
		local pose = gun.anim:update(dt)
		if gun.visible then
			gun.model:setRoot(base)
			gun.model:setPose(pose)
		end
	end
	-- Hands on the equipped gun
	local gun = guns[equipped]
	if gun and gun.visible then
		local shoulderR = (camCF * CFrame.new(1.05, -1.55, 0.7)).Position
		local shoulderL = (camCF * CFrame.new(-0.35, -1.7, 0.1)).Position
		placeArm(arms.right, shoulderR, gun.model:point("Grip"))
		placeArm(arms.left, shoulderL, gun.model:point("SupportHand"))
		for _, list in arms do
			for _, p in list do
				p.LocalTransparencyModifier = 0
			end
		end
	else
		for _, list in arms do
			for _, p in list do
				p.LocalTransparencyModifier = 1
			end
		end
	end
end

local function build()
	for _, gun in guns do
		gun.model:destroy()
	end
	table.clear(guns)
	for slot = 1, 2 do
		local model = ShotgunModel.new("FirstPerson")
		model:applySkin(skinDef)
		model.model.Name = "Viewmodel_" .. slot
		model.model.Parent = folder
		local anim = AnimPlayer.new("FirstPerson")
		anim:playBase("Idle")
		local gun: Gun = {
			slot = slot,
			model = model,
			anim = anim,
			visible = false,
			lowering = false,
			needsPump = false,
			reloading = false,
		}
		model:setVisible(false)
		guns[slot] = gun
	end
	buildArms()
end

function ViewmodelController.setSkin(skin: any)
	skinDef = skin
	for _, gun in guns do
		gun.model:applySkin(skin)
	end
end

function ViewmodelController.setEnabled(on: boolean)
	enabled = on
	folder.Parent = if on then workspace.CurrentCamera else nil
end

function ViewmodelController.start()
	folder = Instance.new("Folder")
	folder.Name = "Viewmodel"
	table.insert(WeaponController.excluded, folder)
	build()

	WeaponController.Equipped:Connect(onEquipped)
	WeaponController.Fired:Connect(onFired)
	WeaponController.Reset:Connect(function()
		for _, gun in guns do
			gun.needsPump = false
			gun.reloading = false
		end
		buildArms()
	end)
	WeaponController.ReloadStarted:Connect(function(slot)
		local gun = guns[slot]
		if not gun then
			return
		end
		gun.reloading = true
		gun.anim:play("ReloadStart", {
			fadeIn = 0.05,
			onEvent = onEvent(gun),
			onEnd = function()
				if gun.reloading then
					playInsert(gun)
				end
			end,
		})
	end)
	WeaponController.ReloadEnded:Connect(function(slot, completed)
		local gun = guns[slot]
		if not gun or not gun.reloading then
			return
		end
		gun.reloading = false
		gun.model:setShellVisible("Live", false)
		if completed and WeaponController.state.equipped == slot then
			gun.anim:play("ReloadEnd", { fadeIn = 0.05, onEvent = onEvent(gun) })
		end
	end)
	player:GetPropertyChangedSignal("Team"):Connect(buildArms)
	RunService:BindToRenderStep("DoublePumpViewmodel", Enum.RenderPriority.Camera.Value + 2, update)
end

return ViewmodelController
