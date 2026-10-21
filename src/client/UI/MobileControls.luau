--!strict
-- Touch controls: FIRE (drag it to aim while shooting), SWAP, 1 / 2, RELOAD, CROUCH,
-- plus scoreboard and menu. Movement uses Roblox's thumbstick and jump button.
-- Every button is a deliberate tap: SWAP never fires and FIRE never swaps.
--
-- Layout editor (Settings > Touch button layout): drag buttons anywhere, pinch-free
-- size with the +/- chips, Reset to restore, Done to save into the profile.

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local UIRoot = require(script.Parent.UIRoot)
local Controllers = script.Parent.Parent.Controllers
local InputController = require(Controllers.InputController)
local CameraController = require(Controllers.CameraController)
local WeaponController = require(Controllers.WeaponController)
local Settings = require(Controllers.Settings)

local MobileControls = {}

local C = Theme.Colors
local new = Theme.new

type ButtonDef = {
	name: string,
	text: string,
	action: string,
	size: number,
	x: number,
	y: number,
	hold: boolean?,
	look: boolean?,
}

-- Default positions as fractions of the screen (anchor at the button centre).
local DEFS: { ButtonDef } = {
	{ name = "Fire", text = "FIRE", action = "Fire", size = 150, x = 0.86, y = 0.62, hold = true, look = true },
	{ name = "Swap", text = "SWAP", action = "Swap", size = 104, x = 0.73, y = 0.79 },
	{ name = "EquipA", text = "1", action = "EquipA", size = 78, x = 0.68, y = 0.58 },
	{ name = "EquipB", text = "2", action = "EquipB", size = 78, x = 0.75, y = 0.47 },
	{ name = "Reload", text = "R", action = "Reload", size = 78, x = 0.95, y = 0.40 },
	{ name = "Crouch", text = "C", action = "Crouch", size = 86, x = 0.93, y = 0.86, hold = true },
	{ name = "Scoreboard", text = "≡", action = "Scoreboard", size = 64, x = 0.62, y = 0.08, hold = true },
	{ name = "Menu", text = "II", action = "Menu", size = 64, x = 0.68, y = 0.08 },
}

local gui: ScreenGui
local holder: Frame
local buttons: { [string]: { frame: TextButton, def: ButtonDef, scale: UIScale } } = {}
local editing = false
local editBar: Frame
local wanted = false

local function layoutOf(name: string): (number, number, number)
	local saved = Settings.values.touchLayout[name]
	for _, def in DEFS do
		if def.name == name then
			if saved then
				return saved[1], saved[2], saved[3] or 1
			end
			return def.x, def.y, 1
		end
	end
	return 0.5, 0.5, 1
end

local function place()
	-- Sized from the screen height so buttons are thumb-sized on phones and tablets
	local k = math.clamp(workspace.CurrentCamera.ViewportSize.Y / 720, 0.55, 1.3)
	for name, entry in buttons do
		local x, y, sc = layoutOf(name)
		entry.frame.Position = UDim2.fromScale(x, y)
		entry.frame.Size = UDim2.fromOffset(entry.def.size * k, entry.def.size * k)
		entry.scale.Scale = sc
	end
end

function MobileControls.isOnControl(position: Vector2): boolean
	if not gui or not gui.Enabled then
		return false
	end
	for _, entry in buttons do
		local f = entry.frame
		local p, s = f.AbsolutePosition, f.AbsoluteSize
		if position.X >= p.X and position.X <= p.X + s.X and position.Y >= p.Y and position.Y <= p.Y + s.Y then
			return true
		end
	end
	return false
end

