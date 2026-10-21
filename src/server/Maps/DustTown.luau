--!strict
-- DUST TOWN: a sun-baked adobe town at golden hour. A main street with a fountain plaza
-- in the middle, buildings you can fight through on both sides, flat roofs you can
-- climb, and back alleys for flanking. Point-symmetric: Red owns -X, Blue +X.
--
-- Every lane along the street is broken at least once (statue, wagon, market stall),
-- so fights happen around corners and doorways instead of across the map.

local MapKit = require(script.Parent.MapKit)

local DustTown = {}

DustTown.id = "DustTown"
DustTown.displayName = "Dust Town"
DustTown.description =
	"Adobe streets, a fountain plaza and climbable rooftops. Fight through the cantina or flank down the alleys."
DustTown.ambience = "AmbDustTown"
DustTown.killY = -40
DustTown.extents = { min = Vector2.new(-76, -52), max = Vector2.new(76, 52), top = 30, bottom = -1 }

local rgb = Color3.fromRGB
local M = Enum.Material

local SAND = rgb(222, 186, 130)
local STREET = rgb(176, 136, 92)
local ADOBE = { rgb(214, 160, 110), rgb(200, 140, 96), rgb(226, 182, 132), rgb(190, 128, 88) }
local TRIM = rgb(240, 222, 190)
local WOOD = rgb(112, 72, 40)
local WOOD_LIGHT = rgb(160, 112, 66)
local STONE = rgb(200, 178, 140)
local TEAM = { [1] = rgb(200, 52, 52), [-1] = rgb(48, 110, 210) }
local TEAM_NAME = { [1] = "Red", [-1] = "Blue" }

local X, Z = 76, 52

local p, cf = MapKit.p, MapKit.cf

type Opening = { at: number, width: number, height: number, bottom: number? }
type Openings = { south: { Opening }?, north: { Opening }?, west: { Opening }?, east: { Opening }? }

-- Adobe building in half `s`, corners given in Red-half coordinates (x0 < x1, z0 < z1).
-- Openings are measured from the low corner along each wall. `skip` leaves one roof
-- parapet edge open where stairs arrive.
local function adobe(
	b: MapKit.Builder,
	s: number,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	h: number,
	color: Color3,
	openings: Openings,
	skip: string?
)
	b:wall(p(s, x0, 0, z0), p(s, x1, 0, z0), h, 1, M.Plaster, color, openings.south)
	b:wall(p(s, x0, 0, z1), p(s, x1, 0, z1), h, 1, M.Plaster, color, openings.north)
	b:wall(p(s, x0, 0, z0), p(s, x0, 0, z1), h, 1, M.Plaster, color, openings.west)
	b:wall(p(s, x1, 0, z0), p(s, x1, 0, z1), h, 1, M.Plaster, color, openings.east)
	b:span(
		p(s, x0 - 0.5, h, z0 - 0.5),
		p(s, x1 + 0.5, h + 0.8, z1 + 0.5),
		M.Plaster,
		color:Lerp(TRIM, 0.25),
		{ name = "Roof" }
	)
	local top = h + 0.8
	local edges: { [string]: { Vector3 } } = {
		south = { p(s, x0 - 0.5, top, z0 - 0.5), p(s, x1 + 0.5, top + 1.4, z0 + 0.3) },
		north = { p(s, x0 - 0.5, top, z1 - 0.3), p(s, x1 + 0.5, top + 1.4, z1 + 0.5) },
		west = { p(s, x0 - 0.5, top, z0 - 0.5), p(s, x0 + 0.3, top + 1.4, z1 + 0.5) },
		east = { p(s, x1 - 0.3, top, z0 - 0.5), p(s, x1 + 0.5, top + 1.4, z1 + 0.5) },
	}
	for side, span in edges do
		if side ~= skip then
			b:span(span[1], span[2], M.Plaster, color:Lerp(TRIM, 0.4), { name = "Parapet" })
		end
	end
	-- Vigas: roof beams poking out of the long walls (decoration)
	for x = x0 + 1.5, x1 - 1, 3 do
		for _, z in { z0 - 0.9, z1 + 0.9 } do
			b:cylinder(1.8, 0.6, CFrame.new(p(s, x, h - 0.6, z)) * CFrame.Angles(0, math.rad(90), 0), M.Wood, WOOD, {
				collide = false,
				query = false,
				parent = b.props,
				name = "Viga",
			})
		end
	end
	b:span(p(s, x0 + 0.5, 0, z0 + 0.5), p(s, x1 - 0.5, 0.06, z1 - 0.5), M.CeramicTiles, rgb(176, 96, 64), {
		collide = false,
		query = false,
		name = "Tiles",
	})
