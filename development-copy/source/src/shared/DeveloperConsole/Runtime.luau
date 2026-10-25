--!strict
-- Mutates only the already-required config tables, so existing gameplay systems remain authoritative.
local R = {}
function R.movement(values: any, gameConfig: any)
	local m = gameConfig.Movement
	m.WalkSpeed = values.walk
	m.CrouchSpeed = values.crouch
	m.JumpHeight = values.jump
	m.AirControl = values.air
end
function R.weapons(v: any, config: any, baseline: any)
	config.Damage.PelletDamage = v.damage
	config.Damage.PelletCount = v.pellets
	config.Damage.MaxRange = v.range
	config.Damage.FalloffStart = v.falloffStart
	config.Damage.FalloffEnd = v.falloffEnd
	config.Damage.FalloffMinMultiplier = v.minDamage
	config.Timing.FireCooldown = v.cooldown
	config.Timing.ReloadStartTime = v.reloadStart
	config.Timing.ReloadInsertTime = v.reloadInsert
	config.Timing.ReloadEndTime = v.reloadEnd
	config.Timing.SwapTime = v.swap
	config.Recoil.ViewKickPitch = v.recoil
	config.Recoil.RecoverTime = v.recovery
	config.Ammo.MagazineSize = v.capacity
	config.Validation.MaxHitsPerShot = v.pellets
	local pattern = {}
	for i = 1, v.pellets do
		local item = baseline.Spread.Pattern[i]
		pattern[i] = if item
			then { radius = item.radius * v.spread, angle = item.angle }
			else { radius = 3.6 * v.spread, angle = (i - 11) * 137.507764 }
	end
	config.Spread.Pattern = pattern
end
function R.state(state: any, capacity: number)
	state.rules.magazineSize = capacity
	for _, slot in state.slots do
		slot.ammo = math.min(slot.ammo, capacity)
		slot.reloadBaseAmmo = math.min(slot.reloadBaseAmmo, capacity)
	end
	-- Never refill ammo, change shot counters, reset a cooldown or shorten a raise deadline.
end
function R.safe(states: any, now: number, weaponState: any): boolean
	for _, s in states do
		for i in s.slots do
			weaponState.syncReload(s, i, now)
			if s.slots[i].reloading then
				return false
			end
		end
		if s.readyAt > now then
			return false
		end
	end
	return true
end
return R