local function makeButton(def: ButtonDef)
	local isFire = def.name == "Fire"
	local button = new("TextButton", {
		Name = def.name,
		Text = def.text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(def.size, def.size),
		BackgroundColor3 = if isFire then C.Accent else C.Panel,
		BackgroundTransparency = if isFire then 0.15 else 0.35,
		TextColor3 = if isFire then C.Ink else C.Text,
		FontFace = Theme.Fonts.Display,
		TextScaled = true,
		AutoButtonColor = false,
		Parent = holder,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Theme.stroke(if isFire then C.AccentDark else C.Stroke, 3, 0.2),
		new("UIPadding", {
			PaddingTop = UDim.new(0.26, 0),
			PaddingBottom = UDim.new(0.26, 0),
			PaddingLeft = UDim.new(0.18, 0),
			PaddingRight = UDim.new(0.18, 0),
		}),
	}) :: TextButton
	local scale = new("UIScale", { Parent = button }) :: UIScale
	buttons[def.name] = { frame = button, def = def, scale = scale }

	local activeTouch: InputObject? = nil
	local dragStart: Vector2? = nil
	local startPos: Vector2? = nil
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseButton1
		then
			return
		end
		if editing then
			activeTouch = input
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPos = button.AbsolutePosition + button.AbsoluteSize / 2
			return
		end
		activeTouch = input
		button.BackgroundTransparency = 0
		InputController.trigger(def.action, true)
		if not def.hold then
			InputController.trigger(def.action, false)
		end
		if def.look and input.UserInputType == Enum.UserInputType.Touch then
			CameraController.addLookTouch(input)
		end
	end)
	local function release(input: InputObject)
		if input ~= activeTouch then
			return
		end
		activeTouch = nil
		button.BackgroundTransparency = if isFire then 0.15 else 0.35
		if editing then
			return
		end
		if def.hold then
			InputController.trigger(def.action, false)
		end
	end
	button.InputEnded:Connect(release)
	UserInputService.InputEnded:Connect(release)
	UserInputService.InputChanged:Connect(function(input)
		if editing and input == activeTouch and dragStart and startPos then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - (dragStart :: Vector2)
			local center = (startPos :: Vector2) + delta
			local viewport = workspace.CurrentCamera.ViewportSize
			local _, _, sc = layoutOf(def.name)
			local layout = table.clone(Settings.values.touchLayout)
			layout[def.name] =
				{ math.clamp(center.X / viewport.X, 0.03, 0.97), math.clamp(center.Y / viewport.Y, 0.05, 0.95), sc }
			Settings.values.touchLayout = layout
			place()
		end
	end)
end

local function updateVisibility()
	local show = editing or (wanted and InputController.LastInputKind == "Touch")
	gui.Enabled = show
end

-- Called by the flow controller: true while the player is in combat.
function MobileControls.setActive(active: boolean)
	wanted = active
	updateVisibility()
end

function MobileControls.edit()
	editing = true
	gui.DisplayOrder = 60 -- above the menu it was opened from
	editBar.Visible = true
	updateVisibility()
end

local function stopEditing()
	editing = false
	gui.DisplayOrder = 12
	editBar.Visible = false
	Settings.set("touchLayout", Settings.values.touchLayout)
	Settings.save()
	updateVisibility()
end

function MobileControls.start()
	gui = UIRoot.screen("MobileControls", 12)
	gui.Enabled = false
	-- Buttons are positioned in real screen space (not the scaled reference space) so the
	-- layout fractions mean the same thing on every device.
	holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	for _, def in DEFS do
		makeButton(def)
	end
	place()

	editBar = Theme.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		Size = UDim2.fromOffset(520, 70),
		Visible = false,
		Parent = gui,
	})
	Theme.label({
		Text = "Drag buttons to move them",
		Size = UDim2.new(0.5, 0, 1, -20),
		Position = UDim2.fromOffset(14, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Bold,
		Parent = editBar,
	})
	local function sizeAll(delta: number)
		local layout = table.clone(Settings.values.touchLayout)
		for _, def in DEFS do
			local x, y, sc = layoutOf(def.name)
			layout[def.name] = { x, y, math.clamp(sc + delta, 0.6, 1.5) }
		end
		Settings.values.touchLayout = layout
		place()
	end
	local smaller = Theme.button(
		"-",
		"Secondary",
		{ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0.5, 0, 0, 13), Parent = editBar }
	)
	smaller.Activated:Connect(function()
		sizeAll(-0.1)
	end)
	local bigger = Theme.button(
		"+",
		"Secondary",
		{ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0.5, 50, 0, 13), Parent = editBar }
	)
	bigger.Activated:Connect(function()
		sizeAll(0.1)
	end)
	local reset = Theme.button(
		"RESET",
		"Ghost",
		{ Size = UDim2.fromOffset(84, 44), Position = UDim2.new(0.5, 100, 0, 13), Parent = editBar }
	)
	reset.Activated:Connect(function()
		Settings.values.touchLayout = {}
		place()
	end)
	local done = Theme.button(
		"DONE",
		"Primary",
		{ Size = UDim2.fromOffset(80, 44), Position = UDim2.new(0.5, 180, 0, 13), Parent = editBar }
	)
	done.Activated:Connect(stopEditing)

	CameraController.isTouchOnControl = MobileControls.isOnControl
	InputController.InputKindChanged:Connect(updateVisibility)
	Settings.Changed:Connect(place)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	-- Highlight which gun is out
	WeaponController.Equipped:Connect(function(slot)
		for name, entry in buttons do
			if name == "EquipA" or name == "EquipB" then
				local mine = (name == "EquipA" and slot == 1) or (name == "EquipB" and slot == 2)
				entry.frame.BackgroundColor3 = if mine then C.PanelLight else C.Panel
				local stroke = entry.frame:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = if mine then C.Accent else C.Stroke
				end
			end
		end
	end)
end

return MobileControls