end

local function wagon(b: MapKit.Builder, at: CFrame)
	b:box(Vector3.new(4.2, 1.2, 9), at * CFrame.new(0, 2.2, 0), M.WoodPlanks, WOOD_LIGHT, { name = "Wagon" })
	b:box(
		Vector3.new(4.4, 4.2, 7.4),
		at * CFrame.new(0, 4.9, 0.4),
		M.Fabric,
		rgb(236, 226, 204),
		{ name = "WagonCover" }
	)
	for _, z in { -3.2, 3.2 } do
		for _, x in { -2.3, 2.3 } do
			b:cylinder(
				0.4,
				3,
				at * CFrame.new(x, 1.5, z),
				M.Wood,
				WOOD,
				{ collide = false, parent = b.props, name = "Wheel" }
			)
		end
	end
	b:box(Vector3.new(0.3, 0.3, 4), at * CFrame.new(0, 1.6, -6.4), M.Wood, WOOD, { collide = false, parent = b.props })
end

local function stall(b: MapKit.Builder, at: CFrame, canopy: Color3)
	b:box(Vector3.new(7, 3, 2.4), at * CFrame.new(0, 1.5, 0), M.WoodPlanks, WOOD_LIGHT, { name = "StallCounter" })
	for _, x in { -3.3, 3.3 } do
		for _, z in { -1.4, 1.4 } do
			b:box(
				Vector3.new(0.3, 7.5, 0.3),
				at * CFrame.new(x, 3.75, z),
				M.Wood,
				WOOD,
				{ parent = b.props, name = "StallPost" }
			)
		end
	end
	b:box(Vector3.new(8, 0.3, 4), at * CFrame.new(0, 7.6, 0) * CFrame.Angles(math.rad(8), 0, 0), M.Fabric, canopy, {
		collide = false,
		parent = b.props,
		name = "Canopy",
	})
	b:crate(at * CFrame.new(2.4, 4.6, 0), 2.6, WOOD_LIGHT)
	b:crate(at * CFrame.new(2.4, 7.0, 0), 2.2, WOOD_LIGHT)
end

