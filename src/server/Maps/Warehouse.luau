--!strict
-- WAREHOUSE: an indoor logistics hall. Tight aisles between pallet racks, a two-storey
-- site office in the middle with a fightable roof, catwalks along the walls joined to the
-- roof by bridges, and container cover. Point-symmetric: Red owns the -X half, Blue +X.
--
-- Flow: each spawn room has three doors. The centre office is the power position;
-- reaching its roof means crossing open floor or the catwalk bridge, both of which
-- can be contested from the floor. Rack shelves have gaps you can shoot through.

local MapKit = require(script.Parent.MapKit)

local Warehouse = {}

Warehouse.id = "Warehouse"
Warehouse.displayName = "Warehouse"
Warehouse.description =
	"Pallet racks, catwalks and a site office with a roof worth fighting for. Close quarters all over."
Warehouse.ambience = "AmbWarehouse"
Warehouse.killY = -40
-- Playable area, used by the layout checks (tests/maps.spec.luau)
Warehouse.extents = { min = Vector2.new(-72, -46), max = Vector2.new(72, 46), top = 29, bottom = -1 }

local rgb = Color3.fromRGB
local M = Enum.Material

local FLOOR = rgb(118, 118, 122)
local WALL = rgb(150, 156, 164)
local WALL_DARK = rgb(70, 74, 82)
local STEEL = rgb(60, 66, 76)
local BEAM = rgb(232, 120, 40)
local CARDBOARD = rgb(186, 146, 96)
local YELLOW = rgb(250, 200, 40)
local OFFICE = rgb(214, 210, 198)
local TEAM = { [1] = rgb(200, 52, 52), [-1] = rgb(48, 110, 210) }
local TEAM_NAME = { [1] = "Red", [-1] = "Blue" }

local X, Z = 72, 46 -- half extents of the hall interior
local CEILING = 30
local ROOF = 12 -- office roof / catwalk height

local p, cf = MapKit.p, MapKit.cf

-- Pallet rack: uprights, orange beams, three levels of boxes with deliberate gaps.
local function rack(b: MapKit.Builder, at: CFrame, length: number, seed: number)
	local depth, height = 3.6, 15.6
	local bays = math.max(2, math.round(length / 4.5))
	local bay = length / bays
	for i = 0, bays do
		local x = -length / 2 + i * bay
		for _, z in { -depth / 2, depth / 2 } do
			b:box(
				Vector3.new(0.4, height, 0.4),
				at * CFrame.new(x, height / 2, z),
				M.Metal,
				STEEL,
				{ name = "Upright" }
			)
		end
	end
	local levels = { 0.25, 4.1, 7.95, 11.8 }
	for _, y in levels do
		b:box(Vector3.new(length + 0.4, 0.3, depth + 0.4), at * CFrame.new(0, y, 0), M.Metal, BEAM, { name = "Shelf" })
	end
	b:box(Vector3.new(length + 0.4, 0.3, depth + 0.4), at * CFrame.new(0, height, 0), M.Metal, BEAM, { name = "Shelf" })
	local pattern = "XX.XXX.X.XXXX.XX.XX"
	local goodsLevels = table.clone(levels)
	table.insert(goodsLevels, height)
	for level, y in goodsLevels do
		for i = 1, bays do
			local k = (seed + level * 7 + i * 3) % #pattern + 1
			if pattern:sub(k, k) == "X" then
				local h = if (i + level) % 2 == 0 then 3.1 else 2.4
				b:box(
					Vector3.new(bay - 0.7, h, depth - 0.5),
					at * CFrame.new(-length / 2 + (i - 0.5) * bay, y + 0.15 + h / 2, 0),
					M.Cardboard,
					CARDBOARD:Lerp(rgb(120, 90, 60), ((i * 13 + level * 5) % 7) / 14),
					{ name = "Goods", parent = b.props }
				)
			end
		end
	end
end

