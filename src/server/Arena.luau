-- Builds the gray-box test room out of plain parts when the server starts.
-- Layout: a 140 x 140 stud floor with walls, a few pieces of cover, and a
-- spawn at each end (north and south). Dummies stand in the middle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Arena = {}

local FLOOR_SIZE = 140
local WALL_HEIGHT = 20
local FLOOR_TOP = 1 -- the floor sits just above a Baseplate so they don't flicker

local function makePart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Cover pieces: { size, position of the bottom-center on the floor }
local COVER = {
	-- Tall pillars to swap around
	{ Vector3.new(6, 12, 6), Vector3.new(-20, 0, 15) },
	{ Vector3.new(6, 12, 6), Vector3.new(20, 0, -15) },
	-- Waist-high walls to peek over
	{ Vector3.new(14, 3.5, 2), Vector3.new(0, 0, 30) },
	{ Vector3.new(14, 3.5, 2), Vector3.new(0, 0, -30) },
	-- Side boxes
	{ Vector3.new(8, 6, 8), Vector3.new(-45, 0, -20) },
	{ Vector3.new(8, 6, 8), Vector3.new(45, 0, 20) },
	-- A long wall with gaps near each spawn
	{ Vector3.new(20, 8, 2), Vector3.new(-25, 0, 45) },
	{ Vector3.new(20, 8, 2), Vector3.new(25, 0, -45) },
}

function Arena.build()
	-- A Baseplate template comes with its own SpawnLocation in the middle,
	-- which would drop players among the dummies. Remove any stray ones.
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = workspace

	local floorColor = Color3.fromRGB(110, 110, 115)
	local wallColor = Color3.fromRGB(80, 80, 88)
	local coverColor = Color3.fromRGB(150, 150, 155)

	makePart(folder, "Floor", Vector3.new(FLOOR_SIZE, 1, FLOOR_SIZE), Vector3.new(0, FLOOR_TOP - 0.5, 0), floorColor)

	-- Four outer walls
	local half = FLOOR_SIZE / 2
	local wallY = FLOOR_TOP + WALL_HEIGHT / 2
	makePart(folder, "Wall", Vector3.new(FLOOR_SIZE, WALL_HEIGHT, 2), Vector3.new(0, wallY, half), wallColor)
	makePart(folder, "Wall", Vector3.new(FLOOR_SIZE, WALL_HEIGHT, 2), Vector3.new(0, wallY, -half), wallColor)
	makePart(folder, "Wall", Vector3.new(2, WALL_HEIGHT, FLOOR_SIZE), Vector3.new(half, wallY, 0), wallColor)
	makePart(folder, "Wall", Vector3.new(2, WALL_HEIGHT, FLOOR_SIZE), Vector3.new(-half, wallY, 0), wallColor)

	for _, cover in COVER do
		local size, base = cover[1], cover[2]
		makePart(folder, "Cover", size, base + Vector3.new(0, FLOOR_TOP + size.Y / 2, 0), coverColor)
	end

	-- One spawn at each end, facing the middle. The ForceField a spawn gives
	-- lasts SpawnProtection seconds; Health.damage ignores players who have one.
	for _, z in { 58, -58 } do
		local spawnPad = Instance.new("SpawnLocation")
		spawnPad.Name = "Spawn"
		spawnPad.Anchored = true
		spawnPad.Size = Vector3.new(8, 1, 8)
		spawnPad.CFrame = CFrame.lookAt(Vector3.new(0, FLOOR_TOP + 0.5, z), Vector3.new(0, FLOOR_TOP + 0.5, 0))
		spawnPad.Duration = Config.Player.SpawnProtection
		spawnPad.Neutral = true
		spawnPad.Color = Color3.fromRGB(90, 140, 200)
		spawnPad.Parent = folder
	end
end

-- Height of the floor surface, for placing dummies
Arena.FLOOR_TOP = FLOOR_TOP

return Arena
