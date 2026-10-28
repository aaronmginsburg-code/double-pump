--!nocheck
-- Synthetic imported meshes test the actual presentation module, not GPU skinning.
local T = require("./runner/T")
local L = require("./runner/Loader")
local R = L.roblox
local CF, V = R.CFrame, R.Vector3
local I = require("./fixtures/ImportedInstance")
local previousInstance = L.Instance
L.Instance = I
local expect, it = T.expect, T.it
local previousStorage = L.services.ReplicatedStorage
L.reset()
local storage = I.new("Folder")
local assets = I.new("Folder")
assets.Name, assets.Parent = "Assets", storage
local weapons = I.new("Folder")
weapons.Name, weapons.Parent = "Weapons", assets
L.services.ReplicatedStorage = storage
local rig = L.require(L.Shared.Weapons.ShotgunRig)
local cosmetics = L.require(L.Shared.Progression.Cosmetics)
local function template(name)
	local model = I.new("Model")
	model.Name, model.Parent = name, weapons
	for index, key in { "metal", "wood", "accent" } do
		local mesh = I.new("MeshPart")
		mesh.Name = (if name == "PumpShotgun_FP" then "FP" else "TP") .. "_Region_" .. key
		mesh.CFrame = CF.new(index * 0.02, 0, 0)
		mesh.Parent = model
		if index == 1 then
			model.PrimaryPart = mesh
		end
		local appearance = I.new("SurfaceAppearance")
		appearance.Parent = mesh
		local root = I.new("Bone")
		root.Name, root.Parent = "ViewmodelRoot", mesh
		-- Root reference is identical across mesh rig copies, despite mesh pivots.
		local boneAxis = CF.Angles(math.pi / 2, 0, 0)
		root.CFrame = mesh.CFrame:Inverse() * boneAxis
		model:SetAttribute("AnimationRootOffset", boneAxis:Inverse())
		local weapon = I.new("Bone")
		weapon.Name, weapon.Parent = "Weapon", root
		weapon.CFrame = boneAxis:Inverse() * CF.new(rig.Bones.Weapon)
		local pump = I.new("Bone")
		pump.Name, pump.Parent = "Pump", weapon
		pump.CFrame = CF.new(rig.Bones.Pump - rig.Bones.Weapon)
		for boneName, position in rig.Bones do
			if boneName ~= "ViewmodelRoot" and boneName ~= "Weapon" and boneName ~= "Pump" then
				local bone = I.new("Bone")
				local parent = if boneName == "SupportHand" then pump else weapon
				local parentPosition = if parent == pump then rig.Bones.Pump else rig.Bones.Weapon
				bone.Name, bone.Parent = boneName, parent
				bone.CFrame = CF.new(position - parentPosition)
			end
		end
	end
	return model
