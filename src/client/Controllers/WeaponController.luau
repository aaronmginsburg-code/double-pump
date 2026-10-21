--!strict
-- Client side of the two shotguns. Runs the same WeaponState rules as the server so the
-- game reacts the instant you click (prediction), raycasts the pellets locally, and sends
-- the result for the server to validate. The server's snapshot wins on any disagreement.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Collision = require(Shared.Collision)
local Combatants = require(Shared.Combatants)
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Spread = require(Shared.Weapons.Spread)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponState = require(Shared.Weapons.WeaponState)

local InputController = require(script.Parent.InputController)
local MovementController = require(script.Parent.MovementController)

local WeaponController = {}

export type PelletResult = {
	position: Vector3,
	normal: Vector3,
	instance: Instance?,
	material: Enum.Material?,
	isCharacter: boolean,
}
export type FireInfo = {
	slot: number,
	origin: Vector3,
	aim: Vector3,
	directions: { Vector3 },
	pellets: { PelletResult },
	shotNumber: number,
}

WeaponController.Fired = Signal.new() :: Signal.Signal<FireInfo>
WeaponController.Equipped = Signal.new() :: Signal.Signal<number, number?, boolean> -- slot, previous, isSpawn
WeaponController.ReloadStarted = Signal.new() :: Signal.Signal<number>
WeaponController.ShellInserted = Signal.new() :: Signal.Signal<number, number>
WeaponController.ReloadEnded = Signal.new() :: Signal.Signal<number, boolean> -- slot, completed
WeaponController.DryFire = Signal.new() :: Signal.Signal<number>
WeaponController.HitConfirmed = Signal.new() :: Signal.Signal<{ any }>
WeaponController.Rejected = Signal.new() :: Signal.Signal<string?>
WeaponController.Reset = Signal.new() :: Signal.Signal<>

local player = Players.LocalPlayer
local rules = WeaponState.rulesFromConfig(WeaponConfig)
WeaponController.state = WeaponState.new(rules, os.clock())
WeaponController.active = false -- alive and allowed to shoot
WeaponController.excluded = {} :: { Instance } -- extra instances pellets ignore (viewmodel, effects)

local weaponAction: RemoteEvent
local bufferedUntil = 0
local lastReloadShells: { [number]: number } = {}
local wasReloading: { [number]: boolean } = {}

local function state()
	return WeaponController.state
end

