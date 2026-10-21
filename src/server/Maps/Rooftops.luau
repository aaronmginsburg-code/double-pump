--!strict
-- ROOFTOPS: neon-lit city roofs at night, high above the street. Roofs are joined by
-- short bridges and stairs over drops; fall and you're out. Cover comes from machine
-- rooms, AC units, billboards and water tanks. Point-symmetric: Red owns -X, Blue +X.
--
-- Layout: spawn roof (raised) -> wide block roof with a penthouse -> centre roof with a
-- lift machine room. North and south roofs give each team a flank route.

local MapKit = require(script.Parent.MapKit)

local Rooftops = {}

Rooftops.id = "Rooftops"
Rooftops.displayName = "Rooftops"
Rooftops.description = "Neon city roofs joined by narrow bridges. Short gaps, long drops: watch your footing."
Rooftops.ambience = "AmbRooftops"
Rooftops.killY = -30
Rooftops.extents = { min = Vector2.new(-70, -42), max = Vector2.new(70, 42), top = 30, bottom = -30 }

local rgb = Color3.fromRGB
local M = Enum.Material

local ROOF = rgb(78, 82, 92)
local ROOF_LIGHT = rgb(104, 108, 118)
local FACADE = rgb(52, 56, 68)
local STEEL = rgb(46, 50, 58)
local TRIM = rgb(150, 156, 168)
local NEON_PINK = rgb(255, 60, 170)
local NEON_CYAN = rgb(40, 230, 255)
local NEON_AMBER = rgb(255, 170, 40)
local TEAM = { [1] = rgb(220, 60, 60), [-1] = rgb(60, 130, 240) }
local TEAM_NAME = { [1] = "Red", [-1] = "Blue" }

local BUILDING_BOTTOM = -60 -- buildings are solid blocks down to here; the street is far below

local p, cf = MapKit.p, MapKit.cf

-- A building: solid block from far below up to `top`, with a lip around the roof.
local function building(
	b: MapKit.Builder,
	s: number,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	top: number,
	color: Color3
)
	b:span(p(s, x0, BUILDING_BOTTOM, z0), p(s, x1, top, z1), M.Concrete, color, { name = "Building" })
	b:span(p(s, x0 + 0.2, top, z0 + 0.2), p(s, x1 - 0.2, top + 0.15, z1 - 0.2), M.Asphalt, ROOF, {
		collide = false,
		query = false,
		name = "RoofSurface",
	})
	-- Lit window bands on the facades (scenery)
	for y = top - 6, top - 30, -6 do
		for _, zEdge in { z0 - 0.15, z1 + 0.15 } do
			b:span(
				p(s, x0 + 1, y - 1.2, zEdge - 0.1),
				p(s, x1 - 1, y, zEdge + 0.1),
				M.Neon,
				rgb(255, 214, 150):Lerp(FACADE, 0.55),
				{
					collide = false,
					query = false,
					shadow = false,
					name = "WindowBand",
				}
			)
		end
	end
end

-- Low wall (lip) along a roof edge, crouch-height cover.
local function lip(b: MapKit.Builder, a: Vector3, c: Vector3)
	b:span(a, c + Vector3.new(0, 1.6, 0), M.Concrete, ROOF_LIGHT, { name = "Lip" })
end

