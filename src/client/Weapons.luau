-- Client side of the shotguns: input, swapping, and firing.
--
-- The client predicts everything so it feels instant: it shows tracers and
-- impacts right away, then sends the shot to the server, which decides what
-- actually hit and replies with hitmarkers/damage numbers.
--
-- Controls: Left click fires. 1 / 2 pick a gun. Mouse wheel or Q swaps.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Spread = require(ReplicatedStorage.Shared.Spread)
local Effects = require(script.Parent.Effects)
local Viewmodel = require(script.Parent.Viewmodel)
local Hud = require(script.Parent.Hud)
local Movement = require(script.Parent.Movement)
local Sounds = require(script.Parent.Sounds)

local Remotes = ReplicatedStorage.Remotes
local WeaponConfig = Config.Weapon
local player = Players.LocalPlayer

local Weapons = {}

-- Shared with the Viewmodel and Hud so they can animate from the same timestamps
Weapons.state = {
	activeSlot = 1,
	equippedAt = -math.huge, -- os.clock() of the last swap
	lastFired = { [1] = -math.huge, [2] = -math.huge }, -- per gun
	now = os.clock(),
}
local state = Weapons.state

-- If you click a little before the gun is ready, remember it for a moment
-- and fire the instant it becomes ready (Config.Weapon.InputBuffer).
local queuedFireAt: number? = nil

local function getAliveCharacter(): (Model?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return character, humanoid
	end
	return nil, nil
end

-- Seconds until the active gun can fire (0 means right now)
local function timeUntilReady(): number
	local equipReady = state.equippedAt + WeaponConfig.EquipDelay
	local cooldownReady = state.lastFired[state.activeSlot] + WeaponConfig.FireCooldown
	return math.max(equipReady - state.now, cooldownReady - state.now, 0)
end

local function fire()
	local character = getAliveCharacter()
	if not character then
		return
	end
	local camera = workspace.CurrentCamera
	local slot = state.activeSlot
	state.lastFired[slot] = state.now

	local origin = camera.CFrame.Position
	local aim = camera.CFrame.LookVector
	local seed = math.random(1, 2 ^ 30)

	-- Our own raycasts ignore our character and our effects
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, Effects.folder }

	local hits = {}
	local muzzle = Viewmodel.getMuzzlePosition()
	local aiming = Movement.state.aiming -- aimed shots have a tighter spread
	for index, direction in Spread.getPelletDirections(seed, aim, aiming) do
		local result = workspace:Raycast(origin, direction * WeaponConfig.MaxRange, params)
		local endPoint = if result then result.Position else origin + direction * WeaponConfig.MaxRange
		Effects.tracer(muzzle, endPoint)

		if result then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			local hitCharacter = model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
			Effects.impact(result.Position, hitCharacter)
			if hitCharacter then
				-- Tell the server which pellet hit which body part
				table.insert(hits, { pellet = index, part = result.Instance })
			end
		end
	end

	Remotes.Fire:FireServer(slot, seed, origin, aim, hits, aiming)
end

local function tryFire()
	local remaining = timeUntilReady()
	if remaining <= 0 then
		queuedFireAt = nil
		fire()
	elseif remaining <= WeaponConfig.InputBuffer then
		queuedFireAt = state.now
	end
end

local function equip(slot: number)
	if slot == state.activeSlot then
		return
	end
	state.activeSlot = slot
	state.equippedAt = state.now
	queuedFireAt = nil
	Remotes.Equip:FireServer(slot)
end

local function swap()
	equip(if state.activeSlot == 1 then 2 else 1)
end

-- Called every frame by init.client before drawing
function Weapons.update()
	state.now = os.clock()
	if queuedFireAt then
		if state.now - queuedFireAt > WeaponConfig.InputBuffer then
			queuedFireAt = nil -- waited too long; drop it
		elseif timeUntilReady() <= 0 then
			queuedFireAt = nil
			fire()
		end
	end
end

-- Show other players' shots (the server tells us seed + aim; we redo the rays)
local function onShotFired(shooter: Model?, seed: number, origin: Vector3, aim: Vector3, aiming: boolean)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if shooter then { shooter, Effects.folder } else { Effects.folder }
	for _, direction in Spread.getPelletDirections(seed, aim, aiming) do
		local result = workspace:Raycast(origin, direction * WeaponConfig.MaxRange, params)
		local endPoint = if result then result.Position else origin + direction * WeaponConfig.MaxRange
		Effects.tracer(origin + direction * 2, endPoint)
		if result then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			Effects.impact(result.Position, model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil)
		end
	end
end

local function onHitConfirm(results)
	local anyHeadshot, anyKill = false, false
	for _, result in results do
		Effects.damageNumber(result.position, result.damage, result.headshot, result.killed)
		anyHeadshot = anyHeadshot or result.headshot
		anyKill = anyKill or result.killed
	end
	Hud.showHitmarker(anyHeadshot, anyKill)
	if anyKill then
		Sounds.playElimination() -- only we hear it: HitConfirm goes just to the shooter
	end
end

function Weapons.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return -- typing in chat, clicking a button, etc.
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			tryFire()
		elseif input.KeyCode == Enum.KeyCode.One then
			equip(1)
		elseif input.KeyCode == Enum.KeyCode.Two then
			equip(2)
		elseif input.KeyCode == Enum.KeyCode.Q then
			swap()
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			swap() -- only two guns, so either wheel direction swaps
		end
	end)

	-- Fresh guns on every respawn (the server resets its copy too)
	player.CharacterAdded:Connect(function()
		state.activeSlot = 1
		state.equippedAt = -math.huge
		state.lastFired[1] = -math.huge
		state.lastFired[2] = -math.huge
		queuedFireAt = nil
	end)

	Remotes.ShotFired.OnClientEvent:Connect(onShotFired)
	Remotes.HitConfirm.OnClientEvent:Connect(onHitConfirm)
end

Weapons.getAliveCharacter = getAliveCharacter

return Weapons