local function canAct(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return WeaponController.active
		and humanoid ~= nil
		and humanoid.Health > 0
		and character:GetAttribute("Frozen") ~= true
end

local function castPellets(origin: Vector3, directions: { Vector3 }): ({ PelletResult }, { any })
	local character = player.Character
	local exclude: { Instance } = { character :: Instance }
	for _, inst in WeaponController.excluded do
		table.insert(exclude, inst)
	end
	local params = Collision.shotParams(exclude)
	local maxRange = WeaponConfig.Damage.MaxRange
	local results: { PelletResult } = {}
	local hits = {}
	for i, direction in directions do
		local result = workspace:Raycast(origin, direction * maxRange, params)
		if result then
			local model = Combatants.fromPart(result.Instance)
			results[i] = {
				position = result.Position,
				normal = result.Normal,
				instance = result.Instance,
				material = result.Material,
				isCharacter = model ~= nil,
			}
			if model and character and Combatants.isEnemy(character, model) and Combatants.isAlive(model) then
				table.insert(hits, { i = i, part = result.Instance, pos = result.Position })
			end
		else
			results[i] = {
				position = origin + direction * maxRange,
				normal = -direction,
				instance = nil,
				material = nil,
				isCharacter = false,
			}
		end
	end
	return results, hits
end

local function doFire(now: number)
	local s = state()
	local slot = s.equipped
	local ok, _, shotNumber = WeaponState.fire(s, slot, now)
	if not ok then
		return
	end
	bufferedUntil = 0
	local character = player.Character :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local camera = workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local aim = camera.CFrame.LookVector
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
	local multiplier = Spread.stateMultiplier(WeaponConfig.Spread, MovementController.crouching, airborne)
	local directions = Spread.directions(WeaponConfig.Spread, aim, shotNumber, multiplier)
	local pellets, hits = castPellets(origin, directions)

	weaponAction:FireServer("Fire", {
		slot = slot,
		origin = origin,
		aim = aim,
		air = airborne,
		hits = hits,
	})
	if wasReloading[slot] then
		wasReloading[slot] = false
		WeaponController.ReloadEnded:Fire(slot, false)
	end
	WeaponController.Fired:Fire({
		slot = slot,
		origin = origin,
		aim = aim,
		directions = directions,
		pellets = pellets,
		shotNumber = shotNumber,
	})
end

-- Seconds until the equipped gun could fire (ignoring ammo); 0 if now.
local function timeUntilReady(now: number): number
	local s = state()
	local slot = s.slots[s.equipped]
	return math.max(0, s.readyAt - now, slot.nextFireTime - now, s.nextShotTime - now)
end

function WeaponController.tryFire()
	if not canAct() then
		return
	end
	local now = os.clock()
	local s = state()
	local ok, reason = WeaponState.canFire(s, s.equipped, now)
	if ok then
		doFire(now)
	elseif reason == "Empty" then
		WeaponController.DryFire:Fire(s.equipped)
		if WeaponConfig.Ammo.AutoReloadWhenEmpty then
			WeaponController.reload()
		end
	elseif reason == "Swapping" or reason == "Cooldown" or reason == "ShotInterval" or reason == "Reloading" then
		-- Remember a slightly early press so it isn't lost
		if reason ~= "Reloading" and timeUntilReady(now) <= WeaponConfig.Timing.InputBuffer then
			bufferedUntil = now + WeaponConfig.Timing.InputBuffer + 0.02
		end
	end
end

function WeaponController.equip(slot: number)
	if not canAct() then
		return
	end
	local s = state()
	local previous = s.equipped
	local reloadingBefore = wasReloading[previous]
	if WeaponState.equip(s, slot, os.clock()) then
		bufferedUntil = 0
		weaponAction:FireServer("Equip", slot)
		if reloadingBefore then
			wasReloading[previous] = false
			WeaponController.ReloadEnded:Fire(previous, false)
		end
		WeaponController.Equipped:Fire(slot, previous, false)
	end
end

function WeaponController.swap()
	WeaponController.equip(WeaponState.otherSlot(state()))
end

function WeaponController.reload()
	if not canAct() then
		return
	end
	local s = state()
	if WeaponState.startReload(s, os.clock()) then
		weaponAction:FireServer("Reload")
		wasReloading[s.equipped] = true
		lastReloadShells[s.equipped] = s.slots[s.equipped].ammo
		WeaponController.ReloadStarted:Fire(s.equipped)
	end
end

function WeaponController.view(slot: number): WeaponState.SlotView
	return WeaponState.view(state(), slot, os.clock())
end

local function applySnapshot(snap: any)
	if typeof(snap) ~= "table" or typeof(snap.slots) ~= "table" then
		return
	end
	local s = state()
	local now = os.clock()
	local previous = s.equipped
	s.equipped = snap.equipped
	s.shotCounter = snap.shotCounter
	s.readyAt = now + snap.readyIn
	s.nextShotTime = if snap.shotIn > 0 then now + snap.shotIn else -math.huge
	for i, slotSnap in snap.slots do
		local slot = s.slots[i]
		if slot then
			slot.ammo = slotSnap.ammo
			slot.nextFireTime = if slotSnap.cooldown > 0 then now + slotSnap.cooldown else -math.huge
			if slotSnap.reloading and not slot.reloading then
				slot.reloading = true
				slot.reloadBaseAmmo = slotSnap.ammo
				slot.reloadStartedAt = now - WeaponConfig.Timing.ReloadStartTime
			elseif not slotSnap.reloading then
				slot.reloading = false
			end
		end
	end
	if previous ~= s.equipped then
		WeaponController.Equipped:Fire(s.equipped, previous, false)
	end
end

local function onWeaponEvent(kind: string, a: any, b: any)
	if kind == "Snapshot" then
		applySnapshot(a)
		if b then
			WeaponController.Rejected:Fire(b)
		end
	elseif kind == "Hit" then
		WeaponController.HitConfirmed:Fire(a)
	elseif kind == "Reset" then
		WeaponController.state = WeaponState.new(rules, os.clock())
		table.clear(wasReloading)
		bufferedUntil = 0
		WeaponController.Reset:Fire()
		WeaponController.Equipped:Fire(1, nil, true)
	end
end

local function step()
	local now = os.clock()
	local s = state()
	-- Buffered press
	if bufferedUntil > 0 then
		if now > bufferedUntil then
			bufferedUntil = 0
		elseif canAct() and WeaponState.canFire(s, s.equipped, now) then
			doFire(now)
		end
	end
	-- Testing option: hold to keep firing
	if GameConfig.Debug.AutoFireWhenHeld and InputController.isHeld("Fire") and canAct() then
		if WeaponState.canFire(s, s.equipped, now) then
			doFire(now)
		end
	end
	-- Reload progress events for animations and sounds
	local slotIndex = s.equipped
	if wasReloading[slotIndex] then
		local view = WeaponState.view(s, slotIndex, now)
		local before = lastReloadShells[slotIndex] or view.ammo
		if view.ammo > before then
			for n = before + 1, view.ammo do
				WeaponController.ShellInserted:Fire(slotIndex, n)
			end
			lastReloadShells[slotIndex] = view.ammo
		end
		WeaponState.syncReload(s, slotIndex, now)
		if not s.slots[slotIndex].reloading then
			wasReloading[slotIndex] = false
			WeaponController.ReloadEnded:Fire(slotIndex, true)
		end
	end
end

function WeaponController.start()
	weaponAction = Net.event("WeaponAction")
	Net.event("WeaponEvent").OnClientEvent:Connect(onWeaponEvent)

	InputController.Action:Connect(function(action, pressed)
		if action == "Fire" and pressed then
			WeaponController.tryFire()
		elseif action == "EquipA" then
			WeaponController.equip(1)
		elseif action == "EquipB" then
			WeaponController.equip(2)
		elseif action == "Swap" then
			WeaponController.swap()
		elseif action == "Reload" then
			WeaponController.reload()
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return WeaponController
