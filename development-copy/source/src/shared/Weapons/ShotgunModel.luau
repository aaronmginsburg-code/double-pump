--!strict
-- Builds a pump shotgun model and drives its bones.
--
-- Normally this clones the imported Blender asset from
--   ReplicatedStorage.Assets.Weapons.PumpShotgun_FP   (first-person viewmodel)
--   ReplicatedStorage.Assets.Weapons.PumpShotgun_TP   (third-person world model)
-- (see docs/ASSET_PIPELINE.md for importing it in Studio). Until those exist, it builds a
-- clearly-labelled stand-in from parts with the same bone layout, prints a warning once,
-- and sets the model's "StandIn" attribute, so the game is testable before import.
--
-- Animation data (ShotgunAnimData) gives each bone a model-space delta D. For a bone b
-- with rest pose R_b (model space) the animated world pose is  Root * D_b * R_b.
-- With imported Bones we convert that to Bone.Transform; with the stand-in we place parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotgunRig = require(script.Parent.ShotgunRig)

local ShotgunModel = {}
ShotgunModel.__index = ShotgunModel

export type Kind = "FirstPerson" | "ThirdPerson"

export type Skin = {
	metal: Color3,
	wood: Color3,
	accent: Color3?,
	material: Enum.Material?,
	tint: Color3?, -- multiplies the imported textures
}

type BoneEntry = {
	bone: Bone,
	parentBone: Bone?, -- nil when the parent is the mesh part
	parentPart: BasePart?,
	rest: CFrame, -- model-space rest pose (relative to the root)
	animated: boolean,
}

type PartEntry = { part: BasePart, bone: string, rest: CFrame }

export type ShotgunModel = typeof(setmetatable(
	{} :: {
		kind: Kind,
		model: Model,
		standIn: boolean,
		root: CFrame,
		deltas: { [string]: CFrame },
		-- imported asset
		bones: { [Bone]: BoneEntry },
		boneOrder: { Bone },
		rootToPivot: CFrame,
		-- stand-in
		parts: { PartEntry },
		shells: { [string]: { BasePart } },
		baseColors: { [BasePart]: Color3 },
	},
	ShotgunModel
))

local TEMPLATE_NAMES = { FirstPerson = "PumpShotgun_FP", ThirdPerson = "PumpShotgun_TP" }
local warned = false

local function findTemplate(kind: Kind): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weapons = assets and assets:FindFirstChild("Weapons")
	local template = weapons and weapons:FindFirstChild(TEMPLATE_NAMES[kind])
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

function ShotgunModel.isImported(kind: Kind): boolean
	return findTemplate(kind) ~= nil
end

local function prepPart(part: BasePart, kind: Kind)
	part.Anchored = kind == "FirstPerson"
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = kind == "ThirdPerson"
end

---------------------------------------------------------------------------------------
-- Stand-in geometry (only used until the Blender asset is imported)

local DEFAULT_SKIN: Skin = {
	metal = Color3.fromRGB(40, 44, 54),
	wood = Color3.fromRGB(150, 88, 48),
	accent = Color3.fromRGB(24, 26, 30),
}

local function standInPart(
	model: Model,
	name: string,
	shape: "Block" | "Cylinder",
	size: Vector3,
	cf: CFrame,
	colorKey: "metal" | "wood" | "accent" | "brass" | "red",
	bone: string,
	parts: { PartEntry }
)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = if shape == "Cylinder" then Enum.PartType.Cylinder else Enum.PartType.Block
	part.Size = size
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = if colorKey == "wood" then Enum.Material.Wood else Enum.Material.Metal
	part:SetAttribute("ColorKey", colorKey)
	part.Color = if colorKey == "brass"
		then Color3.fromRGB(196, 160, 70)
		elseif colorKey == "red" then Color3.fromRGB(170, 30, 30)
		else (DEFAULT_SKIN :: any)[colorKey]
	part.CFrame = cf
	part:SetAttribute("Bone", bone)
	part:SetAttribute("Rest", cf)
	part.Parent = model
	table.insert(parts, { part = part :: BasePart, bone = bone, rest = cf })
	return part
end

-- Cylinders in Roblox run along X; this turns them to run along Z (the bore).
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)