local function cactus(b: MapKit.Builder, position: Vector3, height: number)
	local green = rgb(76, 128, 70)
	b:cylinder(
		height,
		1.6,
		CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		M.Grass,
		green,
		{
			parent = b.props,
			name = "Cactus",
		}
	)
	b:cylinder(
		2.6,
		1,
		CFrame.new(position + Vector3.new(1.2, height * 0.55, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		M.Grass,
		green,
		{
			parent = b.props,
			collide = false,
		}
	)
	b:box(Vector3.new(1.6, 0.9, 0.9), CFrame.new(position + Vector3.new(0.7, height * 0.42, 0)), M.Grass, green, {
		parent = b.props,
		collide = false,
	})
end

local function hay(b: MapKit.Builder, at: CFrame)
	b:box(
		Vector3.new(4, 2.4, 2.6),
		at * CFrame.new(0, 1.2, 0),
		M.Grass,
		rgb(214, 186, 96),
		{ parent = b.props, name = "Hay" }
	)
end

function DustTown.build(): Model
	local b = MapKit.new("DustTown")

	-- Ground, street, outer walls
	b:span(Vector3.new(-X - 30, -4, -Z - 30), Vector3.new(X + 30, 0, Z + 30), M.Sand, SAND, { name = "Ground" })
	-- Desert floor out to the horizon (scenery)
	b:box(Vector3.new(800, 2, 800), CFrame.new(0, -3.2, 0), M.Sand, SAND:Lerp(rgb(200, 150, 100), 0.3), {
		collide = false,
		query = false,
		name = "Desert",
	})
	b:span(
		Vector3.new(-60, 0, -8),
		Vector3.new(60, 0.08, 8),
		M.Ground,
		STREET,
		{ collide = false, query = false, name = "Street" }
	)
	for _, s in { -1, 1 } do
		b:span(
			Vector3.new(-X - 1.5, 0, s * Z),
			Vector3.new(X + 1.5, 9, s * (Z + 1.5)),
			M.Plaster,
			ADOBE[2],
			{ name = "TownWall" }
		)
		b:span(Vector3.new(s * X, 0, -Z), Vector3.new(s * (X + 1.5), 9, Z), M.Plaster, ADOBE[2], { name = "TownWall" })
	end
	-- Mesas on the horizon (scenery only)
	for i, spec in
		{
			{ -170, 40, 60, 50 },
			{ 160, -60, 80, 44 },
			{ 30, 170, 90, 38 },
			{ -40, -175, 70, 46 },
			{ 200, 120, 60, 30 },
			{ -210, -110, 70, 36 },
		}
	do
		b:box(
			Vector3.new(spec[3], spec[4], spec[3] * 0.7),
			CFrame.new(spec[1], spec[4] / 2 - 2, spec[2]) * CFrame.Angles(0, i, 0),
			M.Sandstone,
			rgb(186, 110, 70),
			{
				collide = false,
				query = false,
				name = "Mesa",
			}
		)
	end

	-- Fountain plaza (symmetric on its own)
	b:cylinder(
		1.6,
		13,
		CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
		M.Sandstone,
		STONE,
		{ name = "Basin" }
	)
	b:cylinder(0.2, 11.6, CFrame.new(0, 1.55, 0) * CFrame.Angles(0, 0, math.rad(90)), M.Glass, rgb(70, 150, 190), {
		collide = false,
		query = false,
		transparency = 0.25,
		name = "Water",
	})
	b:box(Vector3.new(3, 6, 3), CFrame.new(0, 3, 0), M.Sandstone, STONE, { name = "Pedestal" })
	b:box(Vector3.new(1.6, 6, 1.6), CFrame.new(0, 9, 0), M.Sandstone, TRIM, { name = "Obelisk" })
	b:wedge(Vector3.new(1.6, 1.4, 1.6), CFrame.new(0, 12.7, 0), M.Sandstone, TRIM, { name = "Cap" })
	b:light(Vector3.new(0, 13.6, 0), rgb(255, 196, 120), 18, 0.6)

	MapKit.both(function(s)
		local team = TEAM[s]

		-- Spawn courtyard: wall with three gates and a blast wall behind each
		b:wall(p(s, -60, 0, -Z), p(s, -60, 0, Z), 10, 1.4, M.Plaster, ADOBE[4], {
			{ at = 22, width = 8, height = 10 },
			{ at = 52, width = 8, height = 10 },
			{ at = 82, width = 8, height = 10 },
		})
		for _, z in { -30, 0, 30 } do
			b:span(p(s, -63, 0, z - 5.5), p(s, -64.2, 9, z + 5.5), M.Plaster, ADOBE[3], { name = "BlastWall" })
			local banner = b:box(
				Vector3.new(0.3, 5, 4),
				cf(s, -64.4, 5, z, 0),
				M.Fabric,
				team,
				{ name = "Banner", collide = false }
			)
			b:sign(banner, Enum.NormalId.Left, TEAM_NAME[s]:upper(), rgb(255, 255, 255))
			for _, dz in { -4.6, 4.6 } do
				b:box(Vector3.new(2, 11.5, 1.4), cf(s, -60, 5.75, z + dz, 0), M.Plaster, TRIM, { name = "GatePost" })
			end
		end
		for _, z in { -42, -28, -14, 0, 14, 28, 42 } do
			b:spawn(TEAM_NAME[s], p(s, -70, 0.5, z), p(s, 0, 0.5, z))
		end
		-- Shade awning at the back of the courtyard
		b:span(p(s, -76, 7.5, -20), p(s, -72, 7.8, 20), M.WoodPlanks, WOOD_LIGHT, { collide = false, name = "Shade" })
		for _, z in { -19, 0, 19 } do
			b:box(Vector3.new(0.4, 7.5, 0.4), cf(s, -72.3, 3.75, z, 0), M.Wood, WOOD, { parent = b.props })
		end
		b:box(Vector3.new(2, 1.6, 6), cf(s, -74, 0.8, -32, 0), M.Wood, WOOD, { parent = b.props, name = "Trough" })

		-- North side of the street (this half)
		adobe(b, s, -50, 12, -32, 26, 11, ADOBE[1], {
			south = { { at = 6, width = 5, height = 8 }, { at = 13, width = 4, height = 7, bottom = 4 } },
			east = { { at = 9, width = 4, height = 8 } },
			north = { { at = 12, width = 4, height = 8 } },
		}, "west")
		local cantina =
			b:box(Vector3.new(10, 2, 0.3), cf(s, -41, 9.5, 11.4, 180), M.WoodPlanks, WOOD, { name = "CantinaSign" })
		b:sign(cantina, Enum.NormalId.Front, "CANTINA", rgb(250, 230, 190))
		b:span(p(s, -48, 0, 21.5), p(s, -38, 3.6, 23), M.WoodPlanks, WOOD, { name = "Bar" })
		b:stairs(p(s, -53, 0, 8.4), MapKit.dir(s, 0, 1), 11.8, 4, M.Plaster, ADOBE[3])

		adobe(b, s, -26, 14, -14, 26, 9, ADOBE[3], {
			south = { { at = 6, width = 4, height = 8 }, { at = 10.4, width = 2.4, height = 7, bottom = 4 } },
			north = { { at = 4, width = 4, height = 8 } },
		})
		local store =
			b:box(Vector3.new(8, 1.8, 0.3), cf(s, -20, 8.2, 13.4, 180), M.WoodPlanks, WOOD, { name = "StoreSign" })
		b:sign(store, Enum.NormalId.Front, "GENERAL STORE", rgb(250, 230, 190))
		b:span(p(s, -25, 0, 23), p(s, -15, 6, 24.5), M.WoodPlanks, WOOD_LIGHT, { name = "Shelves" })

		-- South side of the street (this half)
		adobe(b, s, -44, -26, -28, -12, 10, ADOBE[2], {
			north = {
				{ at = 3.5, width = 3, height = 7.5, bottom = 4.5 } :: Opening,
				{ at = 8, width = 5, height = 8 },
				{ at = 12.5, width = 3, height = 7.5, bottom = 4.5 },
			},
			west = { { at = 4, width = 4, height = 8 } },
		}, "east")
		local sheriff =
			b:box(Vector3.new(9, 1.8, 0.3), cf(s, -36, 9, -11.4, 0), M.WoodPlanks, WOOD, { name = "SheriffSign" })
		b:sign(sheriff, Enum.NormalId.Back, "SHERIFF", rgb(250, 230, 190))
		for _, x in { -40.5, -31.5 } do
			for i = -1, 1 do
				b:box(Vector3.new(0.2, 3, 0.2), cf(s, x + i * 0.9, 6, -12, 0), M.Metal, rgb(40, 40, 44), {
					shotThrough = true,
					name = "Bars",
				})
			end
		end
		b:span(p(s, -42, 0, -24), p(s, -37, 3.4, -22.5), M.WoodPlanks, WOOD, { name = "Desk" })
		b:stairs(p(s, -25, 0, -8.4), MapKit.dir(s, 0, -1), 10.8, 4, M.Plaster, ADOBE[3])

		-- Street furniture
		wagon(b, cf(s, -36, 0, -3, 90))
		stall(b, cf(s, -22, 0, 9.4, 0), team:Lerp(rgb(240, 230, 210), 0.35))
		stall(b, cf(s, -12, 0, -10, 180), rgb(60, 140, 120))
		b:box(Vector3.new(6, 1.8, 2), cf(s, -14, 0.9, 4, 90), M.Wood, WOOD, { name = "Trough" })
		b:barrel(p(s, -48, 0, 9))
		b:barrel(p(s, -46, 0, 10))
		b:crate(cf(s, -27, 2, -9.5, 0), 4)
		-- Plaza benches and planters
		b:box(Vector3.new(5, 1.6, 1.6), cf(s, -9, 0.8, -10.5, 0), M.Sandstone, STONE, { name = "Bench" })
		b:box(Vector3.new(3, 3, 3), cf(s, -10.5, 1.5, 10.5, 0), M.Sandstone, STONE, { name = "Planter" })
		cactus(b, p(s, -10.5, 3, 10.5), 4)

		-- North alley (this half): water tower over a pump house, hay
		adobe(b, s, -27, 36, -21, 42, 7, ADOBE[4], {})
		for _, dx in { -3.5, 3.5 } do
			for _, dz in { -3.5, 3.5 } do
				b:box(Vector3.new(0.7, 16, 0.7), cf(s, -24 + dx, 8, 39 + dz, 0), M.Wood, WOOD, { name = "TowerLeg" })
			end
		end
		b:cylinder(
			7,
			9,
			CFrame.new(p(s, -24, 19.5, 39)) * CFrame.Angles(0, 0, math.rad(90)),
			M.WoodPlanks,
			WOOD_LIGHT,
			{ name = "Tank" }
		)
		hay(b, cf(s, -44, 0, 44, 0))
		hay(b, cf(s, -44, 2.4, 44, 10))
		hay(b, cf(s, -40, 0, 46, 80))
		hay(b, cf(s, -8, 0, 34, 30))
		b:span(p(s, -60, 0, 31), p(s, -50, 3.2, 32), M.Plaster, ADOBE[3], { name = "LowWall" })
		cactus(b, p(s, -12, 0, 47), 7)

		-- South alley (this half): shed, corral, cacti
		adobe(b, s, -10, -44, -2, -36, 8, ADOBE[1], {
			north = { { at = 4, width = 4, height = 7 } },
		})
		b:railing(p(s, -56, 0, -46), p(s, -56, 0, -34), 3.5, WOOD)
		b:railing(p(s, -56, 0, -34), p(s, -46, 0, -34), 3.5, WOOD)
		b:crate(cf(s, -52, 2, -42, 15), 4)
		b:crate(cf(s, -52, 6, -42, 40), 4)
		hay(b, cf(s, -49, 0, -44, 0))
		cactus(b, p(s, -32, 0, -46), 7.5)
		cactus(b, p(s, -22, 0, -32), 6)
		b:span(p(s, -24, 0, -30), p(s, -14, 5.5, -29), M.Plaster, ADOBE[2], { name = "AlleyWall" })
		b:barrel(p(s, -46, 0, -28))
		-- Clutter against the town walls so the wall-hugging lanes don't run end to end
		b:span(p(s, -36, 0, -Z), p(s, -28, 6, -47), M.WoodPlanks, WOOD_LIGHT, { name = "LeanTo" })
		b:wedge(Vector3.new(8, 2, 5), cf(s, -32, 7, -49.5, 0), M.WoodPlanks, WOOD, { name = "LeanToRoof" })
		b:crate(cf(s, -30, 2, 49.5, 0), 4)
		b:crate(cf(s, -30, 6, 49.5, 12), 4)
		b:span(p(s, -5.5, 0, 47), p(s, -2.5, 7, Z), M.WoodPlanks, WOOD, { name = "Outhouse" })
		b:crate(cf(s, -56, 2, -14, 0), 4)
		b:crate(cf(s, -56, 2, 18, 0), 4)
		b:crate(cf(s, -56, 6, 18, 25), 4)

		-- Lamps along the street
		for _, x in { -48, -24 } do
			b:box(
				Vector3.new(0.4, 9, 0.4),
				cf(s, x, 4.5, -8.6, 0),
				M.Metal,
				rgb(40, 40, 44),
				{ parent = b.props, name = "LampPost" }
			)
			b:light(p(s, x, 9.2, -8.6), rgb(255, 196, 120), 22, 0.8)
		end
	end)

	b:bounds(Vector2.new(-X, -Z), Vector2.new(X, Z), -2, 40)
	b:marker("Camera", CFrame.lookAt(Vector3.new(-40, 34, -46), Vector3.new(0, 2, 0)))
	b.model:SetAttribute("MapId", DustTown.id)
	return b.model
end

DustTown.lighting = {
	ClockTime = 16.8,
	Brightness = 2.6,
	Ambient = rgb(96, 78, 66),
	OutdoorAmbient = rgb(150, 120, 100),
	FogEnd = 900,
	FogColor = rgb(230, 190, 150),
	ColorShift_Top = rgb(255, 210, 160),
	ExposureCompensation = 0.1,
	Atmosphere = {
		Density = 0.36,
		Offset = 0.2,
		Haze = 1.6,
		Glare = 0.4,
		Color = rgb(236, 200, 160),
		Decay = rgb(200, 120, 80),
	},
	Grade = { Contrast = 0.12, Saturation = 0.15, Tint = rgb(255, 240, 222) },
	SunRays = 0.08,
}

return DustTown