local function forklift(b: MapKit.Builder, at: CFrame)
	local body = rgb(240, 180, 30)
	local dark = rgb(30, 30, 34)
	b:box(Vector3.new(4, 2.4, 6), at * CFrame.new(0, 1.7, 0), M.Metal, body, { parent = b.props, name = "Forklift" })
	b:box(Vector3.new(3.6, 0.3, 3), at * CFrame.new(0, 5.6, 0.6), M.Metal, dark, { parent = b.props })
	for _, x in { -1.7, 1.7 } do
		b:box(
			Vector3.new(0.25, 3.0, 0.25),
			at * CFrame.new(x, 4.1, 2),
			M.Metal,
			dark,
			{ parent = b.props, collide = false }
		)
		b:box(
			Vector3.new(0.25, 3.0, 0.25),
			at * CFrame.new(x, 4.1, -0.9),
			M.Metal,
			dark,
			{ parent = b.props, collide = false }
		)
		b:box(Vector3.new(0.3, 6, 0.3), at * CFrame.new(x * 0.7, 3, -3.2), M.Metal, dark, { parent = b.props })
		b:box(Vector3.new(0.4, 0.2, 3.4), at * CFrame.new(x * 0.5, 0.5, -4.8), M.Metal, dark, { parent = b.props })
		for _, z in { -1.9, 1.9 } do
			b:cylinder(
				0.8,
				1.4,
				at * CFrame.new(x * 1.2, 0.7, z),
				M.SmoothPlastic,
				dark,
				{ parent = b.props, collide = false }
			)
		end
	end
	b:pallet(at * CFrame.new(0, 0.6, -5.6))
end

