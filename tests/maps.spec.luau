--!nocheck
-- Builds every arena in Lune and checks the layout rules that matter for fairness:
-- enough spawns per team, spawns standing on floor and not inside walls, no spawn
-- that can see an enemy spawn, mirrored geometry, and short sightlines.
local T = require("./runner/T")
local Loader = require("./runner/Loader")
local MapGeo = require("./runner/MapGeo")
local describe, it, expect = T.describe, T.it, T.expect
local Vector3 = Loader.roblox.Vector3

local function v(p)
	return string.format("(%.0f, %.0f, %.0f)", p.X, p.Y, p.Z)
end

local ARENAS = { "Warehouse", "DustTown", "Rooftops" }

for _, name in ARENAS do
	local ok, moduleScript = pcall(function()
		return Loader.Server.Maps[name]
	end)
	moduleScript = if ok then moduleScript else nil
	if not moduleScript then
		continue
	end
	local map = Loader.require(moduleScript)
	local model = map.build()
	local solids = MapGeo.solids(model)
	local spawns = MapGeo.markers(model, "Spawn")

	describe("Map " .. name, function()
		it("has the module fields MapService needs", function()
			expect(map.id).toBe(name)
			expect(typeof(map.displayName)).toBe("string")
			expect(typeof(map.description)).toBe("string")
			expect(typeof(map.lighting)).toBe("table")
			expect(typeof(map.killY)).toBe("number")
		end)

		it("has at least 6 spawns per team", function()
			local counts = { Red = 0, Blue = 0 }
			for _, s in spawns do
				local team = s:GetAttribute("Team")
				counts[team] = (counts[team] or 0) + 1
			end
			expect(counts.Red >= 6).toBe(true)
			expect(counts.Blue).toBe(counts.Red)
		end)

		it("puts every spawn on a floor with headroom", function()
			for _, s in spawns do
				local pos = s.CFrame.Position
				local body = MapGeo.inside(solids, pos + Vector3.new(0, 2.5, 0))
				if body then
					error(`spawn at {v(pos)} is inside {body.name}`)
				end
				local t = MapGeo.cast(solids, pos + Vector3.new(0, 1, 0), pos - Vector3.new(0, 4, 0))
				if not t then
					error(`spawn at {v(pos)} has no floor under it`)
				end
				if not MapGeo.clear(solids, pos + Vector3.new(0, 0.5, 0), pos + Vector3.new(0, 6, 0)) then
					error(`spawn at {v(pos)} has no headroom`)
				end
			end
		end)

		it("has no spawn that can see an enemy spawn", function()
			for _, a in spawns do
				for _, b in spawns do
					if a:GetAttribute("Team") == "Red" and b:GetAttribute("Team") == "Blue" then
						local eyeA = a.CFrame.Position + Vector3.new(0, 4, 0)
						local eyeB = b.CFrame.Position + Vector3.new(0, 4, 0)
						if MapGeo.clear(solids, eyeA, eyeB) then
							error(`Red spawn {v(a.CFrame.Position)} can see Blue spawn {v(b.CFrame.Position)}`)
						end
					end
				end
			end
		end)

		it("is point-symmetric so both teams get the same map", function()
			local symmetry = MapGeo.symmetry(solids)
			if symmetry < 0.97 then
				error(string.format("only %.1f%% of parts have a mirrored twin", symmetry * 100))
			end
		end)

		it("keeps sightlines short", function()
			local extents = map.extents
			local starts = {}
			for _, s in spawns do
				table.insert(starts, s.CFrame.Position)
			end
			local spots = MapGeo.reachable(solids, extents.min, extents.max, extents.top, extents.bottom, starts)
			expect(#spots > 100).toBe(true)
			local lengths = MapGeo.sightlines(solids, spots, 200, extents.min, extents.max)
			local p75 = MapGeo.percentile(lengths, 0.75)
			local p95 = MapGeo.percentile(lengths, 0.95)
			if p75 > 40 or p95 > 80 then
				error(string.format("sightlines too long: p75 %.0f, p95 %.0f studs", p75, p95))
			end
		end)
	end)
end
