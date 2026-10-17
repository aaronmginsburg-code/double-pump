-- The on-screen HUD, built in code:
--   center:       crosshair dot + a ring showing the pellet spread, hitmarker
--   bottom-left:  shield (blue) and health (green) bars
--   bottom-right: the two gun slots, with the active one highlighted and a
--                 bar that fills up as each gun finishes pumping

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Hud = {}

local gui: ScreenGui
local spreadRing: Frame
local hitmarker: Frame
local hitmarkerBars: { Frame } = {}
local hitmarkerUntil = 0
local healthFill: Frame
local healthText: TextLabel
local shieldFill: Frame
local shieldText: TextLabel
local slotFrames: { { frame: Frame, fill: Frame, status: TextLabel, stroke: UIStroke } } = {}

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function makeBar(name: string, color: Color3, y: number): (Frame, TextLabel)
	local back = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, y),
		Size = UDim2.fromOffset(260, 22),
		BackgroundColor3 = Color3.fromRGB(20, 20, 25),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
	}, gui)
	local fill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, back)
	local text = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5,
		ZIndex = 2,
	}, back)
	return fill, text
end

function Hud.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = make("ScreenGui", { Name = "DoublePumpHud", ResetOnSpawn = false, IgnoreGuiInset = true }, playerGui)

	-- Crosshair
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, gui)
	spreadRing = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, spreadRing)
	make("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.6, Thickness = 1.5 }, spreadRing)

	-- Hitmarker: four short bars in an X around the center
	hitmarker = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(36, 36),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) } do
		local bar = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, corner.X * 11, 0.5, corner.Y * 11),
			Size = UDim2.fromOffset(12, 3),
			Rotation = if corner.X == corner.Y then 45 else -45,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		}, hitmarker)
		table.insert(hitmarkerBars, bar)
	end

	-- Health and shield
	healthFill, healthText = makeBar("Health", Color3.fromRGB(70, 200, 90), -24)
	shieldFill, shieldText = makeBar("Shield", Color3.fromRGB(70, 150, 255), -52)

	-- Gun slots
	for slot = 1, 2 do
		local frame = make("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -24 - (2 - slot) * 150, 1, -24),
			Size = UDim2.fromOffset(140, 56),
			BackgroundColor3 = Color3.fromRGB(20, 20, 25),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
		}, gui)
		local stroke = make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, frame)
		make("TextLabel", {
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = `{slot}  PUMP`,
		}, frame)
		local status = make("TextLabel", {
			Position = UDim2.fromOffset(8, 26),
			Size = UDim2.new(1, -16, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(200, 200, 200),
		}, frame)
		local barBack = make("Frame", {
			Position = UDim2.new(0, 8, 1, -12),
			Size = UDim2.new(1, -16, 0, 5),
			BackgroundColor3 = Color3.fromRGB(60, 60, 65),
			BorderSizePixel = 0,
		}, frame)
		local fill = make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BorderSizePixel = 0,
		}, barBack)
		slotFrames[slot] = { frame = frame, fill = fill, status = status, stroke = stroke }
	end
end

function Hud.showHitmarker(headshot: boolean, killed: boolean)
	local color = if killed
		then Color3.fromRGB(255, 70, 70)
		elseif headshot then Color3.fromRGB(255, 220, 50)
		else Color3.new(1, 1, 1)
	for _, bar in hitmarkerBars do
		bar.BackgroundColor3 = color
		-- Headshot hitmarkers are bigger and thicker
		bar.Size = if headshot then UDim2.fromOffset(16, 4) else UDim2.fromOffset(12, 3)
	end
	hitmarker.Size = if headshot then UDim2.fromOffset(46, 46) else UDim2.fromOffset(36, 36)
	hitmarker.Visible = true
	hitmarkerUntil = os.clock() + Config.Feel.HitmarkerTime
end

-- state: the client weapon state (activeSlot, equippedAt, lastFired, now)
function Hud.update(camera: Camera, humanoid: Humanoid?, state)
	-- Spread ring: how big the pellet cone looks on screen at this field of view
	local viewport = camera.ViewportSize
	local spreadTan = math.tan(math.rad(Config.Weapon.SpreadAngle))
	local fovTan = math.tan(math.rad(camera.FieldOfView / 2))
	local diameter = spreadTan / fovTan * viewport.Y
	spreadRing.Size = UDim2.fromOffset(diameter, diameter)

	if hitmarker.Visible and os.clock() > hitmarkerUntil then
		hitmarker.Visible = false
	end

	local health = if humanoid then humanoid.Health else 0
	local shield = if humanoid then humanoid:GetAttribute("Shield") or 0 else 0
	healthFill.Size = UDim2.fromScale(math.clamp(health / Config.Player.MaxHealth, 0, 1), 1)
	healthText.Text = `{math.ceil(health)}`
	shieldFill.Size = UDim2.fromScale(math.clamp(shield / Config.Player.MaxShield, 0, 1), 1)
	shieldText.Text = `{math.ceil(shield)}`

	for slot, ui in slotFrames do
		local active = slot == state.activeSlot
		local progress = math.clamp((state.now - state.lastFired[slot]) / Config.Weapon.FireCooldown, 0, 1)
		ui.fill.Size = UDim2.fromScale(progress, 1)
		ui.fill.BackgroundColor3 = if progress >= 1 then Color3.fromRGB(80, 255, 120) else Color3.fromRGB(255, 120, 60)
		ui.status.Text = if progress >= 1 then "READY" else "PUMPING..."
		ui.stroke.Transparency = if active then 0 else 1
		ui.frame.BackgroundTransparency = if active then 0.1 else 0.5
	end
end

return Hud
