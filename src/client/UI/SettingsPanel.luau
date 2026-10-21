--!strict
-- Settings page: builds into any parent frame (main menu tab or in-match pause menu).
-- Every change applies instantly and is saved to the profile (debounced).

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Theme = require(script.Parent.Theme)
local Settings = require(script.Parent.Parent.Controllers.Settings)

local SettingsPanel = {}

local C = Theme.Colors
local new = Theme.new

-- Set by the bootstrap: opens the touch-button layout editor.
SettingsPanel.editTouchLayout = nil :: (() -> ())?

local function row(parent: Instance, order: number, title: string): Frame
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = C.PanelLight,
		BackgroundTransparency = 0.35,
		LayoutOrder = order,
		Parent = parent,
	}, { Theme.corner(10) })
	Theme.label({
		Text = title,
		Size = UDim2.new(0.4, 0, 0, 26),
		Position = UDim2.new(0, 18, 0.5, -13),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Bold,
		Outline = false,
		Parent = frame,
	})
	return frame
end

local function header(parent: Instance, order: number, text: string)
	Theme.label({
		Text = text,
		Size = UDim2.new(1, 0, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Display,
		TextColor3 = C.Accent,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function slider(
	parent: Instance,
	order: number,
	title: string,
	key: string,
	min: number,
	max: number,
	step: number,
	format: (number) -> string
)
	local frame = row(parent, order, title)
	local track = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.32, 0, 0, 8),
		BackgroundColor3 = C.Ink,
		Parent = frame,
	}, { Theme.corner(4) })
	local fill = new(
		"Frame",
		{ Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = C.Accent, Parent = track },
		{ Theme.corner(4) }
	)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = C.Text,
		Parent = track,
	}, { Theme.corner(11), Theme.stroke(C.AccentDark, 2) })
	local valueLabel = Theme.label({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(90, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = Theme.Fonts.Bold,
		Outline = false,
		Parent = frame,
	})
	local function show()
		local v = (Settings.values :: any)[key] :: number
		local a = math.clamp((v - min) / (max - min), 0, 1)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		valueLabel.Text = format(v)
	end
	local function setFromX(x: number)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		local v = min + a * (max - min)
		v = math.round(v / step) * step
		Settings.set(key, v)
		Settings.save()
		show()
	end
	local dragging = false
	local hit = new("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 24, 0, 40),
		Position = UDim2.new(0, -12, 0.5, -20),
		Parent = track,
	}) :: TextButton
	hit.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	-- Gamepad: select the row and press left/right
	local function nudge(direction: number)
		local v = (Settings.values :: any)[key] :: number
		Settings.set(key, math.clamp(v + direction * step, min, max))
		Settings.save()
		show()
	end
	local minus = Theme.button(
		"-",
		"Ghost",
		{
			Size = UDim2.fromOffset(34, 34),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(0.5, -14, 0.5, 0),
			Parent = frame,
		}
	)
	minus.Activated:Connect(function()
		nudge(-1)
	end)
	local plus = Theme.button(
		"+",
		"Ghost",
		{
			Size = UDim2.fromOffset(34, 34),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.82, 14, 0.5, 0),
			Parent = frame,
		}
	)
	plus.Activated:Connect(function()
		nudge(1)
	end)
	valueLabel.Position = UDim2.new(1, -12, 0.5, 0)
	valueLabel.Size = UDim2.fromOffset(70, 26)
	Settings.Changed:Connect(show)
	show()
end

local function toggle(parent: Instance, order: number, title: string, key: string)
	local frame = row(parent, order, title)
	local button = Theme.button("", "Secondary", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(120, 38),
		Parent = frame,
	})
	local function show()
		local on = (Settings.values :: any)[key] == true
		button.Text = if on then "ON" else "OFF"
		button.BackgroundColor3 = if on then C.Good else C.PanelLight
		button.TextColor3 = if on then C.Ink else C.TextDim
	end
	button.Activated:Connect(function()
		Settings.set(key, not (Settings.values :: any)[key])
		Settings.save()
		show()
	end)
	Settings.Changed:Connect(show)
	show()
