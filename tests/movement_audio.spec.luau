--!nocheck
local T = require("./runner/T")
local L = require("./runner/Loader")
L.reset()
local C = L.require(L.Shared.Audio.MovementCues)
T.describe("Private movement audio cadence", function()
	T.it("maps actual surfaces to the four approved finishes", function()
		for _, m in { "Metal", "DiamondPlate", "CorrodedMetal" } do
			T.expect(C.surface(m)).toBe("StepMetal")
		end
		for _, m in { "Wood", "WoodPlanks" } do
			T.expect(C.surface(m)).toBe("StepWood")
		end
		for _, m in { "Sand", "Ground" } do
			T.expect(C.surface(m)).toBe("StepSand")
		end
		for _, m in { "Concrete", "Plastic", "Brick", "Asphalt" } do
			T.expect(C.surface(m)).toBe("StepConcrete")
		end
	end)
	T.it("water and air never produce a shoe-on-floor cue", function()
		T.expect(C.surface("Air")).toBe(nil)
		T.expect(C.surface("Water")).toBe(nil)
	end)
	T.it("stationary jitter never accumulates footsteps", function()
		local s = C.new()
		for _ = 1, 100 do
			T.expect(C.advance(s, 0.05, 0.03, true, 0.6, 0, true)).toBe(nil)
		end
	end)
	T.it("distance cadence follows walking instead of elapsed time", function()
		local s, count = C.new(), 0
		for _ = 1, 20 do
			if C.advance(s, 0.05, 1, true, 20, 0, true) then
				count += 1
			end
		end
		T.expect(count).toBe(5)
	end)
	T.it("slower crouch travel naturally has fewer contacts", function()
		local s, count = C.new(), 0
		for _ = 1, 20 do
			if C.advance(s, 0.05, 0.55, true, 11, 0, true) then
				count += 1
			end
		end
		T.expect(count).toBe(2)
	end)
	T.it("no steps while airborne even with full horizontal velocity", function()
		local s = C.new()
		for _ = 1, 20 do
			T.expect(C.advance(s, 0.05, 1, false, 20, -20, true)).toBe(nil)
		end
	end)
	T.it("one landing after a real fall and no concurrent footstep", function()
		local s = C.new()
		C.advance(s, 0.05, 0, true, 0, 0, true)
		C.advance(s, 0.05, 1, false, 20, -10, true)
		C.advance(s, 0.05, 1, false, 20, -15, true)
		T.expect(C.advance(s, 0.05, 1, true, 20, 0, true)).toBe("Landing")
		T.expect(C.advance(s, 0.05, 0, true, 0, 0, true)).toBe(nil)
	end)
	T.it("minor floor flicker never creates a landing", function()
		local s = C.new()
		C.advance(s, 0.05, 0, false, 0, -2, true)
		T.expect(C.advance(s, 0.05, 0, true, 0, 0, true)).toBe(nil)
	end)
	T.it("initial spawn does not imply a landing", function()
		T.expect(C.advance(C.new(), 0.05, 0, true, 0, 0, true)).toBe(nil)
	end)
	T.it("airborne spawn or transfer first establishes a floor silently", function()
		local s = C.new()
		C.advance(s, 0.1, 0, false, 0, -12, true)
		T.expect(C.advance(s, 0.05, 0, true, 0, 0, true)).toBe(nil)
	end)
	T.it("teleports clear distance and airborne history", function()
		local s = C.new()
		C.advance(s, 0.1, 1, false, 20, -20, true)
		T.expect(C.advance(s, 0.05, 100, true, 20, 0, true)).toBe(nil)
		T.expect(C.advance(s, 0.05, 0, true, 0, 0, true)).toBe(nil)
	end)
	T.it("long frame stalls produce no catch-up burst", function()
		local s = C.new()
		T.expect(C.advance(s, 1, 8, true, 20, 0, true)).toBe(nil)
		T.expect(s.travel).toBe(0)
	end)
	T.it("dead frozen menu or excluded states clear pending movement audio", function()
		local s = C.new()
		C.advance(s, 0.1, 1, false, 20, -20, true)
		T.expect(C.advance(s, 0.05, 1, true, 20, 0, false)).toBe(nil)
		T.expect(C.advance(s, 0.05, 0, true, 0, 0, true)).toBe(nil)
	end)
	T.it("at most one contact on a large but valid sample", function()
		local s = C.new()
		T.expect(C.advance(s, 0.2, 10, true, 50, 0, true)).toBe("Step")
		T.expect(C.advance(s, 0.01, 0, true, 50, 0, true)).toBe(nil)
	end)
	T.it("replicated position jumps without velocity do not sound like footsteps", function()
		T.expect(C.advance(C.new(), 0.2, 6, true, 2, 0, true)).toBe(nil)
	end)
end)
L.reset()
