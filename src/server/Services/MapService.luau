--!strict
-- Loads arenas and the practice range, applies each map's lighting, and answers
-- "where are the spawns". Only one arena exists at a time (workspace.Arena); loading a
-- new one destroys the old one first, inside one call, so maps can't overlap.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Collision = require(Shared.Collision)

local Maps = script.Parent.Parent.Maps

local MapService = {}

export type MapModule = {
	id: string,
	displayName: string,
	description: string?,
	build: () -> Model,
	lighting: { [string]: any },
	ambience: string?,
	origin: Vector3?,
}

MapService.Registry = {} :: { [string]: MapModule }
MapService.ArenaIds = {} :: { string }
MapService.currentId = nil :: string?

local arena: Model? = nil
local range: Model? = nil

local function register(module: ModuleScript, isArena: boolean)
	local map = require(module) :: any
	MapService.Registry[map.id] = map
	if isArena then
		table.insert(MapService.ArenaIds, map.id)
	end
end

local function prepare(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("ShotThrough") then
				d.CollisionGroup = Collision.SHOT_THROUGH
			end
			if d:GetAttribute("Barrier") then
				CollectionService:AddTag(d, "Barrier")
			end
		end
	end
end

local function applyLighting(map: MapModule)
	local L: any = map.lighting or {}
	Lighting.ClockTime = L.ClockTime or 14
	Lighting.Brightness = L.Brightness or 2
	Lighting.Ambient = L.Ambient or Color3.fromRGB(70, 70, 70)
	Lighting.OutdoorAmbient = L.OutdoorAmbient or Color3.fromRGB(128, 128, 128)
	Lighting.ColorShift_Top = L.ColorShift_Top or Color3.new(0, 0, 0)
	Lighting.ColorShift_Bottom = L.ColorShift_Bottom or Color3.new(0, 0, 0)
	Lighting.FogEnd = L.FogEnd or 100000
	Lighting.FogColor = L.FogColor or Color3.fromRGB(190, 190, 200)
	Lighting.ExposureCompensation = L.ExposureCompensation or 0
	Lighting.EnvironmentDiffuseScale = L.EnvironmentDiffuseScale or 0.6
	Lighting.EnvironmentSpecularScale = L.EnvironmentSpecularScale or 0.6
	Lighting.GlobalShadows = true

	local function ensure<T>(className: string, name: string): T
		local existing = Lighting:FindFirstChild(name)
		if existing then
			return existing :: any
		end
		local inst = Instance.new(className :: any)
		inst.Name = name
		inst.Parent = Lighting
		return inst :: any
	end
	local atmosphere = ensure("Atmosphere", "MapAtmosphere") :: Atmosphere
	local A = L.Atmosphere or {}
	atmosphere.Density = A.Density or 0.25
	atmosphere.Offset = A.Offset or 0.1
	atmosphere.Color = A.Color or Color3.fromRGB(199, 199, 199)
	atmosphere.Decay = A.Decay or Color3.fromRGB(106, 112, 125)
	atmosphere.Glare = A.Glare or 0
	atmosphere.Haze = A.Haze or 0

	local cc = ensure("ColorCorrectionEffect", "MapGrade") :: ColorCorrectionEffect
	local G = L.Grade or {}
	cc.Brightness = G.Brightness or 0
	cc.Contrast = G.Contrast or 0.08
	cc.Saturation = G.Saturation or 0.1
	cc.TintColor = G.Tint or Color3.new(1, 1, 1)

	local bloom = ensure("BloomEffect", "MapBloom") :: BloomEffect
	bloom.Intensity = 0.35
	bloom.Size = 20
	bloom.Threshold = 1.6

	local sunRays = ensure("SunRaysEffect", "MapSunRays") :: SunRaysEffect
	sunRays.Intensity = L.SunRays or 0.02
	sunRays.Spread = 0.6
end

function MapService.loadRange(): Model
	if range then
		return range
	end
	local map = MapService.Registry.Range
	local model = map.build()
	model.Name = "Range"
	prepare(model)
	model.Parent = workspace
	range = model
	return model
end

-- Builds an arena (destroying the previous one first) and applies its lighting.
function MapService.load(mapId: string): Model
	local map = MapService.Registry[mapId]
	assert(map, "Unknown map " .. tostring(mapId))
	if arena then
		arena:Destroy()
		arena = nil
	end
	local model = map.build()
	model.Name = "Arena"
	model:SetAttribute("MapId", mapId)
	model:SetAttribute("DisplayName", map.displayName)
	model:SetAttribute("Ambience", map.ambience or "")
	prepare(model)
	model.Parent = workspace
	arena = model
	MapService.currentId = mapId
	applyLighting(map)
	return model
end

function MapService.useRangeLighting()
	applyLighting(MapService.Registry.Range)
end

local function markersIn(model: Model?, name: string, team: string?): { BasePart }
	local list = {}
	local markers = model and model:FindFirstChild("Markers")
	if not markers then
		return list
	end
	for _, m in markers:GetChildren() do
		if m.Name == name and m:IsA("BasePart") and (team == nil or m:GetAttribute("Team") == team) then
			table.insert(list, m)
		end
	end
	return list
end

function MapService.spawns(team: string): { BasePart }
	return markersIn(arena, "Spawn", team)
end

function MapService.rangeSpawns(): { BasePart }
	return markersIn(range, "Spawn", "Range")
end

function MapService.rangeDummyMarkers(): { BasePart }
	return markersIn(range, "Dummy", nil)
end

function MapService.cameraPoint(): CFrame?
	local list = markersIn(arena, "Camera", nil)
	return if list[1] then list[1].CFrame else nil
end

-- Geometry the server uses for line-of-sight checks.
function MapService.worldRoots(): { Instance }
	local roots: { Instance } = {}
	if arena then
		table.insert(roots, (arena :: Model):FindFirstChild("Geometry") or arena)
		local props = (arena :: Model):FindFirstChild("Props")
		if props then
			table.insert(roots, props)
		end
	end
	if range then
		table.insert(roots, (range :: Model):FindFirstChild("Geometry") or range)
		local props = (range :: Model):FindFirstChild("Props")
		if props then
			table.insert(roots, props)
		end
	end
	return roots
end

function MapService.arena(): Model?
	return arena
end

function MapService.start()
	register(Maps.Range, false)
	for _, name in { "Warehouse", "DustTown", "Rooftops" } do
		local module = Maps:FindFirstChild(name)
		if module then
			register(module :: ModuleScript, true)
		end
	end
	workspace.FallenPartsDestroyHeight = -120
	MapService.loadRange()
	MapService.useRangeLighting()
end

return MapService
