--!strict
-- Training dummies in the practice range: R15-proportioned targets with real hit zones
-- (Head, UpperTorso, arms, legs) that take damage through the normal combat pipeline,
-- some standing still, some strafing or jumping. They respawn shortly after being
-- eliminated. Dummies never shoot back.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Combatants = require(Shared.Combatants)
local GameConfig = require(Shared.Config.GameConfig)
local MapService = require(script.Parent.MapService)

local PracticeService = {}

type Dummy = {
	model: Model,
	marker: BasePart,
	kind: string,
	width: number,
	phase: number,
	base: CFrame,
}

local dummies: { Dummy } = {}
local folder: Folder

-- name, size, offset from the root (root centre is 3 studs above the floor)
local BODY: { { any } } = {
	{ "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.75, 0) },
	{ "UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 0.4, 0) },
	{ "LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, -0.6, 0) },
	{ "LeftUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 0.6, 0) },
	{ "LeftLowerArm", Vector3.new(1, 1.1, 1), Vector3.new(-1.5, -0.55, 0) },
	{ "LeftHand", Vector3.new(1, 0.3, 1), Vector3.new(-1.5, -1.25, 0) },
	{ "RightUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, 0.6, 0) },
	{ "RightLowerArm", Vector3.new(1, 1.1, 1), Vector3.new(1.5, -0.55, 0) },
	{ "RightHand", Vector3.new(1, 0.3, 1), Vector3.new(1.5, -1.25, 0) },
	{ "LeftUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(-0.5, -1.4, 0) },
	{ "LeftLowerLeg", Vector3.new(1, 1.2, 1), Vector3.new(-0.5, -2.4, 0) },
	{ "LeftFoot", Vector3.new(1, 0.3, 1), Vector3.new(-0.5, -2.85, 0) },
	{ "RightUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(0.5, -1.4, 0) },
	{ "RightLowerLeg", Vector3.new(1, 1.2, 1), Vector3.new(0.5, -2.4, 0) },
	{ "RightFoot", Vector3.new(1, 0.3, 1), Vector3.new(0.5, -2.85, 0) },
}

local SKIN = Color3.fromRGB(235, 140, 40)
local DARK = Color3.fromRGB(45, 48, 56)

local function buildDummy(at: CFrame, drill: boolean): Model
	local model = Instance.new("Model")
	model.Name = if drill then "Drill Bot" else "Training Bot"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CFrame = at * CFrame.new(0, 3, 0)
	root.Parent = model
	model.PrimaryPart = root
	for _, spec in BODY do
		local name, size, offset = spec[1], spec[2], spec[3]
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Anchored = true
		part.CanCollide = true
		part.CFrame = root.CFrame * CFrame.new(offset)
		part.Material = if name == "Head" or name:find("Torso")
			then Enum.Material.SmoothPlastic
			else Enum.Material.Metal
		part.Color = if name == "Head" or name:find("Torso") then SKIN else DARK
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		if name == "UpperTorso" then
			-- Target rings on the chest
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.PixelsPerStud = 60
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.Parent = part
			for i, scale in { 0.9, 0.6, 0.3 } do
				local ring = Instance.new("Frame")
				ring.AnchorPoint = Vector2.new(0.5, 0.5)
				ring.Position = UDim2.fromScale(0.5, 0.5)
				ring.Size = UDim2.fromScale(scale * 0.8, scale)
				ring.BackgroundColor3 = if i % 2 == 1 then Color3.new(1, 1, 1) else Color3.fromRGB(220, 40, 40)
				ring.Parent = gui
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(1, 0)
				corner.Parent = ring
			end
		elseif name == "Head" then
			local visor = Instance.new("Part")
			visor.Name = "Visor"
			visor.Size = Vector3.new(1, 0.3, 0.1)
			visor.Anchored = true
			visor.CanCollide = false
			visor.CanQuery = false
			visor.Material = Enum.Material.Neon
			visor.Color = Color3.fromRGB(80, 220, 255)
			visor.CFrame = part.CFrame * CFrame.new(0, 0.15, -0.62)
			visor.Parent = model
		end
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = GameConfig.Player.MaxHealth
	humanoid.Health = GameConfig.Player.MaxHealth
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	model:SetAttribute("Dummy", true)
	CollectionService:AddTag(model, Combatants.TAG)
	return model
end

local function respawn(dummy: Dummy)
	local old = dummy.model
	local drill = dummy.marker:GetAttribute("Drill") == true
	dummy.model = buildDummy(dummy.base, drill)
	dummy.model.Parent = folder
	if old then
		old:Destroy()
	end
	local humanoid = dummy.model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.Died:Once(function()
		local model = dummy.model
		-- Topple over, then come back
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.CanQuery = false
				p.Transparency = math.max(p.Transparency, 0.5)
			end
		end
		task.delay(GameConfig.Practice.TargetRespawn, function()
			if dummy.model == model then
				respawn(dummy)
			end
		end)
	end)
end

function PracticeService.start()
	folder = Instance.new("Folder")
	folder.Name = "Dummies"
	folder.Parent = workspace
	for _, marker in MapService.rangeDummyMarkers() do
		local dummy: Dummy = {
			model = nil :: any,
			marker = marker,
			kind = (marker:GetAttribute("Kind") :: string?) or "Static",
			width = (marker:GetAttribute("Width") :: number?) or 12,
			phase = math.random() * math.pi * 2,
			base = marker.CFrame,
		}
		respawn(dummy)
		table.insert(dummies, dummy)
	end

	-- Moving targets (server-side, anchored, replicated at network rate)
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		for _, dummy in dummies do
			if dummy.kind == "Static" or not dummy.model or dummy.model:GetAttribute("Dead") then
				continue
			end
			local offset = CFrame.identity
			if dummy.kind == "Strafe" then
				local speed = GameConfig.Practice.MovingTargetSpeed
				local period = dummy.width * 2 / speed
				-- Triangle wave: constant speed with sharp direction changes, like a strafing player
				local u = ((t + dummy.phase) % period) / period
				local x = (if u < 0.5 then u * 2 else 2 - u * 2) - 0.5
				offset = CFrame.new(x * dummy.width, 0, 0)
			elseif dummy.kind == "Jump" then
				local cycle = (t + dummy.phase) % 1.6
				local h = if cycle < 0.7 then math.sin(cycle / 0.7 * math.pi) * 6 else 0
				offset = CFrame.new(0, h, 0)
			end
			dummy.model:PivotTo(dummy.base * offset * CFrame.new(0, 3, 0))
		end
	end)
end

return PracticeService