-- Flat bridge between two roofs with railings both sides (rails don't stop pellets).
local function bridge(b: MapKit.Builder, a: Vector3, c: Vector3, width: number)
	local along = (c - a).Unit
	local side = along:Cross(Vector3.yAxis) * (width / 2)
	b:span(a - side - Vector3.new(0, 0.5, 0), c + side, M.DiamondPlate, STEEL, { name = "Bridge" })
	b:railing(a + side, c + side, 3, TRIM)
	b:railing(a - side, c - side, 3, TRIM)
end

local function acUnit(b: MapKit.Builder, at: CFrame)
	b:box(Vector3.new(4, 3.2, 6), at * CFrame.new(0, 1.6, 0), M.Metal, rgb(170, 176, 184), { name = "ACUnit" })
	b:cylinder(0.3, 2.6, at * CFrame.new(0, 3.35, 1.4) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, STEEL, {
		collide = false,
		parent = b.props,
	})
	b:cylinder(0.3, 2.6, at * CFrame.new(0, 3.35, -1.4) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, STEEL, {
		collide = false,
		parent = b.props,
	})
end

local function waterTank(b: MapKit.Builder, base: Vector3)
	for _, dx in { -2.6, 2.6 } do
		for _, dz in { -2.6, 2.6 } do
			b:box(
				Vector3.new(0.5, 9, 0.5),
				CFrame.new(base + Vector3.new(dx, 4.5, dz)),
				M.Metal,
				STEEL,
				{ name = "TankLeg" }
			)
		end
	end
	b:cylinder(
		7,
		7,
		CFrame.new(base + Vector3.new(0, 12.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		M.WoodPlanks,
		rgb(120, 82, 54),
		{
			name = "Tank",
		}
	)
	b:wedge(
		Vector3.new(7, 2, 7),
		CFrame.new(base + Vector3.new(0, 17, 0)),
		M.Metal,
		STEEL,
		{ collide = false, name = "TankRoof" }
	)
end

local function billboard(b: MapKit.Builder, at: CFrame, text: string, color: Color3)
	for _, x in { -5, 5 } do
		b:box(Vector3.new(0.6, 9, 0.6), at * CFrame.new(x, 4.5, 0), M.Metal, STEEL, { name = "BillboardLeg" })
	end
	local board = b:box(
		Vector3.new(14, 6, 0.6),
		at * CFrame.new(0, 10, 0),
		M.SmoothPlastic,
		rgb(20, 20, 28),
		{ name = "Billboard" }
	)
	b:sign(board, Enum.NormalId.Front, text, color, { font = Enum.Font.LuckiestGuy })
	b:sign(board, Enum.NormalId.Back, text, color, { font = Enum.Font.LuckiestGuy })
	b:box(
		Vector3.new(14.4, 0.3, 0.3),
		at * CFrame.new(0, 13.2, -0.4),
		M.Neon,
		color,
		{ collide = false, query = false, name = "BillboardNeon" }
	)
	b:light((at * CFrame.new(0, 12, -2)).Position, color, 20, 1.2)
end

function Rooftops.build(): Model
	local b = MapKit.new("Rooftops")

	-- Centre roof (symmetric on its own) with the lift machine room
	building(b, 1, -14, -14, 14, 14, 0, FACADE)
	b:box(Vector3.new(8, 6.5, 8), CFrame.new(0, 3.25, 0), M.Concrete, ROOF_LIGHT, { name = "MachineRoom" })
	b:box(Vector3.new(8.6, 0.5, 8.6), CFrame.new(0, 6.75, 0), M.Metal, STEEL, { name = "MachineRoomRoof" })
	b:light(Vector3.new(0, 7.4, 0), NEON_AMBER, 18, 0.8)

	-- The city below and around (scenery only: not solid, not hit by shots)
	b:box(
		Vector3.new(900, 2, 900),
		CFrame.new(0, -200, 0),
		M.Asphalt,
		rgb(20, 20, 26),
		{ collide = false, query = false, name = "Street" }
	)
	local rng = Random.new(41)
	for i = 1, 70 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(110, 330)
		local w, d = rng:NextNumber(18, 40), rng:NextNumber(18, 40)
		local h = rng:NextNumber(120, 260)
		local x, z = math.cos(angle) * dist, math.sin(angle) * dist
		local tower = b:box(
			Vector3.new(w, h, d),
			CFrame.new(x, -200 + h / 2, z),
			M.Concrete,
			FACADE:Lerp(rgb(30, 32, 44), rng:NextNumber()),
			{
				collide = false,
				query = false,
				shadow = false,
				name = "CityTower",
			}
		)
		if i % 3 == 0 then
			local neon = ({ NEON_PINK, NEON_CYAN, NEON_AMBER })[(i // 3) % 3 + 1]
			b:box(Vector3.new(w + 0.4, 1, 0.4), tower.CFrame * CFrame.new(0, h / 2 - 3, -d / 2), M.Neon, neon, {
				collide = false,
				query = false,
				shadow = false,
				name = "CityNeon",
			})
		end
	end

	MapKit.both(function(s)
		local team = TEAM[s]

		-- Spawn roof (raised 4) with a parapet, three exits and blast walls
		building(b, s, -70, -34, -52, 34, 4, FACADE:Lerp(team, 0.12))
		b:wall(p(s, -52.6, 4, -34), p(s, -52.6, 4, 34), 6, 1.2, M.Concrete, ROOF_LIGHT, {
			{ at = 10, width = 6, height = 6 },
			{ at = 34, width = 6, height = 6 },
			{ at = 58, width = 6, height = 6 },
		})
		for _, z in { -24, 0, 24 } do
			b:span(p(s, -56, 4, z - 4.5), p(s, -57, 11, z + 4.5), M.Concrete, ROOF_LIGHT, { name = "BlastWall" })
			b:box(
				Vector3.new(1.2, 0.4, 9),
				cf(s, -56.5, 11.2, z, 0),
				M.Neon,
				team,
				{ collide = false, query = false, name = "BlastWallStrip" }
			)
			-- Stairs down onto the next roof
			b:stairs(p(s, -46, 0, z), MapKit.dir(s, -1, 0), 4, 5, M.DiamondPlate, STEEL)
			b:railing(p(s, -52, 0, z - 2.7), p(s, -46, 0, z - 2.7), 4, TRIM)
			b:railing(p(s, -52, 0, z + 2.7), p(s, -46, 0, z + 2.7), 4, TRIM)
		end
		for _, z in { -30, -20, -10, 0, 10, 20, 30 } do
			b:spawn(TEAM_NAME[s], p(s, -63, 4.5, z), p(s, 0, 4.5, z))
		end
		b:box(Vector3.new(5, 7, 9), cf(s, -67.5, 7.5, -15, 0), M.Concrete, ROOF_LIGHT, { name = "Stairwell" })
		acUnit(b, cf(s, -67, 4, 26, 0))
		local spawnSign = b:box(
			Vector3.new(0.4, 3, 12),
			cf(s, -69.6, 8, 0, 0),
			M.SmoothPlastic,
			rgb(16, 16, 22),
			{ name = "TeamSign" }
		)
		b:sign(spawnSign, Enum.NormalId.Right, TEAM_NAME[s]:upper() .. " ROOF", team)

		-- Main block roof with a penthouse
		building(b, s, -46, -40, -20, 40, 0, FACADE)
		b:wall(
			p(s, -40, 0, -10),
			p(s, -28, 0, -10),
			8,
			1,
			M.Concrete,
			rgb(200, 200, 206),
			{ { at = 6, width = 4, height = 7 } }
		)
		b:wall(
			p(s, -40, 0, 10),
			p(s, -28, 0, 10),
			8,
			1,
			M.Concrete,
			rgb(200, 200, 206),
			{ { at = 3, width = 3, height = 6.5, bottom = 3.5 } }
		)
		b:wall(
			p(s, -40, 0, -10),
			p(s, -40, 0, 10),
			8,
			1,
			M.Concrete,
			rgb(200, 200, 206),
			{ { at = 14, width = 4, height = 7 } }
		)
		b:wall(p(s, -28, 0, -10), p(s, -28, 0, 10), 8, 1, M.Concrete, rgb(200, 200, 206), {
			{ at = 6, width = 4, height = 7 },
			{ at = 13, width = 4, height = 6.5, bottom = 3.5 },
		})
		b:span(p(s, -40.5, 8, -10.5), p(s, -27.5, 8.6, 10.5), M.Concrete, ROOF_LIGHT, { name = "PenthouseRoof" })
		b:light(p(s, -34, 7.4, 0), rgb(255, 220, 180), 16, 0.7)
		acUnit(b, cf(s, -42, 0, 26, 0))
		acUnit(b, cf(s, -24, 0, -26, 90))
		waterTank(b, p(s, -26, 0, 30))
		billboard(b, cf(s, -34, 0, -36, 0), "PUMP-O  COLA", NEON_PINK)
		lip(b, p(s, -46, 0, 39), p(s, -30, 0, 40))
		lip(b, p(s, -44, 0, -18), p(s, -36, 0, -17))
		b:box(
			Vector3.new(6, 0.8, 4),
			cf(s, -24, 0.4, 14, 0),
			M.Glass,
			rgb(150, 200, 220),
			{ transparency = 0.4, name = "Skylight" }
		)
		b:box(Vector3.new(2.4, 5, 2.4), cf(s, -32, 2.5, 20, 0), M.Metal, STEEL, { name = "VentStack" })
		b:box(Vector3.new(2.4, 5, 2.4), cf(s, -38, 2.5, -26, 0), M.Metal, STEEL, { name = "VentStack" })

		-- Bridges from the main block to the centre roof
		for _, z in { -9, 9 } do
			bridge(b, p(s, -20, 0, z), p(s, -14, 0, z), 4.5)
		end

		-- Flank roof (north for Red, south for Blue), slightly raised
		building(b, s, -14, 20, 14, 40, 2, FACADE:Lerp(rgb(60, 50, 80), 0.4))
		b:stairs(p(s, -7, 0, 16.8), MapKit.dir(s, 0, 1), 2, 4, M.DiamondPlate, STEEL)
		b:span(p(s, -9, -0.5, 14), p(s, -5, 0, 16.8), M.DiamondPlate, STEEL, { name = "Bridge" })
		b:railing(p(s, -9.2, 0, 14), p(s, -9.2, 0, 20), 3, TRIM)
		b:railing(p(s, -4.8, 0, 14), p(s, -4.8, 0, 20), 3, TRIM)
		b:stairs(p(s, -17.2, 0, 32), MapKit.dir(s, 1, 0), 2, 4, M.DiamondPlate, STEEL)
		b:span(p(s, -20, -0.5, 30), p(s, -17.2, 0, 34), M.DiamondPlate, STEEL, { name = "Bridge" })
		b:railing(p(s, -20, 0, 29.8), p(s, -14, 0, 29.8), 3, TRIM)
		b:railing(p(s, -20, 0, 34.2), p(s, -14, 0, 34.2), 3, TRIM)
		b:box(Vector3.new(7, 7, 6), cf(s, 4, 5.5, 30, 0), M.Concrete, ROOF_LIGHT, { name = "Shed" })
		for i, x in { -10, -4, 9 } do
			b:box(
				Vector3.new(3.4, 3, 3.4),
				cf(s, x, 3.5, if i == 2 then 36 else 25, 0),
				M.WoodPlanks,
				rgb(110, 76, 50),
				{ name = "Planter" }
			)
		end
		lip(b, p(s, -14, 2, 39), p(s, 14, 2, 40))
		b:box(Vector3.new(4, 4, 8), cf(s, -2, 4, 24, 90), M.Concrete, ROOF_LIGHT, { name = "Hatch" })
		billboard(b, cf(s, 10, 2, 39, 180), "DOUBLE PUMP", NEON_CYAN)

		-- Centre roof cover (this half)
		b:box(Vector3.new(3, 3.2, 5), cf(s, -9, 1.6, -5, 0), M.Metal, rgb(170, 176, 184), { name = "ACUnit" })
		b:box(Vector3.new(2, 4.8, 2), cf(s, -6, 2.4, 9, 0), M.Metal, STEEL, { name = "VentStack" })
		lip(b, p(s, -12, 0, -14), p(s, -4, 0, -13))
		b:light(p(s, -10, 4, 10), NEON_PINK, 14, 0.8)
		b:light(p(s, -40, 4, -32), NEON_CYAN, 18, 0.8)
		b:light(p(s, -60, 9, 0), team, 22, 0.7)
	end)

	b:bounds(Vector2.new(-70, -42), Vector2.new(70, 42), -40, 30)
	b:marker("Camera", CFrame.lookAt(Vector3.new(-48, 32, -50), Vector3.new(0, 0, 0)))
	b.model:SetAttribute("MapId", Rooftops.id)
	return b.model
end

Rooftops.lighting = {
	ClockTime = 20.6,
	Brightness = 1.2,
	Ambient = rgb(70, 70, 100),
	OutdoorAmbient = rgb(90, 90, 130),
	FogEnd = 700,
	FogColor = rgb(40, 40, 70),
	ExposureCompensation = 0.6,
	EnvironmentDiffuseScale = 0.4,
	Atmosphere = { Density = 0.4, Offset = 0.05, Haze = 1.4, Color = rgb(90, 80, 140), Decay = rgb(60, 40, 90) },
	Grade = { Contrast = 0.15, Saturation = 0.2, Tint = rgb(230, 230, 255) },
}

return Rooftops
