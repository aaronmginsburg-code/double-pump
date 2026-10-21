--!strict
-- Creates ScreenGuis that scale with the screen. UI is laid out for a 1920x1080 reference
-- in pixel offsets; a UIScale shrinks/grows it for phones, tablets and big monitors.
-- Elements anchored to edges stay on those edges at every size.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local UIRoot = {}

local scales: { UIScale } = {}

function UIRoot.scaleFactor(): number
	local viewport = workspace.CurrentCamera.ViewportSize
	local s = math.min(viewport.X / 1920, viewport.Y / 1080)
	-- Small screens get a bit larger than proportional so text stays readable
	if s < 0.7 then
		s = s * 1.25
	end
	return math.clamp(s, 0.45, 1.25)
end

local function update()
	local s = UIRoot.scaleFactor()
	for _, scale in scales do
		scale.Scale = s
	end
end

-- A full-screen ScreenGui with a scaled root Frame. Returns (gui, root).
function UIRoot.screen(name: string, displayOrder: number, ignoreInset: boolean?): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.DisplayOrder = displayOrder
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = ignoreInset ~= false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	table.insert(scales, scale)
	-- The root covers the screen in "reference pixels": size = screen / scale
	local function resize()
		local s = UIRoot.scaleFactor()
		local viewport = workspace.CurrentCamera.ViewportSize
		root.Size = UDim2.fromOffset(viewport.X / s, viewport.Y / s)
		scale.Scale = s
	end
	resize()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui, root
end

function UIRoot.isSmallScreen(): boolean
	local viewport = workspace.CurrentCamera.ViewportSize
	return math.min(viewport.X, viewport.Y) < 600
end

function UIRoot.start()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(update)
end

return UIRoot