local function buildStandIn(kind: Kind): (Model, { PartEntry }, { [string]: { BasePart } })
	local model = Instance.new("Model")
	model.Name = TEMPLATE_NAMES[kind] .. "_StandIn"
	model:SetAttribute("StandIn", true)
	local parts: { PartEntry } = {}
	local B = ShotgunRig.Bones
	local boreY = B.Muzzle.Y
	local tubeY = B.ShellLive.Y

	local function p(...)
		return standInPart(model, ...)
	end
	-- Receiver and action
	p("Receiver", "Block", Vector3.new(0.18, 0.27, 0.86), CFrame.new(0, -0.02, -0.13), "metal", "Weapon", parts)
	p("SightRib", "Block", Vector3.new(0.05, 0.03, 0.86), CFrame.new(0, 0.13, -0.13), "accent", "Weapon", parts)
	p(
		"Barrel",
		"Cylinder",
		Vector3.new(1.62, 0.11, 0.11),
		CFrame.new(0, boreY, -1.36) * ALONG_Z,
		"metal",
		"Weapon",
		parts
	)
	p(
		"Muzzle",
		"Cylinder",
		Vector3.new(0.06, 0.125, 0.125),
		CFrame.new(0, boreY, -2.14) * ALONG_Z,
		"accent",
		"Weapon",
		parts
	)
	p(
		"FrontSight",
		"Block",
		Vector3.new(0.04, 0.05, 0.05),
		CFrame.new(0, boreY + 0.075, -2.08),
		"accent",
		"Weapon",
		parts
	)
	p(
		"MagTube",
		"Cylinder",
		Vector3.new(1.3, 0.095, 0.095),
		CFrame.new(0, tubeY, -1.2) * ALONG_Z,
		"metal",
		"Weapon",
		parts
	)
	p(
		"MagCap",
		"Cylinder",
		Vector3.new(0.09, 0.11, 0.11),
		CFrame.new(0, tubeY, -1.86) * ALONG_Z,
		"accent",
		"Weapon",
		parts
	)
	p("BarrelBand", "Block", Vector3.new(0.13, 0.2, 0.06), CFrame.new(0, -0.01, -1.72), "accent", "Weapon", parts)
	p("TriggerGuard", "Block", Vector3.new(0.05, 0.12, 0.34), CFrame.new(0, -0.2, 0.08), "accent", "Weapon", parts)
	p("Trigger", "Block", Vector3.new(0.03, 0.09, 0.03), CFrame.new(0, -0.17, 0.1), "metal", "Trigger", parts)
	-- Stock: comb, wrist and butt
	p(
		"StockWrist",
		"Block",
		Vector3.new(0.15, 0.22, 0.42),
		CFrame.new(0, -0.08, 0.5) * CFrame.Angles(math.rad(-10), 0, 0),
		"wood",
		"Weapon",
		parts
	)
	p(
		"Stock",
		"Block",
		Vector3.new(0.15, 0.36, 0.78),
		CFrame.new(0, -0.14, 1.06) * CFrame.Angles(math.rad(-7), 0, 0),
		"wood",
		"Weapon",
		parts
	)
	p(
		"ButtPad",
		"Block",
		Vector3.new(0.16, 0.42, 0.07),
		CFrame.new(0, -0.18, 1.48) * CFrame.Angles(math.rad(-7), 0, 0),
		"accent",
		"Weapon",
		parts
	)
	-- Pump (forend) with grooves
	p("Pump", "Block", Vector3.new(0.2, 0.17, 0.56), CFrame.new(0, tubeY - 0.02, -1.13), "wood", "Pump", parts)
	for i = -2, 2 do
		p(
			"PumpGroove",
			"Block",
			Vector3.new(0.205, 0.02, 0.03),
			CFrame.new(0, tubeY - 0.03, -1.13 + i * 0.09),
			"accent",
			"Pump",
			parts
		)
	end
	p("ActionBar", "Block", Vector3.new(0.02, 0.03, 0.62), CFrame.new(0.08, tubeY + 0.02, -0.8), "metal", "Pump", parts)
	p("Bolt", "Block", Vector3.new(0.06, 0.07, 0.16), CFrame.new(0.06, B.Bolt.Y, B.Bolt.Z), "metal", "Bolt", parts)
	-- Shells for the eject/reload beats (hidden at rest)
	local spent = p(
		"ShellSpent",
		"Cylinder",
		Vector3.new(0.25, 0.08, 0.08),
		CFrame.new(B.ShellSpent) * ALONG_Z,
		"red",
		"ShellSpent",
		parts
	)
	local live = p(
		"ShellLive",
		"Cylinder",
		Vector3.new(0.25, 0.08, 0.08),
		CFrame.new(B.ShellLive) * ALONG_Z,
		"red",
		"ShellLive",
		parts
	)
	spent.Transparency = 1
	live.Transparency = 1

	for _, entry in parts do
		prepPart(entry.part, kind)
	end
	model.PrimaryPart = parts[1].part
	return model, parts, { Spent = { spent }, Live = { live } }
