--!strict
-- Practice range: always loaded, away from the arenas. Lanes at fixed distances so
-- players can learn the pellet pattern and the falloff, strafing and jumping targets,
-- and a double-pump drill booth. Players wait here when there aren't enough players
-- for a match.

local MapKit = require(script.Parent.MapKit)

local Range = {}

Range.id = "Range"
Range.displayName = "Practice Range"
Range.origin = Vector3.new(-1200, 0, 0) -- far from the arenas

local CONCRETE = Color3.fromRGB(150, 152, 158)
local FLOOR = Color3.fromRGB(92, 96, 104)
local ACCENT = Color3.fromRGB(255, 176, 32)
local DARK = Color3.fromRGB(38, 40, 46)
local WHITE = Color3.fromRGB(240, 240, 235)

function Range.build(): Model
	local b = MapKit.new("Range")
	local o = Range.origin
	local function at(x: number, y: number, z: number): Vector3
		return o + Vector3.new(x, y, z)
	end

	-- Hall: 120 (x) by 84 (z), 26 high. Shooters stand at x < -40, targets downrange (+x).
	b:span(at(-62, -2, -44), at(62, 0, 44), Enum.Material.Concrete, FLOOR, { name = "Floor" })
	b:span(at(-62, 0, -46), at(62, 26, -44), Enum.Material.Concrete, CONCRETE)
	b:span(at(-62, 0, 44), at(62, 26, 46), Enum.Material.Concrete, CONCRETE)
	b:span(at(-64, 0, -46), at(-62, 26, 46), Enum.Material.Concrete, CONCRETE)
	local backstop = b:span(at(62, 0, -46), at(64, 26, 46), Enum.Material.Concrete, DARK)
	b:span(at(-64, 26, -46), at(64, 27, 46), Enum.Material.Metal, DARK, { name = "Ceiling" })
	-- Roof beams and lights
	for x = -50, 50, 20 do
		b:span(
			at(x - 0.6, 23, -44),
			at(x + 0.6, 26, 44),
			Enum.Material.Metal,
			Color3.fromRGB(70, 74, 82),
			{ query = false }
		)
		for z = -30, 30, 20 do
			b:light(at(x, 22.6, z), Color3.fromRGB(255, 244, 225), 40, 1.2, "Spot")
		end
	end
	b:sign(backstop, Enum.NormalId.Left, "DOUBLE PUMP  •  PRACTICE RANGE", ACCENT, { bg = DARK })

	-- Firing line with a low counter, distance markers on the floor
	b:span(
		at(-42, 0, -40),
		at(-41, 2.6, 40),
		Enum.Material.Wood,
		Color3.fromRGB(120, 86, 56),
		{ name = "Counter", shotThrough = true }
	)
	local lanes = { -30, -15, 0, 15, 30 }
	local distances = { 5, 10, 20, 35 }
	for _, z in lanes do
		b:span(
			at(-41, 0.01, z - 0.2),
			at(60, 0.05, z + 0.2),
			Enum.Material.SmoothPlastic,
			ACCENT,
			{ collide = false, query = false }
		)
	end
	for _, d in distances do
		local x = -41 + d
		local stripe = b:span(
			at(x - 0.3, 0.01, -42),
			at(x + 0.3, 0.06, 42),
			Enum.Material.SmoothPlastic,
			WHITE,
			{ collide = false, query = false }
		)
		stripe.Name = "DistanceStripe"
		local post = b:box(
			Vector3.new(4, 2, 0.4),
			CFrame.new(at(x, 20, -43.5)),
			Enum.Material.SmoothPlastic,
			DARK,
			{ query = false }
		)
		b:sign(post, Enum.NormalId.Back, `{d} STUDS`, ACCENT)
	end

	-- Static target dummies at each distance on lanes -30 / -15 / 0
	for i, d in distances do
		local x = -41 + d
		b:marker(
			"Dummy",
			CFrame.lookAt(at(x, 0, lanes[((i - 1) % 3) + 1]), at(-60, 0, lanes[((i - 1) % 3) + 1])),
			{ Kind = "Static" }
		)
	end
	b:marker("Dummy", CFrame.lookAt(at(-31, 0, 0), at(-60, 0, 0)), { Kind = "Static" })
	-- Strafing targets on lane 15 (12 studs) and lane 30 (22 studs)
	b:marker("Dummy", CFrame.lookAt(at(-29, 0, 15), at(-60, 0, 15)), { Kind = "Strafe", Width = 14 })
	b:marker("Dummy", CFrame.lookAt(at(-19, 0, 30), at(-60, 0, 30)), { Kind = "Strafe", Width = 18 })
	-- Jumping target
	b:marker("Dummy", CFrame.lookAt(at(-25, 0, -8), at(-60, 0, -8)), { Kind = "Jump" })

	-- Double-pump drill booth: two dummies close together behind a low wall
	b:span(at(20, 0, 34), at(21, 3, 42), Enum.Material.Concrete, CONCRETE)
	local booth = b:box(
		Vector3.new(0.4, 3, 8),
		CFrame.new(at(-42.2, 6, 34)),
		Enum.Material.SmoothPlastic,
		DARK,
		{ query = false }
	)
	b:sign(booth, Enum.NormalId.Left, "DRILL: FIRE • SWAP • FIRE", ACCENT)
	b:marker("Dummy", CFrame.lookAt(at(-33, 0, 36), at(-60, 0, 36)), { Kind = "Static", Drill = true })
	b:marker("Dummy", CFrame.lookAt(at(-33, 0, 40), at(-60, 0, 40)), { Kind = "Static", Drill = true })

	-- Cover pieces to practise peeking
	b:crate(CFrame.new(at(-10, 2, -30)), 4)
	b:crate(CFrame.new(at(-10, 2, -26)), 4)
	b:crate(CFrame.new(at(-10, 6, -28)), 4)
	b:barrel(at(5, 0, -20))
	b:barrel(at(7.5, 0, -18))

	-- Player area behind the line
	for i = -3, 3 do
		b:spawn("Range", at(-54, 0.5, i * 10), at(60, 0.5, i * 10))
	end
	b:marker("Camera", CFrame.lookAt(at(-55, 12, 0), at(20, 2, 0)))
	local welcome = b:box(
		Vector3.new(0.4, 6, 24),
		CFrame.new(at(-61.6, 9, 0)),
		Enum.Material.SmoothPlastic,
		DARK,
		{ query = false }
	)
	b:sign(welcome, Enum.NormalId.Right, "1 / 2  EQUIP  •  Q  SWAP  •  R  RELOAD  •  HEADSHOTS x1.75", WHITE)
	b:bounds(Vector2.new(o.X - 62, o.Z - 44), Vector2.new(o.X + 62, o.Z + 44), o.Y - 2, o.Y + 26)

	b.model:SetAttribute("MapId", Range.id)
	return b.model
end

Range.lighting = {
	ClockTime = 14,
	Brightness = 1.5,
	Ambient = Color3.fromRGB(80, 80, 88),
	OutdoorAmbient = Color3.fromRGB(110, 110, 120),
	FogEnd = 1000,
	ExposureCompensation = 0.2,
}

return Range
