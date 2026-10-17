-- Visual-only effects: pellet tracers, impact puffs, floating damage numbers.
-- These only exist on this client and never affect gameplay.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Feel = Config.Feel

local Effects = {}

local folder = Instance.new("Folder")
folder.Name = "LocalEffects"
folder.Parent = workspace
Effects.folder = folder

-- A part that physics and raycasts ignore completely
local function makeEffectPart(size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Parent = folder
	return part
end

local function fadeOut(part: BasePart, duration: number)
	TweenService:Create(part, TweenInfo.new(duration), { Transparency = 1 }):Play()
	Debris:AddItem(part, duration)
end

function Effects.tracer(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local cframe = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	local part = makeEffectPart(Vector3.new(0.05, 0.05, length), cframe, Color3.fromRGB(255, 230, 150))
	part.Transparency = 0.3
	fadeOut(part, Feel.TracerLifetime)
end

-- hitCharacter = true makes a red puff instead of a gray one
function Effects.impact(position: Vector3, hitCharacter: boolean)
	local color = if hitCharacter then Color3.fromRGB(220, 40, 40) else Color3.fromRGB(200, 200, 200)
	local part = makeEffectPart(Vector3.new(0.3, 0.3, 0.3), CFrame.new(position), color)
	part.Shape = Enum.PartType.Ball
	fadeOut(part, Feel.ImpactLifetime)
end

-- A number that pops up at a position and floats away.
-- Yellow for headshots, red for kills, white otherwise.
function Effects.damageNumber(position: Vector3, damage: number, headshot: boolean, killed: boolean)
	-- Billboards need something to sit on, so use an invisible anchor part
	local anchor = makeEffectPart(Vector3.new(0.1, 0.1, 0.1), CFrame.new(position + Vector3.new(0, 1.5, 0)), Color3.new())
	anchor.Transparency = 1

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.AlwaysOnTop = true
	billboard.Adornee = anchor
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = tostring(damage)
	label.TextColor3 = if killed
		then Color3.fromRGB(255, 70, 70)
		elseif headshot then Color3.fromRGB(255, 220, 50)
		else Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard

	-- Small random sideways nudge so several numbers don't stack exactly
	local drift = Vector3.new(math.random(-10, 10) / 10, 2.5, 0)
	local info = TweenInfo.new(Feel.DamageNumberTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { CFrame = anchor.CFrame + drift }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, Feel.DamageNumberTime)
end

return Effects