end

---------------------------------------------------------------------------------------
-- Imported asset

local function partWorld(entry: BoneEntry, worlds: { [Bone]: CFrame }): CFrame
	if entry.parentBone then
		return worlds[entry.parentBone]
	end
	return (entry.parentPart :: BasePart).CFrame
end

local function setupImported(self: any, template: Model, clone: boolean)
	local model = if clone then template:Clone() else template
	self.model = model
	if clone then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				prepPart(d, self.kind)
				-- The prepared exports separate the original geometry into palette regions.
				-- FBX custom properties are not guaranteed to survive Studio import.
				local key = d.Name:match("^[FT]P_Region_(%a+)$")
				if key == "metal" or key == "wood" or key == "accent" then
					d:SetAttribute("ColorKey", key)
					d.Material = if key == "wood" then Enum.Material.Wood else Enum.Material.Metal
				end
			elseif d:IsA("Bone") then
				d.Transform = CFrame.identity
			end
		end
	end
	-- Shell meshes (FP_Shell_Live / FP_Shell_Spent) start hidden
	self.shells = { Spent = {}, Live = {} }
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name:find("Shell_Spent") then
				table.insert(self.shells.Spent, d)
				d.Transparency = 1
			elseif d.Name:find("Shell_Live") then
				table.insert(self.shells.Live, d)
				d.Transparency = 1
			end
		end
	end

	-- A multi-mesh FBX can import with a separate copy of the rig below each mesh.
	-- Index by instance so every copy receives the same model-space animation delta.
	local allBones: { Bone } = {}
	local rootBone: Bone? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") then
			table.insert(allBones, d)
			if d.Name == "ViewmodelRoot" and not rootBone then
				rootBone = d
			end
		end
	end
	local worlds: { [Bone]: CFrame } = {}
	local order: { Bone } = {}
	local function visit(bone: Bone)
		local parent = bone.Parent
		local parentWorld = if parent and parent:IsA("Bone")
			then worlds[parent]
			elseif parent and parent:IsA("BasePart") then parent.CFrame
			else CFrame.identity
		worlds[bone] = parentWorld * bone.CFrame
		table.insert(order, bone)
		for _, child in bone:GetChildren() do
			if child:IsA("Bone") then
				visit(child)
			end
		end
	end
	for _, bone in allBones do
		local parent = bone.Parent
		if not parent or not parent:IsA("Bone") then
			visit(bone)
		end
	end
	local rootOffset = model:GetAttribute("AnimationRootOffset") or CFrame.identity
	local rootWorld = if rootBone then worlds[rootBone] * rootOffset else model:GetPivot()
	self.rootToPivot = rootWorld:ToObjectSpace(model:GetPivot())
	self.bones = {}
	for _, bone in allBones do
		local parent = bone.Parent
		self.bones[bone] = {
			bone = bone,
			parentBone = if parent and parent:IsA("Bone") then parent else nil,
			parentPart = if parent and parent:IsA("BasePart") then parent else nil,
			rest = rootWorld:ToObjectSpace(worlds[bone] or rootWorld),
			animated = table.find(ShotgunRig.Animated, bone.Name) ~= nil,
		}
	end
	self.boneOrder = order
	if not rootBone then
		warn(
			"[Double Pump] Imported shotgun has no ViewmodelRoot bone; animations disabled. See docs/ASSET_PIPELINE.md"
		)
	end
end

---------------------------------------------------------------------------------------

