--!strict
-- Short notifications (server notices, unlocks, challenge completions) stacked on the
-- right side of the screen, below the kill feed.

local Theme = require(script.Parent.Theme)
local UIRoot = require(script.Parent.UIRoot)

local Toasts = {}

local C = Theme.Colors
local new = Theme.new
local holder: Frame
local order = 0

local KIND_COLORS: { [string]: Color3 } = {
	info = C.Text,
	good = C.Good,
	warn = C.Gold,
	error = C.Hot,
	reward = C.Accent,
}

function Toasts.show(text: string, kind: string?, duration: number?)
	if not holder then
		return
	end
	order += 1
	local color = KIND_COLORS[kind or "info"] or C.Text
	local toast = Theme.panel({
		Name = "Toast",
		Size = UDim2.fromOffset(420, 54),
		LayoutOrder = order,
		BackgroundTransparency = 0.15,
		Parent = holder,
	})
	new("Frame", {
		Size = UDim2.new(0, 6, 1, -16),
		Position = UDim2.fromOffset(10, 8),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = toast,
	}, { Theme.corner(3) })
	Theme.label({
		Text = text,
		Size = UDim2.new(1, -40, 1, -16),
		Position = UDim2.fromOffset(28, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Bold,
		TextColor3 = C.Text,
		Parent = toast,
	})
	local scale = new("UIScale", { Scale = 0.8, Parent = toast }) :: UIScale
	Theme.tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(duration or 3.5, function()
		Theme.tween(scale, 0.2, { Scale = 0.01 })
		task.wait(0.2)
		toast:Destroy()
	end)
	local items = holder:GetChildren()
	local count = 0
	for _, child in items do
		if child:IsA("Frame") then
			count += 1
		end
	end
	-- Keep at most 4 visible
	if count > 4 then
		local oldest: Frame? = nil
		for _, child in items do
			if child:IsA("Frame") and (oldest == nil or child.LayoutOrder < (oldest :: Frame).LayoutOrder) then
				oldest = child
			end
		end
		if oldest then
			oldest:Destroy()
		end
	end
end

function Toasts.start()
	local _, root = UIRoot.screen("Toasts", 40)
	holder = new("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 330),
		Size = UDim2.fromOffset(420, 300),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Theme.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right) })
end

return Toasts
