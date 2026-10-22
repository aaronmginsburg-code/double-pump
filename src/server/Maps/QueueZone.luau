--!strict
-- Additional range furniture only; noncolliding and excluded from pellet queries.
local QueueZone = {}

function QueueZone.build(range: Model, cframe: CFrame, size: Vector3)
	local model = Instance.new("Model")
	model.Name = "MatchQueue"
	local edges: { Part } = {}
	local cyan = Color3.fromRGB(64, 214, 240)
	local function part(
		name: string,
		dimensions: Vector3,
		position: Vector3,
		color: Color3,
		material: Enum.Material
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = dimensions
		p.CFrame = CFrame.new(position)
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Color = color
		p.Material = material
		p.Parent = model
		return p
	end
	local floor = cframe.Position - Vector3.new(0, size.Y / 2 - 0.06, 0)
	part("QueueFloor", Vector3.new(size.X, 0.1, size.Z), floor, Color3.fromRGB(28, 61, 72), Enum.Material.SmoothPlastic)
	for _, sign in { -1, 1 } do
		table.insert(
			edges,
			part(
				"Boundary",
				Vector3.new(size.X, 0.12, 0.25),
				floor + Vector3.new(0, 0.1, sign * size.Z / 2),
				cyan,
				Enum.Material.Neon
			)
		)
		table.insert(
			edges,
			part(
				"Boundary",
				Vector3.new(0.25, 0.12, size.Z),
				floor + Vector3.new(sign * size.X / 2, 0.1, 0),
				cyan,
				Enum.Material.Neon
			)
		)
	end
	local anchor = part("QueueDisplay", Vector3.one, floor + Vector3.new(0, 9, 0), cyan, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "QueueDisplay"
	gui.Size = UDim2.fromOffset(360, 142)
	gui.MaxDistance = 150
	gui.AlwaysOnTop = false
	gui.Parent = anchor
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(18, 24, 32)
	panel.BackgroundTransparency = 0.08
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = cyan
	stroke.Thickness = 2
	stroke.Parent = panel
	local function label(name: string, y: number, height: number, textSize: number): TextLabel
		local text = Instance.new("TextLabel")
		text.Name = name
		text.Size = UDim2.new(1, -24, 0, height)
		text.Position = UDim2.fromOffset(12, y)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextSize = textSize
		text.TextColor3 = Color3.fromRGB(244, 246, 250)
		text.Parent = panel
		return text
	end
	local title = label("Title", 10, 34, 27)
	local population = label("Population", 48, 30, 23)
	local status = label("Status", 88, 38, 18)
	model.Parent = range
	return function(state: string, count: number, capacity: number, minimum: number, seconds: number)
		local countdown = state == "Countdown"
		local color = if countdown then Color3.fromRGB(255, 186, 48) else cyan
		title.Text = if countdown then "MATCH STARTING" else "MATCH QUEUE"
		title.TextColor3 = color
		population.Text = `{count} / {capacity} Players`
		status.Text = if countdown
			then `Starting in {seconds} seconds`
			elseif state == "Pending" then "Arena occupied - next match pending"
			else `Waiting for players - minimum {minimum}`
		stroke.Color = color
		for _, edge in edges do
			edge.Color = color
		end
	end
end

return QueueZone
