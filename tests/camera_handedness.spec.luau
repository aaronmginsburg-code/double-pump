--!nocheck
local T = require("./runner/T")
local L = require("./runner/Loader")
local oldLayout = require("./fixtures/MobileLayoutV5")
local layout = L.require(L.Shared.Mobile.Layout)
local drag = L.require(L.Shared.Mobile.DragAim)
local preferences = L.require(L.Shared.Preferences)
local profile = L.require(L.Shared.Progression.Profile)
local expect, it = T.expect, T.it
T.describe("Touch drag restoration", function()
	it("passes exact finger deltas, without a rate or deadzone", function()
		local s = drag.new()
		expect(s:begin(1, false)).toBeTruthy()
		expect(s:move(1, L.roblox.Vector2.new(24, -13))).toEqual(L.roblox.Vector2.new(24, -13))
		expect(s:move(1, L.roblox.Vector2.zero)).toEqual(L.roblox.Vector2.zero)
	end)
	it("buttons, movement and swap cannot acquire the camera", function()
		local s = drag.new()
		for _, role in { "Fire", "Move", "Swipe", "Jump", "Crouch", "Reload" } do
			expect(s:begin(role, true)).toBeFalsy()
			expect(s:move(role, L.roblox.Vector2.new(0, 100)).Magnitude).toBe(0)
		end
	end)
	it("one aim finger remains independent of simultaneous control fingers", function()
		local s = drag.new()
		s:begin("aim", false)
		expect(s:begin("second", false)).toBeFalsy()
		expect(s:move("fire", L.roblox.Vector2.new(5, 8)).Magnitude).toBe(0)
		s:finish("fire")
		expect(s:move("aim", L.roblox.Vector2.new(5, 8)).X).toBe(5)
		s:finish("aim")
		expect(s:move("aim", L.roblox.Vector2.new(5, 8)).Magnitude).toBe(0)
		expect(s:begin("fresh", false)).toBeTruthy()
		s:clear()
		expect(s:move("fresh", L.roblox.Vector2.new(5, 8)).Magnitude).toBe(0)
	end)
end)
T.describe("No mobile layout drift", function()
	for _, size in
		{
			{ 568, 320 },
			{ 772, 360 },
			{ 844, 390 },
			{ 874, 402 },
			{ 960, 600 },
			{ 1024, 768 },
			{ 1366, 1024 },
			{
				320,
				568,
			},
			{
				390,
				844,
			},
		}
	do
		for _, left in { false, true } do
			it(tostring(size[1]) .. "x" .. tostring(size[2]) .. " hand " .. tostring(left), function()
				for _, saved in
					{
						{},
						{ Fire = { 0.86, 0.62, 1 } },
						{ Look = { 0.8, 0.6, 1 }, Menu = { 0.63, 0.08, 1 } },
						{
							Move = { 0.1, 0.8, 0.9 },
						},
					}
				do
					local before = oldLayout.calculate(size[1], size[2], left, saved)
					local after = layout.calculate(size[1], size[2], left, saved)
					expect(after.rects.Look).toBe(nil)
					expect(after.rects.LegacyV2Constraint).toBe(nil)
					for name, r in before.rects do
						if name ~= "Look" then
							expect(after.rects[name]).toEqual(r)
						end
					end
				end
			end)
		end
	end
end)
T.describe("Independent presentation preference migration", function()
	it("defaults both preferences right", function()
		expect(preferences.normalize(nil)).toEqual({ controlLayout = "right", weaponHand = "right" })
	end)
	for _, legacy in { "Left-Handed", "Right-Handed" } do
		it("preserves coupled " .. legacy .. " saves", function()
			local p = profile.sanitize({ version = 2, xp = 99, settings = { controlLayout = legacy } }, 100)
			local side = if legacy == "Left-Handed" then "left" else "right"
			expect(p.settings.controlLayout).toBe(side)
			expect(p.settings.weaponHand).toBe(side)
			expect(p.xp).toBe(99)
			expect(p.version).toBe(3)
		end)
	end
	for _, ui in { "right", "left" } do
		for _, hand in { "right", "left" } do
			it("roundtrips " .. ui .. " UI / " .. hand .. " weapon independently", function()
				local p = profile.new(100)
				p.settings.controlLayout = ui
				p.settings.weaponHand = hand
				local loaded = profile.sanitize(p, 200)
				expect(loaded.settings.controlLayout).toBe(ui)
				expect(loaded.settings.weaponHand).toBe(hand)
				loaded.settings.controlLayout = if ui == "right" then "left" else "right"
				expect(profile.sanitize(loaded, 300).settings.weaponHand).toBe(hand)
				loaded.settings.weaponHand = if hand == "right" then "left" else "right"
				expect(profile.sanitize(loaded, 400).settings.controlLayout).toBe(loaded.settings.controlLayout)
			end)
		end
	end
	it("sanitizes invalid values", function()
		expect(preferences.normalize({ controlLayout = {}, weaponHand = 4 })).toEqual({
			controlLayout = "right",
			weaponHand = "right",
		})
	end)
end)
