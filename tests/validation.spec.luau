--!nocheck
local T = require("./runner/T")
local Loader = require("./runner/Loader")
local Shared = Loader.Shared
local SV = Loader.require(Shared.Weapons.ShotValidation)
local PositionHistory = Loader.require(Shared.Weapons.PositionHistory)
local RateLimiter = Loader.require(Shared.Util.RateLimiter)
local V3, CF = Loader.roblox.Vector3, Loader.roblox.CFrame
local describe, it, expect = T.describe, T.it, T.expect

local function check(over)
	local c = {
		origin = V3.new(0, 5, 0),
		direction = V3.new(0, 0, -1),
		hitPosition = V3.new(0, 5, -10),
		partCFrame = CF.new(0, 5, -10.5),
		partSize = V3.new(2, 2, 1),
		maxRange = 150,
		rayTolerance = 1.25,
		hitboxTolerance = 3,
	}
	for k, v in over or {} do
		c[k] = v
	end
	return SV.checkHit(c)
end

describe("ShotValidation", function()
	it("accepts a hit on the ray and the part", function()
		local ok, why, d = check()
		expect(ok).toBeTruthy()
		expect(why).toBe(nil)
		expect(d).toBeNear(10)
	end)
	it("rejects hits behind the shooter", function()
		local ok, why = check({ hitPosition = V3.new(0, 5, 10), partCFrame = CF.new(0, 5, 10) })
		expect(ok).toBeFalsy()
		expect(why).toBe("Behind")
	end)
	it("rejects hits beyond max range", function()
		local ok, why = check({ hitPosition = V3.new(0, 5, -200), partCFrame = CF.new(0, 5, -200) })
		expect(why).toBe("Range")
	end)
	it("rejects a hit point that isn't on the pellet line", function()
		local ok, why = check({ hitPosition = V3.new(6, 5, -10), partCFrame = CF.new(6, 5, -10) })
		expect(ok).toBeFalsy()
		expect(why).toBe("OffRay")
	end)
	it("rejects a hit on a part that the server says was elsewhere", function()
		local ok, why = check({ partCFrame = CF.new(0, 5, -30) })
		expect(ok).toBeFalsy()
		expect(why).toBe("OffTarget")
	end)
	it("rejects NaN and huge vectors", function()
		expect(SV.isFiniteVector(V3.new(0 / 0, 0, 0))).toBeFalsy()
		expect(SV.isFiniteVector(V3.new(math.huge, 0, 0))).toBeFalsy()
		expect(SV.isFiniteVector(V3.new(1e7, 0, 0), 1e5)).toBeFalsy()
		expect(SV.isFiniteVector("hello")).toBeFalsy()
		expect(SV.isFiniteVector(V3.new(1, 2, 3))).toBeTruthy()
	end)
	it("box distance is zero inside", function()
		expect(SV.distanceToBox(V3.new(0.5, 0, 0), CF.new(), V3.new(2, 2, 2))).toBe(0)
		expect(SV.distanceToBox(V3.new(3, 0, 0), CF.new(), V3.new(2, 2, 2))).toBeNear(2)
	end)
	it("scales tolerance with ping and caps it", function()
		expect(SV.scaled(3, 20, 9, 0.1)).toBeNear(5)
		expect(SV.scaled(3, 20, 9, 5)).toBe(9)
	end)
end)

describe("PositionHistory", function()
	it("interpolates between snapshots", function()
		local h = PositionHistory.new(1)
		h:record(0, { Head = CF.new(0, 0, 0) })
		h:record(0.1, { Head = CF.new(10, 0, 0) })
		expect(h:sample("Head", 0.05).Position.X).toBeNear(5)
		expect(h:sample("Head", 5).Position.X).toBeNear(10)
		expect(h:sample("Head", -5).Position.X).toBeNear(0)
	end)
	it("forgets snapshots older than maxAge", function()
		local h = PositionHistory.new(0.5)
		for i = 0, 100 do
			h:record(i * 0.05, { Head = CF.new(i, 0, 0) })
		end
		expect(#h.snapshots).toBeLessThan(15)
	end)
end)

describe("RateLimiter", function()
	it("allows a burst then throttles, then refills", function()
		local r = RateLimiter.new(3, 1)
		expect(r:allow("p", 0)).toBeTruthy()
		expect(r:allow("p", 0)).toBeTruthy()
		expect(r:allow("p", 0)).toBeTruthy()
		expect(r:allow("p", 0)).toBeFalsy()
		expect(r:allow("p", 1.01)).toBeTruthy()
		expect(r:allow("q", 0)).toBeTruthy()
	end)
end)