end
local fp, tp = template("PumpShotgun_FP"), template("PumpShotgun_TP")
local Model = L.require(L.Shared.Weapons.ShotgunModel)
local AnimPlayer = L.require(L.Shared.Weapons.AnimPlayer)
local Presentation = L.require(L.Shared.Mobile.Presentation)
T.describe("Segmented original shotgun imports", function()
	for _, left in { false, true } do
		for _, clip in
			{ "Idle", "Equip", "Fire", "Pump", "ReloadStart", "ReloadInsert", "ReloadEnd", "SwapIn", "Unequip" }
		do
			it("applies unchanged " .. clip .. " pose, left hand " .. tostring(left), function()
				local gun = Model.new("FirstPerson")
				local anim = AnimPlayer.new("FirstPerson")
				anim:play(clip, { fadeIn = 0, hold = true })
				local pose = anim:update(anim:duration(clip) * 0.4)
				local root = rig.ViewmodelOffset
				if left then
					root = Presentation.reflect(root)
					for name, delta in pose do
						pose[name] = Presentation.reflect(delta)
					end
				end
				gun:setRoot(root)
				gun:setPose(pose)
				local function world(bone)
					local parent = bone.Parent
					local parentWorld = if parent:IsA("Bone") then world(parent) else parent.CFrame
					return parentWorld * bone.CFrame * bone.Transform
				end
				for bone, entry in gun.bones do
					if entry.animated then
						local desired = root * (pose[bone.Name] or CF.identity) * entry.rest
						local a, b = { world(bone):GetComponents() }, { desired:GetComponents() }
						for i = 1, 12 do
							expect(a[i]).toBeNear(b[i], 1e-4)
						end
					end
				end
				gun:destroy()
			end)
		end
	end
	it("animates every repeated bone tree and restores all pump transforms", function()
		local gun = Model.new("FirstPerson")
		gun:setRoot(CF.new(3, 4, 5))
		gun:setPose({ Pump = CF.new(0, 0, 0.24) })
		local count = 0
		for _, bone in gun.model:GetDescendants() do
			if bone:IsA("Bone") and bone.Name == "Pump" then
				count += 1
				expect(bone.Transform.Position.Z).toBeNear(0.24)
			end
		end
		expect(count).toBe(3)
		gun:setPose({})
		for _, bone in gun.model:GetDescendants() do
			if bone:IsA("Bone") then
				expect(bone.Transform.Position.Magnitude).toBeNear(0)
			end
		end
		gun:destroy()
	end)
	it("clones identical visuals with independent Pump A/B poses", function()
		local a, b = Model.new("FirstPerson"), Model.new("FirstPerson")
		a:setPose({ Pump = CF.new(0, 0, 0.2) })
		b:setPose({})
		expect(a.model == b.model).toBeFalsy()
		expect(a.model.FP_Region_wood.ViewmodelRoot.Weapon.Pump.Transform.Position.Z).toBeNear(0.2)
		expect(b.model.FP_Region_wood.ViewmodelRoot.Weapon.Pump.Transform.Position.Z).toBeNear(0)
		expect(fp.FP_Region_wood.ViewmodelRoot.Weapon.Pump.Transform.Position.Magnitude).toBeNear(0)
		a:destroy()
		b:destroy()
	end)
	it("keeps visual meshes out of collisions and shot queries", function()
		local gun = Model.new("FirstPerson")
		for _, part in gun.model:GetDescendants() do
			if part:IsA("BasePart") then
				expect(part.Anchored).toBeTruthy()
				expect(part.CanCollide or part.CanQuery or part.CanTouch).toBeFalsy()
			end
		end
		gun:destroy()
	end)
	it("keeps muzzle and grip references independent of mesh pivot", function()
		local gun = Model.new("FirstPerson")
		local root = CF.new(5, 2, -8) * CF.Angles(0, 0.4, 0)
		gun:setRoot(root)
		for _, name in { "Muzzle", "Grip", "ShellEject", "ShellLoad", "SupportHand" } do
			expect((gun:point(name).Position - (root * CF.new(rig.Bones[name])).Position).Magnitude).toBeNear(0)
		end
		gun:destroy()
	end)
	for _, kind in { "FirstPerson", "ThirdPerson" } do
		for _, skin in cosmetics.Skins do
			it(kind .. " preserves palette " .. skin.id, function()
				local gun = Model.new(kind)
				gun:applySkin(skin)
				for _, part in gun.model:GetChildren() do
					local key = part:GetAttribute("ColorKey")
					local color = skin[key]
					for _, actual in { part.Color, part.SurfaceAppearance.Color } do
						expect(actual.R).toBeNear(color.R, 1e-5)
						expect(actual.G).toBeNear(color.G, 1e-5)
						expect(actual.B).toBeNear(color.B, 1e-5)
					end
					if key == "metal" then
						expect(part.Material).toBe(skin.material or R.Enum.Material.Metal)
					end
				end
				gun:destroy()
			end)
		end
	end
	it("wraps replicated world meshes without losing duplicate rigs", function()
		local gun = Model.new("ThirdPerson")
		local wrapped = Model.wrap(gun.model)
		wrapped:setPose({ Pump = CF.new(0, 0, 0.1) })
		local count = 0
		for _, bone in gun.model:GetDescendants() do
			if bone:IsA("Bone") and bone.Name == "Pump" then
				count += 1
				expect(bone.Transform.Position.Z).toBeNear(0.1)
			end
		end
		expect(count).toBe(3)
		gun:destroy()
	end)
	it("retains the original parts fallback when templates are absent", function()
		fp.Parent, tp.Parent = nil, nil
		local gun = Model.new("FirstPerson")
		expect(gun.standIn).toBeTruthy()
		expect(gun.model:GetAttribute("StandIn")).toBeTruthy()
		gun:destroy()
		fp.Parent, tp.Parent = weapons, weapons
	end)
end)
storage:Destroy()
L.services.ReplicatedStorage = previousStorage
L.Instance = previousInstance
L.reset()
