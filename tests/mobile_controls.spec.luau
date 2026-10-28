--!nocheck
local T = require("./runner/T")
local L = require("./runner/Loader")
local R = L.roblox
local layout = L.require(L.Shared.Mobile.Layout)
local touch = L.require(L.Shared.Mobile.TouchState)
local seq = L.require(L.Shared.Mobile.FireSequence)
local present = L.require(L.Shared.Mobile.Presentation)
local ws = L.require(L.Shared.Weapons.WeaponState)
local config = L.require(L.Shared.Config.WeaponConfig)
local profile = L.require(L.Shared.Progression.Profile)
local expect, it = T.expect, T.it
T.describe("Mobile touch ownership and swipe recognition", function()
	it("accepts one quick downward intent and requires a fresh finger gesture", function()
		local s = touch.new(1)
		expect(s:begin("swipe", "Swipe", 220, 120, 0)).toBeTruthy()
		expect(s:move("swipe", 225, 191, 0.1)).toBeFalsy()
		expect(s:move("swipe", 225, 192, 0.2)).toBeTruthy()
		expect(s:move("swipe", 225, 300, 0.25)).toBeFalsy()
		s:finish("swipe")
		s:begin("again", "Swipe", 220, 120, 1)
		expect(s:move("again", 220, 210, 1.2)).toBeTruthy()
	end)
	for _, case in
		{ { "slow", 0, 90, 0.31 }, { "short", 0, 40, 0.1 }, { "horizontal", 120, 80, 0.1 }, { "upward", 0, -100, 0.1 } }
	do
		it("rejects " .. case[1], function()
			local s = touch.new(1)
			s:begin(1, "Swipe", 0, 0, 0)
			expect(s:move(1, case[2], case[3], case[4])).toBeFalsy()
		end)
	end
	it("rejects up-then-down and expired drags permanently", function()
		local s = touch.new(1)
		s:begin(1, "Swipe", 0, 50, 0)
		s:move(1, 0, 20, 0.1)
		expect(s:move(1, 0, 150, 0.2)).toBeFalsy()
		s:finish(1)
		s:begin(2, "Swipe", 0, 0, 0)
		s:move(2, 0, 30, 0.31)
		expect(s:move(2, 0, 100, 0.32)).toBeFalsy()
	end)
	it("scales the distance threshold with the logical GUI layout", function()
		local s = touch.new(1.5)
		s:begin(1, "Swipe", 0, 0, 0)
		expect(s:move(1, 0, 90, 0.2)).toBeFalsy()
		expect(s:move(1, 0, 108, 0.3)).toBeTruthy()
	end)
	it("movement and unrelated controls never become swipe intents", function()
		for _, role in { "Move", "Aim", "Fire", "Jump", "Reload", "Crouch" } do
			local s = touch.new(1)
			s:begin(1, role, 0, 0, 0)
			expect(s:move(1, 0, 200, 0.1)).toBeFalsy()
		end
	end)
	it("independent fingers own fire, movement, look, jump and swipe concurrently", function()
		local s = touch.new(1)
		for i, role in { "Fire", "Move", "Aim", "Jump", "Swipe" } do
			expect(s:begin(i, role, 0, 0, 0)).toBeTruthy()
		end
		expect(s:begin(6, "Fire", 0, 0, 0)).toBeFalsy()
		expect(s:finish(3)).toBe("Aim")
		expect(s.owners.Fire).toBe(1)
		expect(s.owners.Move).toBe(2)
		expect(s:move(5, 0, 80, 0.15)).toBeTruthy()
		s:clear()
		expect(next(s.owners)).toBe(nil)
	end)
	it("movement stick retains clamping", function()
		expect(touch.stick(100, 100, 30).Magnitude).toBeNear(1)
		expect(touch.stick(0, 0, 30).Magnitude).toBe(0)
	end)
end)
T.describe("Mobile held-fire sequences use unchanged weapon rules", function()
	local function harness()
		local now = 0
		local state = ws.new(ws.rulesFromConfig(config), -config.Timing.EquipTime)
		local s = seq.new()
		local shots = 0
		local function fire()
			if ws.fire(state, state.equipped, now) then
				shots += 1
			end
		end
		local function swap()
			local slot = ws.otherSlot(state)
			if ws.equip(state, slot, now) then
				return slot
			end
		end
		local function step(t)
			now = t
			local ok, why = ws.canFire(state, state.equipped, now)
			s:step(true, state.equipped, ok, why, fire)
		end
		return s, state, fire, swap, step, function()
			return shots
		end
	end
	it("holding alone fires once, even across many cooldowns", function()
		local s, state, fire, swap, step, shots = harness()
		s:press(fire)
		s:press(fire)
		for t = 0, 5, 0.01 do
			step(t)
		end
		expect(shots()).toBe(1)
		expect(state.slots[1].ammo).toBe(config.Ammo.MagazineSize - 1)
	end)
	it("a new press during cooldown makes no delayed repeat shot", function()
		local s, state, fire, swap, step, shots = harness()
		s:press(fire)
		s:release()
		step(0.2)
		s:press(fire)
		step(2)
		expect(shots()).toBe(1)
		expect(s.pending).toBe(nil)
	end)
	it("pressing fire interrupts a loaded reload using the original weapon rules", function()
		local s, state, fire, swap, step, shots = harness()
		s:press(fire)
		s:release()
		step(1)
		expect(ws.startReload(state, 1)).toBeTruthy()
		step(1.1)
		s:press(fire)
		expect(shots()).toBe(2)
		expect(state.slots[1].reloading).toBeFalsy()
		expect(state.slots[1].ammo).toBe(config.Ammo.MagazineSize - 2)
	end)
	it("one swipe fires the second gun at the original global interval, once", function()
		local s, state, fire, swap, step, shots = harness()
		s:press(fire)
		step(0.02)
		expect(s:swipe(swap)).toBeTruthy()
		step(0.17)
		expect(shots()).toBe(1)
		step(0.399)
		expect(shots()).toBe(1)
		step(0.4)
		expect(shots()).toBe(2)
		step(4)
		expect(shots()).toBe(2)
		expect(state.slots[2].ammo).toBe(config.Ammo.MagazineSize - 1)
	end)
	it("a fresh rapid swipe replaces the pending intent and restarts normal switch eligibility", function()
		local s, state, fire, swap, step, shots = harness()
		s:press(fire)
		step(0.02)
		s:swipe(swap)
		step(0.04)
		expect(s:swipe(swap)).toBeTruthy()
		expect(state.equipped).toBe(1)
		expect(s.pending).toBe(1)
		step(0.4)
		expect(shots()).toBe(1)
		step(1)
		expect(shots()).toBe(2)
		expect(state.slots[2].ammo).toBe(config.Ammo.MagazineSize)
		expect(state.slots[1].ammo).toBe(config.Ammo.MagazineSize - 2)
	end)
	it("switching back waits for the independent original same-gun cooldown", function()
		local s, state, fire, swap, step, shots = harness()
		s:press(fire)
		step(0.02)
		s:swipe(swap)
		step(0.4)
		step(0.42)
		s:swipe(swap)
		step(0.8)
		expect(shots()).toBe(2)
		step(0.999)
		expect(shots()).toBe(2)
		step(1)
		expect(shots()).toBe(3)
	end)
	it("releasing fire cancels an eligible future shot", function()
		local s, state, fire, swap, step, shots = harness()
		s:press(fire)
		step(0.02)
		s:swipe(swap)
		s:release()
		step(0.4)
		expect(shots()).toBe(1)
		expect(s.pending).toBe(nil)
	end)
	it("unheld swipes switch without firing", function()
		local s, state, fire, swap, step, shots = harness()
		s:swipe(swap)
		step(2)
		expect(state.equipped).toBe(2)
		expect(shots()).toBe(0)
	end)
	it("death/menu/focus cancellation cannot resurrect a pending shot", function()
		local s, state, fire, swap, step, shots = harness()
		s:press(fire)
		s:swipe(swap)
		s:step(false, 2, true, nil, fire)
		step(5)
		expect(shots()).toBe(1)
		expect(s.held).toBeFalsy()
	end)
	it("a reconciled slot change cancels the intent, rather than shooting a different gun", function()
		local s, state, fire, swap, step, shots = harness()
		s:press(fire)
		s:swipe(swap)
		ws.equip(state, 1, 0.05)
		step(2)
		expect(shots()).toBe(1)
		expect(s.pending).toBe(nil)
	end)
	it("consumes before the fire callback and never retries a rejection", function()
		local s = seq.new()
		local calls = 0
		s:press(function() end)
		s:swipe(function()
			return 2
		end)
		s:step(true, 2, true, nil, function()
			calls += 1
			s:step(true, 2, true, nil, function()
				calls += 100
			end)
		end)
		s:step(true, 2, true, nil, function()
			calls += 100
		end)
		expect(calls).toBe(1)
	end)
	it("an empty incoming gun consumes one attempt without firing through a reload", function()
		local s = seq.new()
		local n = 0
		s:press(function() end)
		s:swipe(function()
			return 2
		end)
		s:step(true, 2, false, "Empty", function()
			n += 1
		end)
		s:step(true, 2, true, nil, function()
			n += 1
		end)
		expect(n).toBe(1)
	end)
end)
T.describe("Responsive mobile layout", function()
	for _, size in
		{
			{ 568, 320 },
			{ 640, 360 },
			{ 844, 390 },
			{ 932, 430 },
			{ 1024, 768 },
			{ 1366, 1024 },
			{ 320, 568 },
			{
				390,
				844,
			},
		}
	do
		for _, left in { false, true } do
			it(
				string.format("no overlapping touch or HUD bounds at %dx%d %s", size[1], size[2], tostring(left)),
				function()
					local out = layout.calculate(size[1], size[2], left)
					for name, r in out.rects do
						assert(
							r.x >= -0.001 and r.y >= 0 and r.x + r.w <= size[1] + 0.001 and r.y + r.h <= size[2] + 0.001,
							"outside safe area: " .. name
						)
						for other, b in out.rects do
							if other ~= name then
								assert(not layout.overlaps(r, b), name .. " overlaps " .. other)
							end
						end
					end
				end
			)
		end
	end
	it("exact mirror preserves sizes and vertical alignment", function()
		local a, b = layout.calculate(844, 390, false), layout.calculate(844, 390, true)
		for name, r in a.rects do
			expect(b.rects[name].x).toBeNear(844 - r.x - r.w)
			expect(b.rects[name].y).toBe(r.y)
		end
		expect(a.rects.Crouch.x + a.rects.Crouch.w / 2).toBeNear(844 * 0.86)
		expect(a.rects.Crouch.y).toBe(a.rects.Reload.y)
	end)
	it("unsafe saved layouts are rejected without moving other controls", function()
		local defaults = layout.calculate(844, 390, false)
		local bad = layout.calculate(844, 390, false, { Fire = { 0.86, 0.62, 1 } })
		expect(bad.rects.Fire).toEqual(defaults.rects.Fire)
	end)
end)
T.describe("Handedness presentation and persistence", function()
	it("reflects local offsets without reversing the forward direction", function()
		local cf = R.CFrame.new(0.8, -0.5, -1) * R.CFrame.Angles(0.2, 0.1, 0.05)
		local reflected = present.reflect(cf)
		expect(reflected.X).toBeNear(-cf.X)
		expect(reflected.Y).toBeNear(cf.Y)
		expect(reflected.LookVector.Z).toBeNear(cf.LookVector.Z)
		local round = present.reflect(reflected)
		expect((round.Position - cf.Position).Magnitude).toBeNear(0)
		expect(round.LookVector:Dot(cf.LookVector)).toBeNear(1)
		expect(reflected.RightVector:Cross(reflected.UpVector):Dot(-reflected.LookVector)).toBeNear(1)
	end)
	it("migrates v1 profiles without changing progress or legacy layout", function()
		local p = profile.sanitize(
			{ version = 1, xp = 400, coins = 70, settings = { touchLayout = { Fire = { 0.8, 0.5, 1 } } } },
			100
		)
		expect(p.version).toBe(3)
		expect(p.xp).toBe(400)
		expect(p.coins).toBe(70)
		expect(p.settings.controlLayout).toBe("right")
		expect(p.settings.touchLayout.Fire[1]).toBe(0.8)
		expect(next(p.settings.touchLayoutV2)).toBe(nil)
	end)
	it("keeps handedness and new button positions over a profile roundtrip", function()
		local p = profile.new(100)
		p.settings.controlLayout = "left"
		p.settings.touchLayoutV2 = { Fire = { 0.7, 0.65, 1 } }
		local again = profile.sanitize(p, 200)
		expect(again.settings.controlLayout).toBe("left")
		expect(again.settings.touchLayoutV2.Fire[2]).toBe(0.65)
	end)
	it("sends handedness through the existing debounced settings save and applies it on load", function()
		local oldTask = L.task
		L.reset()
		local ok, err = xpcall(function()
			local pending, saved, calls = nil, nil, 0
			L.task = table.clone(oldTask)
			L.task.delay = function(_, fn)
				pending = fn
			end
			L.inject(L.Shared.Net, {
				event = function(name)
					expect(name).toBe("SettingsAction")
					return {
						FireServer = function(_, action, values)
							expect(action).toBe("Save")
							calls += 1
							saved = table.clone(values)
						end,
					}
				end,
			})
			local settings = L.require(L.game.StarterPlayer.StarterPlayerScripts.Client.Controllers.Settings)
			settings.set("controlLayout", "left")
			settings.set("weaponHand", "right")
			settings.save()
			settings.save()
			expect(calls).toBe(0)
			pending()
			expect(calls).toBe(1)
			expect(saved.controlLayout).toBe("left")
			expect(saved.weaponHand).toBe("right")
			local p = profile.new(100)
			p.settings = saved
			settings.reset()
			settings.apply(profile.sanitize(p, 200).settings)
			expect(settings.values.controlLayout).toBe("left")
			expect(settings.values.weaponHand).toBe("right")
		end, debug.traceback)
		L.task = oldTask
		L.reset()
		assert(ok, err)
	end)
end)