function ShotgunModel.new(kind: Kind): ShotgunModel
	local self = setmetatable({
		kind = kind,
		standIn = false,
		root = CFrame.identity,
		deltas = {},
		bones = {},
		boneOrder = {},
		rootToPivot = CFrame.identity,
		parts = {},
		shells = { Spent = {}, Live = {} },
		baseColors = {},
	}, ShotgunModel) :: any

	local template = findTemplate(kind)
	if template then
		setupImported(self, template, true)
	else
		self.standIn = true
		local model, parts, shells = buildStandIn(kind)
		self.model = model
		self.parts = parts
		self.shells = shells
		self.rootToPivot = model:GetPivot()
		if not warned then
			warned = true
			warn(
				"[Double Pump] Shotgun asset not found in ReplicatedStorage.Assets.Weapons; using the parts stand-in."
					.. " Import the Blender model as described in docs/ASSET_PIPELINE.md."
			)
		end
	end
	self.model:SetAttribute("ShotgunKind", kind)
	return self
end

-- Wraps a third-person gun that already exists (the server-made "WorldShotgun" on a
-- character) so each client can animate its pump locally.
function ShotgunModel.wrap(model: Model): ShotgunModel
	local self = setmetatable({
		kind = "ThirdPerson",
		standIn = model:GetAttribute("StandIn") == true,
		root = CFrame.identity,
		deltas = {},
		bones = {},
		boneOrder = {},
		rootToPivot = CFrame.identity,
		parts = {},
		shells = { Spent = {}, Live = {} },
		baseColors = {},
	}, ShotgunModel) :: any
	if self.standIn then
		self.model = model
		local receiver = model:FindFirstChild("Receiver")
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Bone") then
				local entry =
					{ part = d, bone = d:GetAttribute("Bone"), rest = d:GetAttribute("Rest") or CFrame.identity }
				if d == receiver then
					table.insert(self.parts, 1, entry)
				else
					table.insert(self.parts, entry)
				end
			end
		end
	else
		-- Bone rest poses are measured from the current pose, so wrap before animating
		setupImported(self, model, false)
	end
	self:syncRoot()
	return self
end

-- Moves the whole gun so its ViewmodelRoot sits at `root` (world space).
function ShotgunModel.setRoot(self: ShotgunModel, root: CFrame)
	self.root = root
	if self.standIn then
		self:_placeStandIn()
	else
		self.model:PivotTo(root * self.rootToPivot)
		self:_applyBones()
	end
end

-- deltas: bone name -> model-space delta (from AnimPlayer). Missing bones = rest.
function ShotgunModel.setPose(self: ShotgunModel, deltas: { [string]: CFrame })
	self.deltas = deltas
	if self.kind == "ThirdPerson" then
		self:syncRoot()
	end
	if self.standIn then
		self:_placeStandIn()
	else
		self:_applyBones()
	end
end

