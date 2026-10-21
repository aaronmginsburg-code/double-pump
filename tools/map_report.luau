--!nocheck
-- Prints layout numbers for every arena: part count, spawns, standing area, how far you
-- can see (sightline percentiles) and symmetry. Usage: lune run tools/map_report.luau
local Loader = require("../tests/runner/Loader")
local MapGeo = require("../tests/runner/MapGeo")

for _, name in { "Warehouse", "DustTown", "Rooftops" } do
	local ok, moduleScript = pcall(function()
		return Loader.Server.Maps[name]
	end)
	moduleScript = if ok then moduleScript else nil
	if moduleScript then
		local map = Loader.require(moduleScript)
		local model = map.build()
		local parts = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		local solids = MapGeo.solids(model)
		local e = map.extents
		local starts = {}
		for _, s in MapGeo.markers(model, "Spawn") do
			table.insert(starts, s.CFrame.Position)
		end
		local spots = MapGeo.reachable(solids, e.min, e.max, e.top, e.bottom, starts)
		local lengths = MapGeo.sightlines(solids, spots, 200, e.min, e.max)
		print(
			string.format(
				"%-10s parts %4d  spawns %2d  standing spots %4d  sightline p50 %3.0f  p75 %3.0f  p95 %3.0f  max %3.0f  symmetry %.1f%%",
				name,
				parts,
				#MapGeo.markers(model, "Spawn"),
				#spots,
				MapGeo.percentile(lengths, 0.5),
				MapGeo.percentile(lengths, 0.75),
				MapGeo.percentile(lengths, 0.95),
				lengths[#lengths] or 0,
				MapGeo.symmetry(solids) * 100
			)
		)
	end
end
