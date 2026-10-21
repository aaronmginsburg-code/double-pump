--!strict
-- Small toolkit for building arenas out of parts in code. Every map module uses it, so
-- maps are diffable text, rebuild identically every round, and can also be exported to
-- .rbxm files for editing in Studio (tools/build_maps.luau).
--
-- Conventions: +Y up, map centred on the origin, Red spawns on -X, Blue spawns on +X.
-- Only Instance.new and datatypes are used here (no services), so it also runs in Lune.

local MapKit = {}
MapKit.__index = MapKit

export type PartOptions = {
	transparency: number?,
	collide: boolean?,
	shotThrough: boolean?, -- players collide, pellets pass (railings, chain-link)
	query: boolean?,
	shadow: boolean?,
	reflectance: number?,
	shape: Enum.PartType?,
	name: string?,
	parent: any,
}

export type Builder = typeof(setmetatable(
	{} :: {
		model: Model,
		geometry: Folder,
		props: Folder,
		markers: Folder,
		lights: Folder,
		count: number,
	},
	MapKit
))

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function MapKit.new(name: string): Builder
	local model = Instance.new("Model")
	model.Name = name
	return setmetatable({
		model = model,
		geometry = folder("Geometry", model),
		props = folder("Props", model),
		markers = folder("Markers", model),
		lights = folder("Lights", model),
		count = 0,
	}, MapKit)
end

function MapKit.box(
	self: Builder,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3,
	opts: PartOptions?
): Part
	local o = (opts or {}) :: PartOptions
	local part = Instance.new("Part")
	part.Name = o.name or "Part"
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Material = material
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if o.shape then
		part.Shape = o.shape
	end
	if o.transparency then
		part.Transparency = o.transparency
	end
	if o.reflectance then
		part.Reflectance = o.reflectance
	end
	if o.collide == false then
		part.CanCollide = false
	end
	if o.query == false then
		part.CanQuery = false
	end
	if o.shadow == false then
		part.CastShadow = false
	end
	part.CanTouch = false
	if o.shotThrough then
		part:SetAttribute("ShotThrough", true)
	end
	part.Parent = o.parent or self.geometry
	self.count += 1
	return part
end

-- Box from two opposite corners (handy for floors and walls laid out on a grid).
function MapKit.span(
	self: Builder,
	a: Vector3,
	b: Vector3,
	material: Enum.Material,
	color: Color3,
	opts: PartOptions?
): Part
	local minV = a:Min(b)
	local maxV = a:Max(b)
	return self:box(maxV - minV, CFrame.new((minV + maxV) / 2), material, color, opts)
end

function MapKit.wedge(
	self: Builder,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3,
	opts: PartOptions?
): WedgePart
	local o = (opts or {}) :: PartOptions
	local part = Instance.new("WedgePart")
	part.Name = o.name or "Wedge"
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Material = material
	part.Color = color
	part.CanTouch = false
	if o.collide == false then
		part.CanCollide = false
	end
	part.Parent = o.parent or self.geometry
	self.count += 1
	return part
end

function MapKit.cylinder(
	self: Builder,
	length: number,
	diameter: number,
	cf: CFrame,
	material: Enum.Material,
	color: Color3,
	opts: PartOptions?
): Part
	local o = table.clone(opts or {}) :: PartOptions
	o.shape = Enum.PartType.Cylinder
	return self:box(Vector3.new(length, diameter, diameter), cf, material, color, o)
end

-- Invisible wall that stops players but not pellets or the camera.
function MapKit.barrier(self: Builder, a: Vector3, b: Vector3)
	local part = self:span(a, b, Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), {
		transparency = 1,
		query = false,
		shadow = false,
		name = "Barrier",
	})
	part:SetAttribute("Barrier", true)
	return part
end