function ShotgunModel._placeStandIn(self: ShotgunModel)
	local root, deltas = self.root, self.deltas
	if self.kind == "FirstPerson" then
		local cframes, partsList = {}, {}
		for i, entry in self.parts do
			partsList[i] = entry.part
			local d = deltas[entry.bone]
			cframes[i] = if d then root * d * entry.rest else root * entry.rest
		end
		workspace:BulkMoveTo(partsList, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	else
		-- Third person parts are welded to the receiver; only moving parts are re-posed
		local rootRest = self.parts[1].rest
		for i, entry in self.parts do
			if i > 1 and entry.bone ~= "Weapon" then
				local weld = entry.part:FindFirstChild("StandInWeld") :: Weld?
				if weld then
					local d = deltas[entry.bone] or CFrame.identity
					weld.C0 = rootRest:Inverse() * d * entry.rest
				end
			end
		end
	end
end

function ShotgunModel._applyBones(self: ShotgunModel)
	local root, deltas = self.root, self.deltas
	local worlds: { [Bone]: CFrame } = {}
	for _, indexedBone in self.boneOrder do
		local entry = self.bones[indexedBone]
		local bone = entry.bone
		local parentWorld = partWorld(entry, worlds)
		local d = if entry.animated then deltas[bone.Name] else nil
		if d then
			local desired = root * d * entry.rest
			bone.Transform = (parentWorld * bone.CFrame):ToObjectSpace(desired)
			worlds[bone] = desired
		else
			if entry.animated then
				bone.Transform = CFrame.identity
			end
			worlds[bone] = parentWorld * bone.CFrame * bone.Transform
		end
	end
end

-- Third person: the gun is moved by physics (welded to a character), so read the root
-- back from the parts.
function ShotgunModel.syncRoot(self: ShotgunModel)
	if self.standIn then
		local first = self.parts[1]
		self.root = first.part.CFrame * first.rest:Inverse()
	else
		self.root = self.model:GetPivot() * self.rootToPivot:Inverse()
	end
end

-- World CFrame of a bone or reference point (Muzzle, ShellEject, Grip, SupportHand...).
function ShotgunModel.point(self: ShotgunModel, name: string): CFrame
	local rest = ShotgunRig.Bones[name] or Vector3.zero
	local carrier = ShotgunRig.Carrier[name] or "Weapon"
	local d = self.deltas[carrier] or CFrame.identity
	return self.root * d * CFrame.new(rest)
end

function ShotgunModel.setShellVisible(self: ShotgunModel, which: "Spent" | "Live", visible: boolean)
	local list: { BasePart } = self.shells[which] or {}
	for _, part in list do
		part.Transparency = if visible then 0 else 1
	end
end

function ShotgunModel.setVisible(self: ShotgunModel, visible: boolean)
	for _, d in self.model:GetDescendants() do
		if d:IsA("BasePart") then
			local isShell = table.find(self.shells.Spent, d) or table.find(self.shells.Live, d)
			if not isShell then
				d.LocalTransparencyModifier = if visible then 0 else 1
			end
		end
	end
end

function ShotgunModel.applySkin(self: ShotgunModel, skin: Skin?)
	local s = skin or DEFAULT_SKIN
	for _, d in self.model:GetDescendants() do
		if d:IsA("SurfaceAppearance") then
			local parent = d.Parent
			local key = if parent and parent:IsA("BasePart") then parent:GetAttribute("ColorKey") else nil
			local color = if key == "metal"
				then s.metal
				elseif key == "wood" then s.wood
				elseif key == "accent" then s.accent or DEFAULT_SKIN.accent :: Color3
				else Color3.new(1, 1, 1)
			local tint = s.tint or Color3.new(1, 1, 1)
			local surface = d :: any
			surface.Color = Color3.new(color.R * tint.R, color.G * tint.G, color.B * tint.B)
		elseif d:IsA("BasePart") and d:GetAttribute("ColorKey") then
			local key = d:GetAttribute("ColorKey")
			if key == "metal" then
				d.Color = s.metal
				d.Material = s.material or Enum.Material.Metal
			elseif key == "wood" then
				d.Color = s.wood
			elseif key == "accent" then
				d.Color = s.accent or DEFAULT_SKIN.accent :: Color3
			end
		end
	end
end

function ShotgunModel.destroy(self: ShotgunModel)
	self.model:Destroy()
end

-- Third person: weld every part to one root part so the gun can be mounted on a body.
-- Returns the root part (the Weapon bone's carrier).
function ShotgunModel.weldForThirdPerson(self: ShotgunModel): BasePart
	local rootPart: BasePart
	if self.standIn then
		rootPart = self.parts[1].part
		local rootRest = self.parts[1].rest
		for i, entry in self.parts do
			entry.part.Anchored = false
			if i > 1 then
				local weld = Instance.new("Weld")
				weld.Name = "StandInWeld"
				weld.Part0 = rootPart
				weld.Part1 = entry.part
				weld.C0 = rootRest:Inverse() * entry.rest
				weld.Parent = entry.part
			end
		end
	else
		local primary = self.model.PrimaryPart or self.model:FindFirstChildWhichIsA("BasePart", true)
		assert(primary, "Imported shotgun has no parts")
		rootPart = primary
		for _, d in self.model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				if d ~= rootPart then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = rootPart
					weld.Part1 = d
					weld.Parent = d
				end
			end
		end
	end
	self.model.PrimaryPart = rootPart
	return rootPart
end

ShotgunModel.DefaultSkin = DEFAULT_SKIN

return ShotgunModel
