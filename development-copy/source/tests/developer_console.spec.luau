--!nocheck
local T = require("./runner/T")
local L = require("./runner/Loader")
L.reset()
local C = L.require(L.Shared.DeveloperConsole.Config)
local Runtime = L.require(L.Shared.DeveloperConsole.Runtime)
local Trigger = L.require(L.Shared.DeveloperConsole.AutoFire)
local Store = L.require(L.Shared.DeveloperConsole.ProfileStore)
local Weapon = L.require(L.Shared.Weapons.WeaponState)
local WeaponConfig = L.require(L.Shared.Config.WeaponConfig)
local Game = L.require(L.Shared.Config.GameConfig)
local Access = L.require(L.Server.Services.DeveloperAccess)
local Layout = L.require(L.Shared.DeveloperConsole.Layout)
T.describe("Responsive console layout", function()
	for _, size in { { 1920, 1080 }, { 874, 402 }, { 320, 568 }, { 393, 852 }, { 1024, 768 } } do
		T.it("fits the safe viewport " .. size[1] .. "x" .. size[2], function()
			local v = Layout.measure(size[1], size[2])
			assert(v.x >= 0 and v.y >= 0 and v.x + v.width <= size[1] and v.y + v.height <= size[2])
			assert(v.compact == (v.height < 560))
		end)
	end
end)
T.describe("Five-category console registry", function()
	T.it("validates complete defaults", function()
		T.expect(C.validate(C.defaults())).toEqual(C.defaults())
	end)
	T.it("contains five categories and distinct identifiers", function()
		T.expect(#C.Categories).toBe(5)
		local seen = {}
		for _, f in C.Fields do
			local id = f.category .. "." .. f.key
			assert(not seen[id])
			seen[id] = true
			assert(f.description and f.handler and f.policy and f.scope)
		end
	end)
	for _, cat in C.Categories do
		T.it("rejects missing and unknown " .. cat .. " settings", function()
			local v = C.defaults()
			v[cat].unknown = true
			assert(C.validate(v) == nil)
			v = C.defaults()
			v[cat] = nil
			assert(C.validate(v) == nil)
		end)
	end
	T.it("rejects all numeric invalid bounds NaN infinity and fractional integer fields", function()
		for _, f in C.Fields do
			if f.type == "number" and f.available then
				for _, bad in { f.min - 1, f.max + 1, 0 / 0, math.huge, "1" } do
					local v = C.defaults()
					v[f.category][f.key] = bad
					assert(C.validate(v) == nil, f.key)
				end
				if f.step == 1 then
					local v = C.defaults()
					v[f.category][f.key] = f.min + 0.5
					assert(C.validate(v) == nil)
				end
			end
		end
	end)
	T.it("rejects fictional movement feature activation", function()
		for _, key in { "sprint", "slide", "friction", "acceleration", "deceleration" } do
			local v = C.defaults()
			v.movement[key] += 1
			assert(C.validate(v) == nil)
		end
	end)
	T.it("requires consistent falloff and spatial near/far ranges", function()
		local v = C.defaults()
		v.weapons.falloffStart = 50
		assert(C.validate(v) == nil)
		v = C.defaults()
		v.weapons.range = 20
		assert(C.validate(v) == nil)
		v = C.defaults()
		v.audio.Fire_min = 80
		v.audio.Fire_max = 30
		assert(C.validate(v) == nil)
	end)
	T.it("migrates legacy aim profile without changing other defaults", function()
		local v = C.legacy({ slowdownStrength = 0.6, enabled = false })
		assert(v.aiming.slowdownStrength == 0.6 and not v.aiming.enabled)
		assert(C.equal(v, C.defaults(), "movement"))
		assert(C.equal(v, C.defaults(), "weapons"))
	end)
	T.it("merges a category without replacing unrelated live settings", function()
		local a = C.defaults()
		a.audio.bus_Master = 0.4
		local b = C.defaults()
		b.movement.walk = 22
		local v = C.merge(a, b, "movement")
		assert(v.audio.bus_Master == 0.4 and v.movement.walk == 22)
	end)
	T.it("validates preset names and scopes without datastore key injection", function()
		for _, n in { "default", "Mobile-Aim_Test", "BalancedAudio" } do
			assert(C.name(n))
		end
		for _, n in { "", "bad/name", string.rep("x", 25), "../production", "two words" } do
			assert(not C.name(n))
		end
		assert(C.scope("all") and C.scope("audio") and not C.scope("production"))
	end)
	T.it("defaults auto fire and mouse assistance off", function()
		local v = C.defaults()
		assert(
			not v.autoFire.enabled
				and not v.aiming.mouseEligible
				and v.aiming.touchEligible
				and v.aiming.controllerEligible
		)
	end)
end)
T.describe("Tuning runtime preserves weapon authority", function()
	T.it("default mapping preserves every gameplay value and spread", function()
		local cfg = C.copy(WeaponConfig)
		Runtime.weapons(C.defaults().weapons, cfg, WeaponConfig)
		T.expect(cfg).toEqual(WeaponConfig)
	end)
	T.it("keeps pellet direction count claim limit and damage count consistent", function()
		for _, count in { 1, 7, 10, 16, 20 } do
			local cfg = C.copy(WeaponConfig)
			local v = C.defaults().weapons
			v.pellets = count
			Runtime.weapons(v, cfg, WeaponConfig)
			assert(
				#cfg.Spread.Pattern == count
					and cfg.Damage.PelletCount == count
					and cfg.Validation.MaxHitsPerShot == count
			)
		end
	end)
	T.it("does not compound spread scaling over repeated live edits", function()
		local cfg = C.copy(WeaponConfig)
		local v = C.defaults().weapons
		v.spread = 1.5
		Runtime.weapons(v, cfg, WeaponConfig)
		Runtime.weapons(v, cfg, WeaponConfig)
		T.expect(cfg.Spread.Pattern[2].radius).toBeNear(2.4)
	end)
	T.it("retains ammunition shot counters and action deadlines while clamping capacity", function()
		local s = Weapon.new(Weapon.rulesFromConfig(WeaponConfig), 0)
		assert(Weapon.fire(s, 1, 1))
		local deadline = s.slots[1].nextFireTime
		Runtime.state(s, 3)
		assert(
			s.slots[1].ammo == 3
				and s.slots[2].ammo == 3
				and s.shotCounter == 1
				and s.slots[1].nextFireTime == deadline
				and s.nextShotTime == 1.4
		)
	end)
	T.it("increasing capacity does not grant free ammo", function()
		local s = Weapon.new(Weapon.rulesFromConfig(WeaponConfig), 0)
		Runtime.state(s, 8)
		assert(s.slots[1].ammo == 5 and s.rules.magazineSize == 8)
	end)
	T.it("waits for active reload and raise before applying weapon rules", function()
		local s = Weapon.new(Weapon.rulesFromConfig(WeaponConfig), 0)
		assert(not Runtime.safe({ s }, 0.1, Weapon))
		assert(Weapon.fire(s, 1, 1))
		assert(Weapon.startReload(s, 1))
		assert(not Runtime.safe({ s }, 1.2, Weapon))
		assert(Runtime.safe({ s }, 2, Weapon))
	end)
	T.it("movement mapper updates only supported mechanics", function()
		local g = C.copy(Game)
		local v = C.defaults().movement
		v.walk = 22
		v.air = 0.7
		Runtime.movement(v, g)
		assert(
			g.Movement.WalkSpeed == 22
				and g.Movement.AirControl == 0.7
				and not g.Movement.SprintEnabled
				and g.Movement.Gravity == 196.2
		)
	end)
	T.it("production IDs and unlisted users remain denied", function()
		assert(not Access.environment(10772275012, 82505574993280))
		assert(not Access.allowed(123, 10772492892, 139437092998076))
	end)
end)
T.describe("Auto fire ordinary trigger lifecycle", function()
	local function config()
		local v = C.defaults().autoFire
		v.enabled = true
		return v
	end
	T.it("does nothing while disabled or mouse is ineligible", function()
		local s = Trigger.new()
		assert(not Trigger.step(s, C.defaults().autoFire, 1, "target", "Touch", true, true, false))
		assert(not Trigger.step(s, config(), 1, "target", "Keyboard", true, true, false))
	end)
	T.it("waits for both acquisition and persistence then fires once legally ready", function()
		local s = Trigger.new()
		local c = config()
		assert(not Trigger.step(s, c, 0, "target", "Touch", true, true, false))
		assert(not Trigger.step(s, c, 0.2, "target", "Touch", true, true, false))
		assert(Trigger.step(s, c, 0.3, "target", "Touch", true, true, false))
		assert(not Trigger.step(s, c, 0.4, "target", "Touch", true, true, false))
	end)
	T.it("target switching restarts acquisition", function()
		local s = Trigger.new()
		local c = config()
		Trigger.step(s, c, 0, "A", "Touch", true, true, false)
		assert(not Trigger.step(s, c, 0.3, "B", "Touch", true, true, false))
		assert(Trigger.step(s, c, 0.6, "B", "Touch", true, true, false))
	end)
	T.it("never interrupts reloads or bypasses weapon readiness", function()
		local s = Trigger.new()
		local c = config()
		Trigger.step(s, c, 0, "A", "Touch", true, true, false)
		assert(not Trigger.step(s, c, 0.4, "A", "Touch", true, true, true))
		assert(not Trigger.step(s, c, 0.5, "A", "Touch", true, false, false))
		assert(Trigger.step(s, c, 0.6, "A", "Touch", true, true, false))
	end)
	T.it("UI death loss of target and input ineligibility cancel acquisition", function()
		for _, condition in { "UI", "Target", "Device" } do
			local s = Trigger.new()
			local c = config()
			Trigger.step(s, c, 0, "A", "Touch", true, true, false)
			Trigger.step(
				s,
				c,
				0.2,
				if condition == "Target" then nil else "A",
				if condition == "Device" then "Keyboard" else "Touch",
				condition ~= "UI",
				true,
				false
			)
			assert(not Trigger.step(s, c, 0.3, "A", "Touch", true, true, false))
		end
	end)
end)
T.describe("Versioned scoped presets with compare-and-swap", function()
	local function adapter()
		return {
			value = nil,
			GetAsync = function(self)
				return self.value
			end,
			UpdateAsync = function(self, _, fn)
				local nextValue = fn(self.value)
				if nextValue then
					self.value = nextValue
				end
				return nextValue
			end,
		}
	end
	T.it("loads empty slot and saves validated full profile", function()
		local db = adapter()
		local store = Store.new(db)
		assert(store:load("x").revision == 0)
		assert(store:save("x", 0, C.defaults(), "all", "default").revision == 1)
		assert(store:load("x").values.movement.walk == 20)
	end)
	T.it("stale revisions cannot overwrite newer saves", function()
		local db = adapter()
		local s = Store.new(db)
		assert(s:save("x", 0, C.defaults(), "audio", "mix"))
		assert(s:save("x", 0, C.defaults(), "audio", "mix") == nil and db.value.revision == 1)
	end)
	T.it("unknown future schema cannot be overwritten", function()
		local db = adapter()
		db.value = { schema = 99, revision = 2 }
		local s = Store.new(db)
		assert(s:load("x") == nil and s:save("x", 0, C.defaults(), "all", "default") == nil and db.value.schema == 99)
	end)
	T.it("datastore failures preserve current session values", function()
		local v = C.defaults()
		v.audio.bus_Master = 0.5
		local s = Store.new({
			GetAsync = function()
				error("offline")
			end,
			UpdateAsync = function()
				error("offline")
			end,
		})
		assert(s:load("x") == nil and s:save("x", 0, v, "audio", "mix") == nil and v.audio.bus_Master == 0.5)
	end)
	T.it("invalid save inputs never reach UpdateAsync", function()
		local called = false
		local s = Store.new({
			UpdateAsync = function()
				called = true
			end,
		})
		assert(s:save("x", -1, C.defaults(), "all", "default") == nil and not called)
		local v = C.defaults()
		v.weapons.damage = 999
		assert(s:save("x", 0, v, "all", "default") == nil and not called)
	end)
end)
L.reset()
