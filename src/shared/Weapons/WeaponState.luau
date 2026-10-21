--!strict
-- The rules of the two shotguns, as pure data + functions (no Roblox APIs), so the exact
-- same code runs on the client (prediction) and the server (authority), and in unit tests.
--
-- Rules:
--   * Each slot has its own ammo, its own fire cooldown and its own reload.
--   * A shot needs: the slot equipped and raised (swap finished), the slot's own cooldown
--     over, the player's global MinShotInterval over, and at least one shell.
--   * Swapping never resets or shortens a cooldown; holstered guns keep counting down.
--   * Reloads insert one shell at a time and are interrupted by firing or swapping
--     (shells already inserted are kept).
--
-- Times are seconds on whatever clock the caller uses (os.clock on the server,
-- os.clock on the client). `tolerance` lets the server accept a request that arrives a
-- little early because of network jitter. Next-allowed times advance from
-- max(now, nextAllowed), so tolerance can be gained once but never accumulates.

export type Timing = {
	FireCooldown: number,
	MinShotInterval: number,
	SwapTime: number,
	EquipTime: number,
	ReloadStartTime: number,
	ReloadInsertTime: number,
}

export type Rules = {
	timing: Timing,
	magazineSize: number,
}

export type Slot = {
	ammo: number,
	nextFireTime: number, -- this slot's cooldown ends here
	lastFireTime: number,
	reloading: boolean,
	reloadStartedAt: number,
	reloadBaseAmmo: number,
	shotsFired: number,
}

export type State = {
	rules: Rules,
	slots: { Slot },
	equipped: number,
	readyAt: number, -- the equipped gun is raised and may fire from here
	nextShotTime: number, -- global min-interval gate across both guns
	shotCounter: number, -- total shots, used for the deterministic spread roll
	lastSwapAt: number,
}

export type FailReason = "NotEquipped" | "Swapping" | "Cooldown" | "ShotInterval" | "Empty" | "Reloading" | "BadSlot"

local WeaponState = {}

local NEVER = -math.huge

function WeaponState.rulesFromConfig(weaponConfig: any): Rules
	return {
		timing = weaponConfig.Timing,
		magazineSize = weaponConfig.Ammo.MagazineSize,
	}
end

local function newSlot(magazineSize: number): Slot
	return {
		ammo = magazineSize,
		nextFireTime = NEVER,
		lastFireTime = NEVER,
		reloading = false,
		reloadStartedAt = 0,
		reloadBaseAmmo = 0,
		shotsFired = 0,
	}
end

function WeaponState.new(rules: Rules, now: number, slotCount: number?): State
	local slots = {}
	for i = 1, slotCount or 2 do
		slots[i] = newSlot(rules.magazineSize)
	end
	return {
		rules = rules,
		slots = slots,
		equipped = 1,
		readyAt = now + rules.timing.EquipTime,
		nextShotTime = NEVER,
		shotCounter = 0,
		lastSwapAt = NEVER,
	}
end

-- Shells inserted by an in-progress reload at time `now` (not yet applied).
local function reloadShellsAt(state: State, slot: Slot, now: number): number
	local timing = state.rules.timing
	local elapsed = now - slot.reloadStartedAt - timing.ReloadStartTime
	if elapsed < 0 then
		return 0
	end
	local shells = math.floor(elapsed / timing.ReloadInsertTime + 1e-9)
	return math.clamp(shells, 0, state.rules.magazineSize - slot.reloadBaseAmmo)
end

-- Brings a slot's ammo up to date with its reload; finishes the reload when full.
function WeaponState.syncReload(state: State, slotIndex: number, now: number)
	local slot = state.slots[slotIndex]
	if not slot or not slot.reloading then
		return
	end
	slot.ammo = slot.reloadBaseAmmo + reloadShellsAt(state, slot, now)
	if slot.ammo >= state.rules.magazineSize then
		slot.ammo = state.rules.magazineSize
		slot.reloading = false
	end
end

-- Stops a reload, keeping inserted shells.
local function interruptReload(state: State, slotIndex: number, now: number)
	local slot = state.slots[slotIndex]
	if slot and slot.reloading then
		WeaponState.syncReload(state, slotIndex, now)
		slot.reloading = false
	end
end

-- When the reload of a slot will be complete (nil if not reloading).
function WeaponState.reloadDoneAt(state: State, slotIndex: number): number?
	local slot = state.slots[slotIndex]
	if not slot or not slot.reloading then
		return nil
	end
	local timing = state.rules.timing
	local missing = state.rules.magazineSize - slot.reloadBaseAmmo
	return slot.reloadStartedAt + timing.ReloadStartTime + missing * timing.ReloadInsertTime
end