function Warehouse.build(): Model
	local b = MapKit.new("Warehouse")

	-- Shell
	b:span(Vector3.new(-X - 2, -2, -Z - 2), Vector3.new(X + 2, 0, Z + 2), M.Concrete, FLOOR, { name = "Floor" })
	b:span(
		Vector3.new(-X - 2, CEILING, -Z - 2),
		Vector3.new(X + 2, CEILING + 1, Z + 2),
		M.Metal,
		WALL_DARK,
		{ name = "Roof" }
	)
	for _, s in { -1, 1 } do
		b:span(Vector3.new(-X - 2, 0, s * Z), Vector3.new(X + 2, CEILING, s * (Z + 2)), M.CorrodedMetal, WALL)
		b:span(Vector3.new(s * X, 0, -Z), Vector3.new(s * (X + 2), CEILING, Z), M.CorrodedMetal, WALL)
	end
	-- Roof trusses and skylight strips (light only, not walkable)
	for x = -60, 60, 20 do
		b:span(
			Vector3.new(x - 0.5, CEILING - 3, -Z),
			Vector3.new(x + 0.5, CEILING, Z),
			M.Metal,
			STEEL,
			{ query = false }
		)
	end
	for x = -50, 50, 20 do
		b:span(
			Vector3.new(x - 3, CEILING - 0.2, -30),
			Vector3.new(x + 3, CEILING + 0.4, 30),
			M.Glass,
			rgb(200, 220, 235),
			{ transparency = 0.45, query = false, shadow = false, name = "Skylight" }
		)
	end
	for x = -60, 60, 24 do
		for z = -32, 32, 16 do
			b:light(Vector3.new(x, CEILING - 3.5, z), rgb(255, 238, 210), 34, 0.9, "Spot")
		end
	end
	-- Floor lane markings
	for _, z in { -14, 14 } do
		b:span(
			Vector3.new(-54, 0, z - 0.25),
			Vector3.new(54, 0.05, z + 0.25),
			M.SmoothPlastic,
			YELLOW,
			{ collide = false, query = false }
		)
	end

	-- Centre office (symmetric itself): walls 11 high, roof slab 11..12
	local OX, OZ = 11, 8
	b:span(
		Vector3.new(-OX - 0.5, ROOF - 1, -OZ - 0.5),
		Vector3.new(OX + 0.5, ROOF, OZ + 0.5),
		M.Concrete,
		rgb(170, 170, 172),
		{ name = "OfficeRoof" }
	)
	b:box(Vector3.new(5, 3.2, 5), CFrame.new(0, ROOF + 1.6, 0), M.Metal, rgb(120, 126, 134), { name = "RoofHatch" })
	b:span(Vector3.new(-1, 0, -3), Vector3.new(1, 3, 3), M.Wood, rgb(120, 86, 56), { name = "Desk" })

	MapKit.both(function(s)
		local team = TEAM[s]
		-- Spawn room: partition with three doors, wall to the ceiling
		b:wall(p(s, -56, 0, -Z), p(s, -56, 0, Z), CEILING, 1.2, M.CorrodedMetal, WALL, {
			{ at = 16, width = 8, height = 10 },
			{ at = 46, width = 8, height = 10 },
			{ at = 76, width = 8, height = 10 },
		})
		for _, z in { -30, 0, 30 } do
			local frame = b:box(Vector3.new(1.4, 1.2, 9), cf(s, -56, 10.6, z), M.Metal, team, { name = "DoorFrame" })
			b:sign(frame, Enum.NormalId.Right, TEAM_NAME[s]:upper(), rgb(255, 255, 255))
		end
		local dock =
			b:box(Vector3.new(0.4, 14, 30), cf(s, -71.7, 8, 0), M.Metal, rgb(90, 96, 108), { name = "RollerDoor" })
		b:sign(dock, Enum.NormalId.Right, if s == 1 then "DOCK A" else "DOCK B", team)
		b:crate(cf(s, -69, 2, -40, 0), 4)
		b:crate(cf(s, -69, 2, 40, 0), 4)
		b:crate(cf(s, -69, 6, 40, 15), 4)
		-- Blast walls just inside each door: nobody can look into the spawn room
		for _, z in { -30, 0, 30 } do
			b:span(p(s, -59.5, 0, z - 5.5), p(s, -60.5, 11, z + 5.5), M.Concrete, WALL_DARK, { name = "BlastWall" })
			b:box(Vector3.new(1.2, 0.6, 11), cf(s, -60, 11.3, z), M.Metal, team, { name = "BlastWallCap" })
		end
		for _, z in { -36, -24, -12, 0, 12, 24, 36 } do
			b:spawn(TEAM_NAME[s], p(s, -65, 0.5, z), p(s, 0, 0.5, z))
		end

		-- Pallet racks
		rack(b, cf(s, -38, 0, -22, 0), 18, 1)
		rack(b, cf(s, -32, 0, 14, 0), 13.5, 4)
		rack(b, cf(s, -44, 0, 26, 90), 9, 9)

		-- Container stack in the near corner, blocks the opposite catwalk's sightline
		b:container(cf(s, -38, 4.25, -40, 90), rgb(40, 120, 90), { label = "DPX 2041" })
		b:container(cf(s, -38, 12.75, -40, 90), team:Lerp(rgb(60, 60, 60), 0.3), { label = "DPX 7730" })
		-- Walk-through container mid-flank
		b:container(cf(s, -24, 4.25, 30, 90), rgb(196, 120, 40), { open = true, length = 16, label = "CARGO" })

		-- Low cover around mid
		b:crate(cf(s, -18, 2, -4, 10), 4)
		b:crate(cf(s, -18, 2, -8.5, -5), 4)
		b:crate(cf(s, -18, 6, -6, 30), 4)
		b:crate(cf(s, -24, 1.5, 4, 0), 3)
		b:pallet(cf(s, -14, 0, 18, 0))
		b:crate(cf(s, -14, 2.1, 18, 0), 3.5)
		b:barrel(p(s, -6, 0, -16))
		b:barrel(p(s, -3.5, 0, -17))
		b:barrel(p(s, -26, 0, -32))
		forklift(b, cf(s, -46, 0, -6, 70))
		-- Crate stacks and jersey barriers to break up the open floor
		b:crate(cf(s, -44, 2, -16, 0), 4)
		b:crate(cf(s, -40, 2, -16, 0), 4)
		b:crate(cf(s, -42, 6, -16, 8), 4)
		b:span(p(s, -30.5, 0, -14), p(s, -29.5, 3.2, -6), M.Concrete, rgb(200, 200, 196), { name = "Barrier" })
		b:crate(cf(s, -14, 2, -28, 0), 4)
		b:crate(cf(s, -14, 6, -28, -12), 4)
		b:crate(cf(s, -10, 2, -28, 5), 4)
		b:span(p(s, -8, 0, -32.5), p(s, 0, 3.2, -31.5), M.Concrete, rgb(200, 200, 196), { name = "Barrier" })
		-- Stock stored under this side's catwalk
		b:crate(cf(s, -20, 2, 42, 0), 4)
		b:crate(cf(s, -20, 6, 42, 10), 4)
		b:crate(cf(s, -24, 2, 42, 0), 4)
		b:pallet(cf(s, -36, 0, 42, 0))
		b:crate(cf(s, -36, 2.1, 42, 0), 3.5)
		b:crate(cf(s, -36, 5.6, 42, 20), 3.5)
		b:crate(cf(s, -48, 2, 31, 0), 4)

		-- Office walls on this side: front face (door) and one long side (door + windows)
		b:wall(p(s, -OX, 0, -OZ), p(s, -OX, 0, OZ), ROOF - 1, 1, M.Concrete, OFFICE, {
			{ at = 11, width = 5, height = 8 },
		})
		b:wall(p(s, -OX, 0, -OZ), p(s, OX, 0, -OZ), ROOF - 1, 1, M.Concrete, OFFICE, {
			{ at = 5, width = 5, height = 8 },
			{ at = 16, width = 6, height = 7.5, bottom = 4.5 },
		})
		-- Window band on the long side (glass is shot-through: you can trade through it)
		b:box(Vector3.new(6, 3, 0.3), cf(s, 5, 6, -OZ, 0), M.Glass, rgb(170, 210, 230), {
			transparency = 0.6,
			shotThrough = true,
			name = "Window",
		})
		-- Stairs up to the office roof along the front face
		b:stairs(p(s, -30.6, 0, -4.5), MapKit.dir(s, 1, 0), ROOF, 5, M.Metal, STEEL)
		b:railing(p(s, -OX, ROOF, OZ), p(s, -9.2, ROOF, OZ), 3, YELLOW)
		b:railing(p(s, -3.8, ROOF, OZ), p(s, OX, ROOF, OZ), 3, YELLOW)
		b:railing(p(s, -OX, ROOF, -1.5), p(s, -OX, ROOF, OZ), 3, YELLOW)

		-- Catwalk along this side's wall, joined to the office roof by a bridge
		b:span(p(s, -54, ROOF - 0.6, Z - 8), p(s, -2, ROOF, Z), M.DiamondPlate, STEEL, { name = "Catwalk" })
		b:railing(p(s, -50.8, ROOF, Z - 8), p(s, -9.5, ROOF, Z - 8), 3, YELLOW)
		b:railing(p(s, -2, ROOF, Z - 8), p(s, -2, ROOF, Z), 3, YELLOW)
		b:span(p(s, -9, ROOF - 0.6, OZ + 0.5), p(s, -4, ROOF, Z - 8), M.DiamondPlate, STEEL, { name = "Bridge" })
		b:railing(p(s, -9, ROOF, OZ + 0.5), p(s, -9, ROOF, Z - 8), 3, YELLOW)
		b:railing(p(s, -4, ROOF, OZ + 0.5), p(s, -4, ROOF, Z - 8), 3, YELLOW)
		-- The catwalk ends at a bulkhead so it can't look down the whole hall
		local bulkhead =
			b:span(p(s, -1.4, ROOF, Z - 8), p(s, -2.4, CEILING, Z), M.CorrodedMetal, WALL_DARK, { name = "Bulkhead" })
		b:sign(bulkhead, if s == 1 then Enum.NormalId.Left else Enum.NormalId.Right, "NO ACCESS", YELLOW)
		-- Hanging tarp between the catwalk and the far side (above head height on the floor)
		b:span(
			p(s, -54, 15, -0.2),
			p(s, -14, CEILING - 3, 0.2),
			M.Fabric,
			team:Lerp(rgb(30, 30, 30), 0.35),
			{ name = "Tarp" }
		)
		for _, x in { -50, -36, -22 } do
			b:box(
				Vector3.new(0.8, ROOF - 0.6, 0.8),
				cf(s, x, (ROOF - 0.6) / 2, Z - 7.6, 0),
				M.Metal,
				STEEL,
				{ name = "CatwalkLeg" }
			)
		end
		-- Stairs from the floor to the catwalk (rising toward this side's back wall)
		b:stairs(p(s, -32, 0, Z - 10.5), MapKit.dir(s, -1, 0), ROOF, 4, M.Metal, STEEL)
		b:span(p(s, -54, ROOF - 0.6, Z - 12.5), p(s, -51, ROOF, Z - 8), M.DiamondPlate, STEEL, { name = "Landing" })
		b:crate(cf(s, -30, ROOF + 1.5, Z - 4, 0), 3)
		b:crate(cf(s, -16, ROOF + 1.5, Z - 4, 20), 3)

		-- Overhead ducts (decoration, above head height)
		b:cylinder(120, 3, CFrame.new(p(s, 0, 25, 34)), M.Metal, rgb(170, 175, 180), { query = false, name = "Duct" })
	end)

	b:bounds(Vector2.new(-X, -Z), Vector2.new(X, Z), -2, CEILING)
	b:marker("Camera", CFrame.lookAt(Vector3.new(-50, 26, -38), Vector3.new(0, 4, 0)))
	b.model:SetAttribute("MapId", Warehouse.id)
	return b.model
end

Warehouse.lighting = {
	ClockTime = 10,
	Brightness = 1.6,
	Ambient = rgb(78, 78, 86),
	OutdoorAmbient = rgb(120, 120, 128),
	FogEnd = 600,
	FogColor = rgb(170, 170, 180),
	ExposureCompensation = 0.25,
	Atmosphere = { Density = 0.32, Haze = 0.6, Color = rgb(200, 196, 190) },
	Grade = { Contrast = 0.1, Saturation = 0.05, Tint = rgb(255, 250, 240) },
}

return Warehouse