-- Straight staircase rising along `forward` (unit, horizontal) from `bottom` (top surface
-- of the floor at the first step's front edge) up `height` studs.
function MapKit.stairs(
	self: Builder,
	bottom: Vector3,
	forward: Vector3,
	height: number,
	width: number,
	material: Enum.Material,
	color: Color3,
	stepHeight: number?
)
	local rise = stepHeight or 1
	local steps = math.max(1, math.round(height / rise))
	rise = height / steps
	local run = 1.6
	local right = forward:Cross(Vector3.yAxis)
	for i = 1, steps do
		local top = bottom.Y + rise * i
		local center = bottom + forward * (run * (i - 0.5))
		local cf = CFrame.fromMatrix(
			Vector3.new(center.X, (bottom.Y + top) / 2 - 0.0, center.Z),
			right,
			Vector3.yAxis,
			-forward
		)
		self:box(Vector3.new(width, top - bottom.Y, run), cf, material, color, { name = "Step" })
	end
	return bottom + forward * (run * steps) + Vector3.new(0, height, 0)
end

-- Railing along a line (shots pass through, players are stopped).
function MapKit.railing(self: Builder, a: Vector3, b: Vector3, height: number, color: Color3)
	local dir = b - a
	local length = dir.Magnitude
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b)
	self:box(
		Vector3.new(0.25, 0.25, length),
		cf + Vector3.new(0, height, 0),
		Enum.Material.Metal,
		color,
		{ shotThrough = true, name = "Rail" }
	)
	self:box(
		Vector3.new(0.18, 0.18, length),
		cf + Vector3.new(0, height * 0.5, 0),
		Enum.Material.Metal,
		color,
		{ shotThrough = true, name = "Rail" }
	)
	local posts = math.max(2, math.floor(length / 5) + 1)
	for i = 0, posts - 1 do
		local p = a:Lerp(b, i / (posts - 1))
		self:box(
			Vector3.new(0.25, height, 0.25),
			CFrame.new(p + Vector3.new(0, height / 2, 0)),
			Enum.Material.Metal,
			color,
			{ shotThrough = true, name = "Post" }
		)
	end
end

function MapKit.light(
	self: Builder,
	position: Vector3,
	color: Color3,
	range: number,
	brightness: number,
	kind: string?
): Part
	local holder = self:box(Vector3.new(0.6, 0.2, 0.6), CFrame.new(position), Enum.Material.Neon, color, {
		collide = false,
		query = false,
		shadow = false,
		name = "LightFixture",
		parent = self.lights,
	})
	local light: any
	if kind == "Spot" then
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 100
		light = spot
	else
		light = Instance.new("PointLight")
	end
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = true
	light.Parent = holder
	return holder
end

-- Text painted on a part face.
function MapKit.sign(
	_self: Builder,
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	textColor: Color3,
	opts: { font: Enum.Font?, bg: Color3?, size: number? }?
)
	local o = (opts or {}) :: { font: Enum.Font?, bg: Color3?, size: number? }
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if o.bg then 0 else 1
	label.BackgroundColor3 = o.bg or Color3.new(0, 0, 0)
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.Font = o.font or Enum.Font.GothamBlack
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
	return gui
end

