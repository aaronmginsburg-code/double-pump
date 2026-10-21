--!strict
-- Rest positions of the shotgun's bones in model space (studs, muzzle -Z, up +Y, the
-- ViewmodelRoot bone at the origin). Copied from the Blender export's
-- exports/attachments.json; used by the stand-in model and for effect positions.

local ShotgunRig = {}

ShotgunRig.Bones = {
	ViewmodelRoot = Vector3.new(0, 0, 0),
	Weapon = Vector3.new(0, -0.07857, 0.4),
	Pump = Vector3.new(0, -0.0625, -1.12857),
	SupportHand = Vector3.new(0, -0.1625, -1.09286),
	Bolt = Vector3.new(0, 0.04464, -0.13571),
	Trigger = Vector3.new(0, -0.12857, 0.10714),
	ShellCarrier = Vector3.new(0, -0.10893, -0.01429),
	ShellSpent = Vector3.new(0, 0.04286, -0.40357),
	ShellLive = Vector3.new(0, -0.0625, -0.625),
	Grip = Vector3.new(0, -0.07857, 0.4),
	Muzzle = Vector3.new(0, 0.04286, -2.16071),
	ShellEject = Vector3.new(0.08036, 0.03929, -0.14643),
	ShellLoad = Vector3.new(0, -0.13929, -0.14643),
}

-- Which animated bone carries each reference point.
ShotgunRig.Carrier = {
	Grip = "Weapon",
	Muzzle = "Weapon",
	ShellEject = "Weapon",
	ShellLoad = "Weapon",
	SupportHand = "Pump",
	Weapon = "Weapon",
	Pump = "Pump",
	Bolt = "Bolt",
	Trigger = "Trigger",
	ShellCarrier = "ShellCarrier",
	ShellSpent = "ShellSpent",
	ShellLive = "ShellLive",
}

-- Bones the animation data drives, parents first.
ShotgunRig.Animated = { "Weapon", "Pump", "Bolt", "Trigger", "ShellCarrier", "ShellSpent", "ShellLive" }

-- Camera -> gun-root offset from the Blender demo camera (70 deg vertical FOV).
-- attachments.json: viewmodel_demo_camera.viewmodel_offset_cframe
ShotgunRig.ViewmodelOffset = CFrame.new(
	0.8056, -0.48837, -1.07452,
	0.99027, 0.0, -0.13917,
	0.01213, 0.99619, 0.08631,
	0.13864, -0.08716, 0.9865
)

ShotgunRig.Length = 3.7

return ShotgunRig
