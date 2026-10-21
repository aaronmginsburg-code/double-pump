--!nocheck
-- Exports an arena's parts and lights to JSON so tools/render_maps.py can render
-- previews (vote-card art, docs). Usage: lune run tools/export_map.luau <MapId> <out.json>
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local Loader = require("../tests/runner/Loader")

local mapId, outPath = process.args[1], process.args[2]
local map = Loader.require(Loader.Server.Maps[mapId])
local model = map.build()

local function color(c)
	return { c.R, c.G, c.B }
end

local parts, lights = {}, {}
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") and d.Parent and d.Parent.Name ~= "Markers" and d.Transparency < 1 then
		local shape = "Block"
		if d:IsA("WedgePart") then
			shape = "Wedge"
		elseif d:IsA("Part") and d.Shape.Name == "Cylinder" then
			shape = "Cylinder"
		end
		table.insert(parts, {
			name = d.Name,
			shape = shape,
			size = { d.Size.X, d.Size.Y, d.Size.Z },
			cframe = { d.CFrame:GetComponents() },
			color = color(d.Color),
			material = d.Material.Name,
			transparency = d.Transparency,
		})
	elseif d:IsA("PointLight") or d:IsA("SpotLight") then
		local p = d.Parent.CFrame.Position
		table.insert(lights, {
			kind = d.ClassName,
			position = { p.X, p.Y, p.Z },
			color = color(d.Color),
			range = d.Range,
			brightness = d.Brightness,
		})
	end
end

local L = map.lighting or {}
local function maybeColor(c)
	return if c then color(c) else nil
end
local out = {
	id = map.id,
	name = map.displayName,
	parts = parts,
	lights = lights,
	lighting = {
		clockTime = L.ClockTime or 14,
		brightness = L.Brightness or 2,
		ambient = maybeColor(L.Ambient),
		outdoorAmbient = maybeColor(L.OutdoorAmbient),
		fogColor = maybeColor(L.FogColor),
		atmosphereColor = maybeColor(L.Atmosphere and L.Atmosphere.Color),
	},
	extents = { map.extents.min.X, map.extents.min.Y, map.extents.max.X, map.extents.max.Y },
}
fs.writeFile(outPath, serde.encode("json", out))
print(`exported {#parts} parts, {#lights} lights to {outPath}`)