-- A named marker the game reads at runtime (spawns, dummies, camera).
function MapKit.marker(self: Builder, name: string, cf: CFrame, attributes: { [string]: any }?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(2, 1, 2)
	part.CFrame = cf
	local attrs: { [string]: any } = attributes or {}
	for k, v in attrs do
		part:SetAttribute(k, v)
	end
	part.Parent = self.markers
	return part
end

function MapKit.spawn(self: Builder, team: string, position: Vector3, lookAt: Vector3)
	local flat = Vector3.new(lookAt.X, position.Y, lookAt.Z)
	return self:marker("Spawn", CFrame.lookAt(position, flat), { Team = team })
end

---------------------------------------------------------------------------------------
-- Symmetry. Arenas are point-symmetric around the origin (rotated 180° about Y), so Red
-- (-X) and Blue (+X) get exactly the same layout. Build one half with `side` = 1 and
-- call it again with `side` = -1:
--
--   MapKit.both(function(s) b:box(size, MapKit.cf(s, -30, 2, 10, 90), ...) end)

function MapKit.both(fn: (side: number) -> ())
	fn(1)
	fn(-1)
end

-- Point in half `side` (side -1 mirrors x and z).
function MapKit.p(side: number, x: number, y: number, z: number): Vector3
	return Vector3.new(x * side, y, z * side)
end

-- CFrame in half `side`, yawed `yawDeg` degrees (turned 180° extra in the mirrored half).
function MapKit.cf(side: number, x: number, y: number, z: number, yawDeg: number?): CFrame
	local yaw = math.rad(yawDeg or 0) + (if side < 0 then math.pi else 0)
	return CFrame.new(x * side, y, z * side) * CFrame.Angles(0, yaw, 0)
end

-- Unit horizontal direction in half `side`.
function MapKit.dir(side: number, x: number, z: number): Vector3
	return Vector3.new(x * side, 0, z * side).Unit
end

---------------------------------------------------------------------------------------
-- Props

function MapKit.crate(self: Builder, cf: CFrame, size: number?, color: Color3?)
	local s = size or 4
	local c = color or Color3.fromRGB(150, 108, 64)
	local body =
		self:box(Vector3.new(s, s, s), cf, Enum.Material.WoodPlanks, c, { name = "Crate", parent = self.props })
	local trim = c:Lerp(Color3.new(0, 0, 0), 0.35)
	for _, dy in { -s / 2 + 0.2, s / 2 - 0.2 } do
		self:box(
			Vector3.new(s + 0.1, 0.35, s + 0.1),
			cf * CFrame.new(0, dy, 0),
			Enum.Material.Wood,
			trim,
			{ name = "CrateTrim", parent = self.props, collide = false }
		)
	end
	return body
end

function MapKit.barrel(self: Builder, position: Vector3, color: Color3?)
	local c = color or Color3.fromRGB(46, 120, 160)
	local body = self:cylinder(
		3.4,
		2.4,
		CFrame.new(position + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Metal,
		c,
		{ name = "Barrel", parent = self.props }
	)
	for _, dy in { 0.5, 2.9 } do
		self:cylinder(
			0.2,
			2.5,
			CFrame.new(position + Vector3.new(0, dy, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.Material.Metal,
			c:Lerp(Color3.new(0, 0, 0), 0.3),
			{ parent = self.props, collide = false }
		)
	end
	return body
end

-- Shipping container (8 x 8.5 x 20 studs by default) with ribbed sides. `open` cuts the
-- doors off one end so players can walk through it.
function MapKit.container(
	self: Builder,
	cf: CFrame,
	color: Color3,
	opts: { length: number?, open: boolean?, label: string? }?
)
	local o = (opts or {}) :: { length: number?, open: boolean?, label: string? }
	local length = o.length or 20
	local w, h = 8, 8.5
	local mat = Enum.Material.CorrodedMetal
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.25)
	-- Walls (hollow so it can be walked through when open)
	self:box(Vector3.new(w, 0.5, length), cf * CFrame.new(0, -h / 2 + 0.25, 0), mat, dark, { name = "ContainerFloor" })
	self:box(Vector3.new(w, 0.5, length), cf * CFrame.new(0, h / 2 - 0.25, 0), mat, color, { name = "ContainerRoof" })
	for _, side in { -1, 1 } do
		local wall = self:box(
			Vector3.new(0.5, h, length),
			cf * CFrame.new(side * (w / 2 - 0.25), 0, 0),
			mat,
			color,
			{ name = "ContainerWall" }
		)
		local ribs = math.floor(length / 1.6)
		for i = 1, ribs - 1 do
			local z = -length / 2 + i * (length / ribs)
			self:box(
				Vector3.new(0.25, h - 0.8, 0.5),
				cf * CFrame.new(side * (w / 2 + 0.1), 0, z),
				mat,
				dark,
				{ collide = false, query = false, parent = self.props, name = "Rib" }
			)
		end
		if o.label and side == 1 then
			self:sign(
				wall,
				Enum.NormalId.Right,
				o.label,
				Color3.fromRGB(245, 240, 230),
				{ font = Enum.Font.GothamBlack }
			)
		end
	end
	-- Back end closed
	self:box(Vector3.new(w, h, 0.5), cf * CFrame.new(0, 0, length / 2 - 0.25), mat, dark, { name = "ContainerEnd" })
	if not o.open then
		self:box(
			Vector3.new(w, h, 0.5),
			cf * CFrame.new(0, 0, -length / 2 + 0.25),
			mat,
			dark,
			{ name = "ContainerDoors" }
		)
		self:box(
			Vector3.new(0.3, h - 1, 0.6),
			cf * CFrame.new(0, 0, -length / 2 - 0.1),
			mat,
			color,
			{ collide = false, query = false, parent = self.props }
		)
	end
end

function MapKit.pallet(self: Builder, cf: CFrame)
	local wood = Color3.fromRGB(176, 140, 92)
	for i = -1, 1 do
		self:box(
			Vector3.new(4, 0.25, 0.8),
			cf * CFrame.new(0, 0.55, i * 1.6),
			Enum.Material.WoodPlanks,
			wood,
			{ parent = self.props, name = "Pallet" }
		)
		self:box(
			Vector3.new(0.6, 0.45, 4),
			cf * CFrame.new(i * 1.7, 0.2, 0),
			Enum.Material.Wood,
			wood:Lerp(Color3.new(0, 0, 0), 0.2),
			{ parent = self.props, name = "Pallet" }
		)
	end
end

-- Wall along X or Z from a to b (floor level) with openings at the given distances
-- along the wall: { {at=, width=, height=, bottom=} } (bottom > 0 makes a window).
function MapKit.wall(
	self: Builder,
	a: Vector3,
	b: Vector3,
	height: number,
	thickness: number,
	material: Enum.Material,
	color: Color3,
	openings: { { at: number, width: number, height: number, bottom: number? } }?
)
	local dir = (b - a)
	local length = dir.Magnitude
	local unit = dir.Unit
	local right = unit:Cross(Vector3.yAxis)
	local function segment(from: number, to: number, y0: number, y1: number)
		if to - from < 0.05 or y1 - y0 < 0.05 then
			return
		end
		local center = a + unit * ((from + to) / 2) + Vector3.new(0, (y0 + y1) / 2, 0)
		local cf = CFrame.fromMatrix(center, right, Vector3.yAxis, -unit)
		self:box(Vector3.new(thickness, y1 - y0, to - from), cf, material, color, { name = "Wall" })
	end
	local list: { { at: number, width: number, height: number, bottom: number? } } = table.clone(openings or {})
	table.sort(list, function(x, y)
		return x.at < y.at
	end)
	local cursor = 0
	for _, opening in list do
		local left = opening.at - opening.width / 2
		local rightEdge = opening.at + opening.width / 2
		segment(cursor, left, 0, height)
		segment(left, rightEdge, 0, opening.bottom or 0)
		segment(left, rightEdge, opening.height, height)
		cursor = rightEdge
	end
	segment(cursor, length, 0, height)
end

-- Bounding wall of invisible barriers around a rectangle, from floorY to topY.
function MapKit.bounds(self: Builder, minXZ: Vector2, maxXZ: Vector2, floorY: number, topY: number)
	local t = 2
	self:barrier(Vector3.new(minXZ.X - t, floorY, minXZ.Y - t), Vector3.new(maxXZ.X + t, topY, minXZ.Y))
	self:barrier(Vector3.new(minXZ.X - t, floorY, maxXZ.Y), Vector3.new(maxXZ.X + t, topY, maxXZ.Y + t))
	self:barrier(Vector3.new(minXZ.X - t, floorY, minXZ.Y), Vector3.new(minXZ.X, topY, maxXZ.Y))
	self:barrier(Vector3.new(maxXZ.X, floorY, minXZ.Y), Vector3.new(maxXZ.X + t, topY, maxXZ.Y))
	-- Lid so nobody can stand on top of the barriers
	self:barrier(Vector3.new(minXZ.X - t, topY, minXZ.Y - t), Vector3.new(maxXZ.X + t, topY + 1, maxXZ.Y + t))
end

return MapKit
