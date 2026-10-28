--!nocheck
local T = require("./runner/T")
local Loader = require("./runner/Loader")
local Shared = Loader.Shared
local WeaponConfig = Loader.require(Shared.Config.WeaponConfig)
local Damage = Loader.require(Shared.Weapons.Damage)
local Spread = Loader.require(Shared.Weapons.Spread)
local V3 = Loader.roblox.Vector3
local describe, it, expect = T.describe, T.it, T.expect
local D = WeaponConfig.Damage

local function hits(zone, n, distance)
	local list = {}
	for i = 1, n do
		list[i] = { zone = zone, distance = distance }
	end
	return list
end

describe("Damage", function()
	it("maps R15 parts to zones", function()
		expect(Damage.zoneForPart("Head")).toBe("Head")
		expect(Damage.zoneForPart("UpperTorso")).toBe("Torso")
		expect(Damage.zoneForPart("LeftHand")).toBe("Arm")
		expect(Damage.zoneForPart("RightFoot")).toBe("Leg")
		expect(Damage.zoneForPart("Handle")).toBe(nil)
	end)

	it("applies zone multipliers per pellet", function()
		expect(Damage.pellet(D, "Head", 1)).toBeNear(17 * 1.75)
		expect(Damage.pellet(D, "Torso", 1)).toBeNear(17)
		expect(Damage.pellet(D, "Arm", 1)).toBeNear(17 * 0.9)
		expect(Damage.pellet(D, "Leg", 1)).toBeNear(17 * 0.8)
	end)

	it("a close full headshot kills from 100 HP", function()
		local total, head = Damage.total(D, hits("Head", 10, 5))
		expect(total).toBeAtLeast(100)
		expect(head).toBeTruthy()
	end)

	it("approved Mobile tuning makes a full close body blast lethal", function()
		local total = Damage.total(D, hits("Torso", 10, 5))
		expect(total).toBeNear(170)
		expect(total).toBeAtLeast(100)
	end)

	it("falls off with distance", function()
		expect(Damage.falloff(D, 0)).toBe(1)
		expect(Damage.falloff(D, D.FalloffStart)).toBe(1)
		expect(Damage.falloff(D, D.FalloffEnd)).toBeNear(D.FalloffMinMultiplier)
		expect(Damage.falloff(D, 1000)).toBeNear(D.FalloffMinMultiplier)
		local mid = Damage.falloff(D, (D.FalloffStart + D.FalloffEnd) / 2)
		expect(mid).toBeNear((1 + D.FalloffMinMultiplier) / 2)
		expect(Damage.pellet(D, "Torso", D.MaxRange + 1)).toBe(0)
	end)

	it("long-range shots are much weaker", function()
		local close = Damage.total(D, hits("Torso", 10, 5))
		local far = Damage.total(D, hits("Torso", 10, 40))
		expect(far).toBeLessThan(close * 0.5)
	end)

	it("caps a shot at the theoretical max", function()
		local total = Damage.total(D, hits("Head", 30, 1))
		expect(total).toBeNear(Damage.maxShotDamage(D))
	end)
end)

describe("Spread", function()
	local S = WeaponConfig.Spread
	it("makes 10 deterministic unit pellets", function()
		local a = Spread.directions(S, V3.new(0, 0, -1), 3)
		local b = Spread.directions(S, V3.new(0, 0, -1), 3)
		expect(#a).toBe(10)
		for i = 1, 10 do
			expect(a[i].Magnitude).toBeNear(1, 1e-5)
			expect((a[i] - b[i]).Magnitude).toBeNear(0, 1e-6)
		end
	end)

	it("centre pellet follows the aim exactly", function()
		local aim = V3.new(1, 0.2, -0.5).Unit
		local d = Spread.directions(S, aim, 7)
		expect((d[1] - aim).Magnitude).toBeNear(0, 1e-5)
	end)

	it("pellets sit at the configured angle from the aim", function()
		local aim = V3.new(0, 0, -1)
		local d = Spread.directions(S, aim, 0)
		for i, p in S.Pattern do
			local angle = math.deg(math.acos(math.clamp(d[i]:Dot(aim), -1, 1)))
			expect(angle).toBeNear(p.radius, 1e-3)
		end
	end)

	it("separation grows with distance and the cone is tight up close", function()
		local aim = V3.new(0, 0, -1)
		local d = Spread.directions(S, aim, 0)
		local function width(dist)
			local maxSep = 0
			for i = 1, #d do
				for j = i + 1, #d do
					maxSep = math.max(maxSep, (d[i] * dist - d[j] * dist).Magnitude)
				end
			end
			return maxSep
		end
		expect(width(10)).toBeLessThan(1.5) -- fits a 2-stud-wide torso
		expect(width(40)).toBeNear(width(10) * 4, 1e-3)
	end)

	it("rolls the pattern between shots", function()
		local aim = V3.new(0, 0, -1)
		local a = Spread.directions(S, aim, 1)
		local b = Spread.directions(S, aim, 2)
		expect((a[5] - b[5]).Magnitude).toBeGreaterThan(0.001)
	end)

	it("works when aiming straight up or down", function()
		for _, aim in { V3.new(0, 1, 0), V3.new(0, -1, 0) } do
			local d = Spread.directions(S, aim, 0)
			for i = 1, 10 do
				expect(d[i].Magnitude == d[i].Magnitude).toBeTruthy() -- not NaN
			end
		end
	end)

	it("crouch tightens, airborne widens", function()
		expect(Spread.stateMultiplier(S, true, false)).toBeLessThan(1)
		expect(Spread.stateMultiplier(S, false, true)).toBeGreaterThan(1)
	end)
end)
