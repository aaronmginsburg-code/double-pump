-- The placeholder pump shotgun, built from plain parts. Used twice:
--   - the first-person viewmodel (client, Viewmodel.luau)
--   - the gun other players see in your hands (server, welded to RightHand)

local GunModel = {}

-- Each piece: name, size, offset from the gun's center, color.
-- -Z is forward (toward the muzzle).
GunModel.PIECES = {
	{ "Receiver", Vector3.new(0.26, 0.32, 1.0), CFrame.new(0, 0, 0), Color3.fromRGB(45, 45, 50) },
	{ "Barrel", Vector3.new(0.13, 0.13, 1.7), CFrame.new(0, 0.08, -1.35), Color3.fromRGB(30, 30, 33) },
	{ "Tube", Vector3.new(0.11, 0.11, 1.3), CFrame.new(0, -0.07, -1.15), Color3.fromRGB(35, 35, 38) },
	{ "Pump", Vector3.new(0.22, 0.2, 0.55), CFrame.new(0, -0.08, -1.05), Color3.fromRGB(120, 75, 40) },
	{ "Stock", Vector3.new(0.22, 0.36, 0.9), CFrame.new(0, -0.12, 0.9), Color3.fromRGB(120, 75, 40) },
	{ "Light", Vector3.new(0.08, 0.04, 0.3), CFrame.new(0, 0.18, 0.15), Color3.fromRGB(80, 255, 120) },
}

-- Muzzle tip relative to the gun's center
GunModel.MUZZLE_OFFSET = CFrame.new(0, 0.08, -2.25)

-- Where the gun sits relative to the RightHand when held in third person.
-- With the arm pointing forward, the hand's "down" points forward, so we tip
-- the gun 90 degrees to line it up with the arm, then slide it into the grip.
local GRIP = CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, 0.15, -0.4)

-- A plain part that never collides, blocks shots, or touches anything
function GunModel.makePart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = if name == "Light" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false -- raycasts (shots) pass straight through the gun
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- Builds a gun welded into a character's right hand (call on the server).
function GunModel.attachToHand(character: Model)
	local hand = character:WaitForChild("RightHand", 5) :: BasePart?
	if not hand then
		return
	end
	local model = Instance.new("Model")
	model.Name = "HeldGun"

	local gunCFrame = hand.CFrame * GRIP
	for _, piece in GunModel.PIECES do
		local name, size, offset, color = piece[1], piece[2], piece[3], piece[4]
		local part = GunModel.makePart(name, size, color)
		part.Massless = true -- doesn't weigh the character down
		part.CFrame = gunCFrame * offset
		part.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = part
		weld.Parent = part

		if name == "Barrel" then
			-- Tracers for third-person shots start here
			local muzzle = Instance.new("Attachment")
			muzzle.Name = "Muzzle"
			muzzle.Position = Vector3.new(0, 0, -size.Z / 2)
			muzzle.Parent = part
		end
	end
	model.Parent = character
end

-- World position of a character's held-gun muzzle, if it has one
function GunModel.getHeldMuzzle(character: Model): Vector3?
	local gun = character:FindFirstChild("HeldGun")
	local barrel = gun and gun:FindFirstChild("Barrel")
	local muzzle = barrel and barrel:FindFirstChild("Muzzle")
	return if muzzle and muzzle:IsA("Attachment") then muzzle.WorldPosition else nil
end

return GunModel