end

local function choice(parent: Instance, order: number, title: string, key: string, options: { string })
	local frame = row(parent, order, title)
	local button = Theme.button("", "Secondary", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(200, 38),
		Parent = frame,
	})
	local function show()
		button.Text = tostring((Settings.values :: any)[key]) .. "  ▸"
	end
	button.Activated:Connect(function()
		local current = table.find(options, (Settings.values :: any)[key]) or 0
		Settings.set(key, options[current % #options + 1])
		Settings.save()
		show()
	end)
	Settings.Changed:Connect(show)
	show()
end

local function action(parent: Instance, order: number, title: string, buttonText: string, fn: () -> ())
	local frame = row(parent, order, title)
	local button = Theme.button(buttonText, "Secondary", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(200, 38),
		Parent = frame,
	})
	button.Activated:Connect(fn)
end

-- Builds the settings list into `parent` (a frame that should be fully sized).
function SettingsPanel.build(parent: Instance): ScrollingFrame
	local scroll = new("ScrollingFrame", {
		Name = "Settings",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	}, {
		Theme.list(Enum.FillDirection.Vertical, 8),
		new("UIPadding", { PaddingRight = UDim.new(0, 14) }),
	}) :: ScrollingFrame
	local Cam = GameConfig.Camera
	local function decimal(v: number)
		return string.format("%.2f", v)
	end
	local function percent(v: number)
		return string.format("%d%%", math.round(v * 100))
	end
	local o = 0
	local function n()
		o += 1
		return o
	end

	header(scroll, n(), "AIM")
	slider(scroll, n(), "Mouse sensitivity", "sensitivity", Cam.MinSensitivity, Cam.MaxSensitivity, 0.05, decimal)
	slider(scroll, n(), "Controller sensitivity", "gamepadSensitivity", 0.2, 3, 0.05, decimal)
	slider(scroll, n(), "Touch sensitivity", "touchSensitivity", 0.2, 3, 0.05, decimal)
	slider(scroll, n(), "Field of view", "fov", Cam.MinFov, Cam.MaxFov, 1, function(v)
		return tostring(math.round(v)) .. "°"
	end)

	header(scroll, n(), "CROSSHAIR")
	choice(scroll, n(), "Style", "crosshairStyle", { "CrossDot", "Cross", "Dot", "Circle" })
	choice(scroll, n(), "Colour", "crosshairColor", { "White", "Green", "Yellow", "Cyan", "Pink" })
	slider(scroll, n(), "Size", "crosshairSize", 0.6, 1.6, 0.05, decimal)

	header(scroll, n(), "CONTROLS")
	toggle(scroll, n(), "Crouch is a toggle", "crouchToggle")
	toggle(scroll, n(), "Mouse wheel switches guns", "wheelSwitching")
	action(scroll, n(), "Touch button layout", "Edit layout", function()
		if SettingsPanel.editTouchLayout then
			SettingsPanel.editTouchLayout()
		end
	end)

	header(scroll, n(), "AUDIO")
	slider(scroll, n(), "Master volume", "masterVolume", 0, 1, 0.05, percent)
	slider(scroll, n(), "Music volume", "musicVolume", 0, 1, 0.05, percent)
	slider(scroll, n(), "Effects volume", "effectsVolume", 0, 1, 0.05, percent)

	header(scroll, n(), "DISPLAY")
	toggle(scroll, n(), "Damage numbers", "showDamageNumbers")
	toggle(scroll, n(), "Camera bob", "cameraBob")
	toggle(scroll, n(), "Reduced effects", "reducedEffects")

	action(scroll, n(), "Restore defaults", "Reset", function()
		Settings.reset()
	end)
	return scroll
end

return SettingsPanel
