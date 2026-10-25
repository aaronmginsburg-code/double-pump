--!nocheck
local T = require("./runner/T")
local Loader = require("./runner/Loader")
local Shared = Loader.Shared
local WeaponConfig = Loader.require(Shared.Config.WeaponConfig)
local WeaponState = Loader.require(Shared.Weapons.WeaponState)

local rules = WeaponState.rulesFromConfig(WeaponConfig)
local timing = WeaponConfig.Timing
local describe, it, expect = T.describe, T.it, T.expect

-- A state whose gun is raised at t=0
local function fresh()
	local s = WeaponState.new(rules, -timing.EquipTime)
	return s
end

describe("WeaponState", function()
	it("starts with two full, independent shotguns and slot A equipped", function()
		local s = fresh()
		expect(#s.slots).toBe(2)
		expect(s.equipped).toBe(1)
		expect(s.slots[1].ammo).toBe(5)
		expect(s.slots[2].ammo).toBe(5)
		expect(s.slots[1]).toBeTruthy()
		expect(s.slots[1] ~= s.slots[2]).toBeTruthy()
	end)

	it("cannot fire before the equip raise finishes", function()
		local s = WeaponState.new(rules, 0)
		local ok, why = WeaponState.fire(s, 1, 0.1)
		expect(ok).toBeFalsy()
		expect(why).toBe("Swapping")
		expect(WeaponState.fire(s, 1, timing.EquipTime)).toBeTruthy()
	end)

	it("fires once and consumes exactly one shell", function()
		local s = fresh()
		local ok = WeaponState.fire(s, 1, 0)
		expect(ok).toBeTruthy()
		expect(s.slots[1].ammo).toBe(4)
		expect(s.slots[2].ammo).toBe(5)
	end)

	it("enforces the per-gun cooldown", function()
		local s = fresh()
		WeaponState.fire(s, 1, 0)
		local ok, why = WeaponState.fire(s, 1, timing.FireCooldown - 0.01)
		expect(ok).toBeFalsy()
		expect(why).toBe("Cooldown")
		expect(WeaponState.fire(s, 1, timing.FireCooldown)).toBeTruthy()
	end)

	it("only fires the equipped gun", function()
		local s = fresh()
		local ok, why = WeaponState.fire(s, 2, 0)
		expect(ok).toBeFalsy()
		expect(why).toBe("NotEquipped")
	end)

	it("double pump: second gun fires MinShotInterval after the first, not earlier", function()
		local s = fresh()
		expect(WeaponState.fire(s, 1, 0)).toBeTruthy()
		WeaponState.equip(s, 2, 0.02)
		-- raised at 0.17, but the global interval holds it until 0.4
		local ok, why = WeaponState.fire(s, 2, 0.2)
		expect(ok).toBeFalsy()
		expect(why).toBe("ShotInterval")
		expect(WeaponState.fire(s, 2, timing.MinShotInterval)).toBeTruthy()
	end)

	it("swap is gated by SwapTime", function()
		local s = fresh()
		WeaponState.equip(s, 2, 1)
		local ok, why = WeaponState.fire(s, 2, 1 + timing.SwapTime - 0.01)
		expect(ok).toBeFalsy()
		expect(why).toBe("Swapping")
		expect(WeaponState.fire(s, 2, 1 + timing.SwapTime)).toBeTruthy()
	end)

	it("swapping back does NOT reset the first gun's cooldown", function()
		local s = fresh()
		WeaponState.fire(s, 1, 0)
		WeaponState.equip(s, 2, 0.01)
		WeaponState.fire(s, 2, 0.4)
		WeaponState.equip(s, 1, 0.42)
		-- A is raised at 0.57 but its own cooldown runs to 1.0
		local ok, why = WeaponState.fire(s, 1, 0.6)
		expect(ok).toBeFalsy()
		expect(why).toBe("Cooldown")
		expect(WeaponState.fire(s, 1, 1.0)).toBeTruthy()
	end)

	it("alternating guns gives two shots per cooldown, single gun gives one", function()
		local function count(alternate)
			local s = fresh()
			local shots, t = 0, 0
			while t < 3.0 do
				local slot = s.equipped
				if WeaponState.fire(s, slot, t) then
					shots += 1
					if alternate then
						WeaponState.equip(s, WeaponState.otherSlot(s), t + 0.01)
					end
				end
				t += 0.01
			end
			return shots
		end
		local single, double = count(false), count(true)
		expect(single).toBe(3) -- 0, 1, 2
		expect(double).toBeGreaterThan(single)
		expect(double).toBeAtLeast(5)
	end)

	it("rapid swapping can't make a gun ready sooner", function()
		local s = fresh()
		WeaponState.fire(s, 1, 0)
		for i = 1, 20 do
			WeaponState.equip(s, WeaponState.otherSlot(s), i * 0.02)
		end
		-- equipped is slot 1 after an even number of swaps; cooldown still to 1.0
		expect(s.equipped).toBe(1)
		expect((WeaponState.fire(s, 1, 0.9))).toBeFalsy()
	end)

	it("reports Empty with no shells", function()
		local s = fresh()
		for i = 0, 4 do
			expect((WeaponState.fire(s, 1, i * 1.0))).toBeTruthy()
		end
		local ok, why = WeaponState.fire(s, 1, 10)
		expect(ok).toBeFalsy()
		expect(why).toBe("Empty")
		expect(s.slots[1].ammo).toBe(0)
	end)

	it("reloads one shell at a time", function()
		local s = fresh()
		for i = 0, 4 do
			WeaponState.fire(s, 1, i)
		end
		expect(WeaponState.startReload(s, 10)).toBeTruthy()
		local tStart = 10 + timing.ReloadStartTime
		WeaponState.syncReload(s, 1, tStart + timing.ReloadInsertTime * 2 + 0.01)
		expect(s.slots[1].ammo).toBe(2)
		expect(s.slots[1].reloading).toBeTruthy()
		WeaponState.syncReload(s, 1, tStart + timing.ReloadInsertTime * 5 + 0.01)
		expect(s.slots[1].ammo).toBe(5)
		expect(s.slots[1].reloading).toBeFalsy()
	end)

	it("won't reload a full gun", function()
		local s = fresh()
		expect(WeaponState.startReload(s, 0)).toBeFalsy()
	end)

	it("firing interrupts a reload and keeps inserted shells", function()
		local s = fresh()
		for i = 0, 4 do
			WeaponState.fire(s, 1, i)
		end
		WeaponState.startReload(s, 10)
		local t = 10 + timing.ReloadStartTime + timing.ReloadInsertTime * 2 + 0.01
		expect(WeaponState.fire(s, 1, t)).toBeTruthy()
		expect(s.slots[1].ammo).toBe(1)
		expect(s.slots[1].reloading).toBeFalsy()
	end)

	it("can't fire mid-reload before the first shell is in", function()
		local s = fresh()
		for i = 0, 4 do
			WeaponState.fire(s, 1, i)
		end
		WeaponState.startReload(s, 10)
		local ok, why = WeaponState.fire(s, 1, 10.2)
		expect(ok).toBeFalsy()
		expect(why).toBe("Reloading")
	end)

	it("swapping cancels the reload of the outgoing gun but keeps its shells", function()
		local s = fresh()
		WeaponState.fire(s, 1, 0)
		WeaponState.fire(s, 1, 1)
		WeaponState.startReload(s, 5)
		WeaponState.equip(s, 2, 5 + timing.ReloadStartTime + timing.ReloadInsertTime + 0.01)
		expect(s.slots[1].reloading).toBeFalsy()
		expect(s.slots[1].ammo).toBe(4)
		expect(s.slots[2].ammo).toBe(5)
	end)

	it("reloading during a swap starts inserting once the gun is raised", function()
		local s = fresh()
		WeaponState.equip(s, 2, 0)
		WeaponState.fire(s, 2, 1)
		WeaponState.equip(s, 1, 2)
		WeaponState.equip(s, 2, 2.05)
		WeaponState.startReload(s, 2.06)
		expect(s.slots[2].reloadStartedAt).toBeNear(2.05 + timing.SwapTime)
	end)

	it("server tolerance accepts slightly-early shots but never accumulates", function()
		local s = fresh()
		local tol = 0.08
		local t = 0
		expect((WeaponState.fire(s, 1, t, tol))).toBeTruthy()
		-- fire every cooldown - tol (cheater): first early shot passes, then it drifts
		local accepted = 1
		for _ = 1, 10 do
			t += timing.FireCooldown - tol
			if WeaponState.fire(s, 1, t, tol) then
				accepted += 1
			end
		end
		-- legit rate over this span is floor(t / cooldown) + 1
		expect(accepted).toBeAtMost(math.floor(t / timing.FireCooldown) + 2)
	end)

	it("reset restores full ammo and clears cooldowns", function()
		local s = fresh()
		WeaponState.fire(s, 1, 0)
		WeaponState.equip(s, 2, 0.1)
		WeaponState.reset(s, 0.2)
		expect(s.slots[1].ammo).toBe(5)
		expect(s.equipped).toBe(1)
		expect(s.slots[1].nextFireTime).toBe(-math.huge)
	end)
	it("respawn resets the pellet counter to match a fresh client state", function()
		local server = fresh()
		for i = 0, 5 do
			local slot = i % 2 + 1
			WeaponState.equip(server, slot, i * 0.6)
			expect(WeaponState.fire(server, slot, i * 0.6 + 0.2)).toBeTruthy()
		end
		expect(server.shotCounter).toBe(6)
		for life = 1, 3 do
			local now = life * 10
			WeaponState.reset(server, now)
			local client = WeaponState.new(rules, now)
			expect(server.shotCounter).toBe(client.shotCounter)
			local _, _, serverShot = WeaponState.fire(server, 1, now + timing.EquipTime)
			local _, _, clientShot = WeaponState.fire(client, 1, now + timing.EquipTime)
			expect(serverShot).toBe(1)
			expect(serverShot).toBe(clientShot)
		end
	end)

	it("view reports cooldown fraction and readiness", function()
		local s = fresh()
		WeaponState.fire(s, 1, 0)
		local v = WeaponState.view(s, 1, 0.5)
		expect(v.cooldownFraction).toBeNear(0.5)
		expect(v.ready).toBeFalsy()
		expect(v.ammo).toBe(4)
		local v2 = WeaponState.view(s, 2, 0.5)
		expect(v2.ready).toBeTruthy()
	end)
end)