function WeaponState.canFire(state: State, slotIndex: number, now: number, tolerance: number?): (boolean, FailReason?)
	local tol = tolerance or 0
	local slot = state.slots[slotIndex]
	if not slot then
		return false, "BadSlot"
	end
	if slotIndex ~= state.equipped then
		return false, "NotEquipped"
	end
	if now < state.readyAt - tol then
		return false, "Swapping"
	end
	if slot.reloading then
		-- Firing interrupts a reload only if a shell is in. Count shells as of now+tol.
		local shells = slot.reloadBaseAmmo + reloadShellsAt(state, slot, now + tol)
		if shells <= 0 then
			return false, "Reloading"
		end
	elseif slot.ammo <= 0 then
		return false, "Empty"
	end
	if now < slot.nextFireTime - tol then
		return false, "Cooldown"
	end
	if now < state.nextShotTime - tol then
		return false, "ShotInterval"
	end
	return true, nil
end

-- Applies a shot if allowed. Returns ok, reason, shotNumber (for the spread roll).
function WeaponState.fire(
	state: State,
	slotIndex: number,
	now: number,
	tolerance: number?
): (boolean, FailReason?, number)
	local ok, reason = WeaponState.canFire(state, slotIndex, now, tolerance)
	if not ok then
		return false, reason :: FailReason?, state.shotCounter
	end
	local slot = state.slots[slotIndex]
	local timing = state.rules.timing
	if slot.reloading then
		-- Use the tolerant count so a shot that was legal on the client stays legal here.
		slot.ammo = slot.reloadBaseAmmo + reloadShellsAt(state, slot, now + (tolerance or 0))
		slot.reloading = false
	end
	slot.ammo -= 1
	slot.lastFireTime = now
	slot.shotsFired += 1
	slot.nextFireTime = math.max(now, slot.nextFireTime) + timing.FireCooldown
	state.nextShotTime = math.max(now, state.nextShotTime) + timing.MinShotInterval
	state.shotCounter += 1
	return true, nil, state.shotCounter
end

-- Switches to another slot. Returns false if it's already equipped or doesn't exist.
function WeaponState.equip(state: State, slotIndex: number, now: number): boolean
	if not state.slots[slotIndex] or slotIndex == state.equipped then
		return false
	end
	interruptReload(state, state.equipped, now)
	state.equipped = slotIndex
	state.lastSwapAt = now
	-- Swapping mid-swap restarts the raise; it can never make a gun ready sooner.
	state.readyAt = now + state.rules.timing.SwapTime
	return true
end

function WeaponState.otherSlot(state: State): number
	return if state.equipped == 1 then 2 else 1
end

function WeaponState.startReload(state: State, now: number): boolean
	local slotIndex = state.equipped
	local slot = state.slots[slotIndex]
	WeaponState.syncReload(state, slotIndex, now)
	if slot.reloading or slot.ammo >= state.rules.magazineSize then
		return false
	end
	slot.reloading = true
	-- If the gun is still being raised, shells start going in once it's up.
	slot.reloadStartedAt = math.max(now, state.readyAt)
	slot.reloadBaseAmmo = slot.ammo
	return true
end

function WeaponState.cancelReload(state: State, now: number)
	interruptReload(state, state.equipped, now)
end

-- Full ammo, no cooldowns (on respawn).
function WeaponState.reset(state: State, now: number)
	for i, _ in state.slots do
		state.slots[i] = newSlot(state.rules.magazineSize)
	end
	state.equipped = 1
	state.readyAt = now + state.rules.timing.EquipTime
	state.nextShotTime = NEVER
	state.shotCounter = 0
	state.lastSwapAt = NEVER
end

export type SlotView = {
	ammo: number,
	magazineSize: number,
	reloading: boolean,
	equipped: boolean,
	cooldownRemaining: number, -- seconds until this slot's own cooldown ends
	cooldownFraction: number, -- 0 = ready, 1 = just fired
	ready: boolean, -- could fire right now if equipped
}

-- Read-only summary for the HUD.
function WeaponState.view(state: State, slotIndex: number, now: number): SlotView
	local slot = state.slots[slotIndex]
	local timing = state.rules.timing
	local ammo = slot.ammo
	if slot.reloading then
		ammo = slot.reloadBaseAmmo + reloadShellsAt(state, slot, now)
	end
	local remaining = math.max(0, slot.nextFireTime - now)
	local equipped = slotIndex == state.equipped
	local raised = not equipped or now >= state.readyAt
	return {
		ammo = ammo,
		magazineSize = state.rules.magazineSize,
		reloading = slot.reloading and ammo < state.rules.magazineSize,
		equipped = equipped,
		cooldownRemaining = remaining,
		cooldownFraction = math.clamp(remaining / timing.FireCooldown, 0, 1),
		ready = remaining <= 0 and ammo > 0 and raised and now >= state.nextShotTime,
	}
end

return WeaponState
