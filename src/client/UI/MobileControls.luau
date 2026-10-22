--!strict
-- Touch-only adapter: fixed movement stick and free-screen drag aiming, one owned finger per control,
-- deliberate swipe intents, and one cancellable held-fire follow-up per valid swap.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Layout = require(Shared.Mobile.Layout)
local TouchState = require(Shared.Mobile.TouchState)
local FireSequence = require(Shared.Mobile.FireSequence)
local Theme = require(script.Parent.Theme)
local Controllers = script.Parent.Parent.Controllers
local InputController = require(Controllers.InputController)
local CameraController = require(Controllers.CameraController)
local WeaponController = require(Controllers.WeaponController)
local Settings = require(Controllers.Settings)

local MobileControls = {}
local player = Players.LocalPlayer
local C, new = Theme.Colors, Theme.new
local gui: ScreenGui
local holder: Frame
local editBar: Frame
local buttons: { [string]: TextButton } = {}
local knobs: { [string]: Frame } = {}
local current: Layout.Result = Layout.calculate(844, 390, false)
local touches = TouchState.new(1)
local sequence = FireSequence.new()
local moveStick = Vector2.zero
local jumpHeld = false
local wanted, editing = false, false
local controls: any = nil
local customControls = false
local editStarts: { [InputObject]: { name: string, x: number, y: number, start: Vector2 } } = {}
local labels: { [string]: string } = {
	Fire = "FIRE",
	Move = "MOVE",
	Jump = "↑",
	Reload = "R",
	Crouch = "C",
	EquipA = "1",
	EquipB = "2",
	Scoreboard = "≡",
	Menu = "II",
	Swipe = "↓ SWAP",
}
local mouseDrag: InputObject? = nil

local function point(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y) - holder.AbsolutePosition
end

local function pressed(name: string, on: boolean)
	local b = buttons[name]
	if b then
		b.BackgroundTransparency = if on then 0.08 elseif name == "Swipe" then 0.94 else 0.3
	end
end

local function neutral()
	sequence:release()
	for _, role in { "Crouch", "Scoreboard" } do
		if touches.owners[role] then
			InputController.trigger(role, false)
		end
	end
	touches:clear()
	table.clear(editStarts)
	mouseDrag = nil
	moveStick = Vector2.zero
	jumpHeld = false
	CameraController.clearTouchLook()
	for name in buttons do
		pressed(name, false)
	end
	for _, knob in knobs do
		knob.Position = UDim2.fromScale(0.5, 0.5)
	end
end

local function place()
	if not holder then
		return
	end
	neutral()
	local size = holder.AbsoluteSize
	current = Layout.calculate(size.X, size.Y, Settings.values.controlLayout == "left", Settings.values.touchLayoutV2)
	touches.unit = current.unit
	for name, b in buttons do
		local r = current.rects[name]
		b.Position = UDim2.fromOffset(r.x, r.y)
		b.Size = UDim2.fromOffset(r.w, r.h)
	end
end

local function updateVisibility()
	if not gui then
		return
	end
	local touchMode = InputController.LastInputKind == "Touch"
	local show = editing or (wanted and touchMode)
	if gui.Enabled ~= show then
		neutral()
	end
	gui.Enabled = show
	CameraController.touchInputEnabled = touchMode
	if controls and customControls ~= touchMode then
		customControls = touchMode
		if touchMode then
			controls:Disable()
		else
			controls:Enable()
		end
	end
	local defaultTouch = player.PlayerGui:FindFirstChild("TouchGui")
	if defaultTouch and defaultTouch:IsA("ScreenGui") and touchMode then
		defaultTouch.Enabled = false
	end
end

function MobileControls.isOnControl(position: Vector2): boolean
	if not gui or not gui.Enabled or editing or not wanted or GuiService.MenuIsOpen then
		return true
	end
	local p = position - holder.AbsolutePosition
	for name, r in current.rects do
		if buttons[name] and Layout.contains(r, p.X, p.Y) then
			return true
		end
	end
	return false
end

local function swipe()
	sequence:swipe(function()
		local nextSlot = if WeaponController.state.equipped == 1 then 2 else 1
		if WeaponController.equip(nextSlot) then
			return nextSlot
		end
		return nil
	end)
end

local function changed(input: InputObject)
	if editing and mouseDrag and input.UserInputType == Enum.UserInputType.MouseMovement then
		-- Mouse is only an editor fallback. Combat touch ownership remains physical.
		local drag = editStarts[mouseDrag]
		if drag then
			local p = point(input)
			local size = holder.AbsoluteSize
			local center = Vector2.new(drag.x, drag.y) + p - drag.start
			local x = center.X / math.max(size.X, 1)
			if Settings.values.controlLayout == "left" then
				x = 1 - x
			end
			local saved = table.clone(Settings.values.touchLayoutV2)
			saved[drag.name] = { x, center.Y / math.max(size.Y, 1), 1 }
			Settings.values.touchLayoutV2 = saved
			current = Layout.calculate(size.X, size.Y, Settings.values.controlLayout == "left", saved)
			for name, b in buttons do
				local r = current.rects[name]
				b.Position = UDim2.fromOffset(r.x, r.y)
				b.Size = UDim2.fromOffset(r.w, r.h)
			end
		end
		return
	end
	local drag = editStarts[input]
	if drag and editing then
		local pos = point(input)
		local delta = pos - drag.start
		local size = holder.AbsoluteSize
		local x = (drag.x + delta.X) / math.max(size.X, 1)
		if Settings.values.controlLayout == "left" then
			x = 1 - x
		end
		local saved = table.clone(Settings.values.touchLayoutV2)
		saved[drag.name] = { x, (drag.y + delta.Y) / math.max(size.Y, 1), 1 }
		Settings.values.touchLayoutV2 = saved
		-- Reflow without releasing the editor's drag ownership.
		current = Layout.calculate(size.X, size.Y, Settings.values.controlLayout == "left", saved)
		for name, b in buttons do
			local r = current.rects[name]
			b.Position = UDim2.fromOffset(r.x, r.y)
			b.Size = UDim2.fromOffset(r.w, r.h)
		end
		return
	end
	local t = touches.touches[input]
	if not t then
		return
	end
	local pos = point(input)
	if t.role == "Swipe" then
		if touches:move(input, pos.X, pos.Y, os.clock()) then
			swipe()
		end
	elseif t.role == "Move" then
		local r = current.rects[t.role]
		local v = TouchState.stick(pos.X - r.x - r.w / 2, pos.Y - r.y - r.h / 2, r.w * 0.30)
		knobs[t.role].Position = UDim2.new(0.5, v.X * r.w * 0.28, 0.5, v.Y * r.h * 0.28)
		moveStick = v
	end
end

local function began(name: string, input: InputObject)
	if
		input.UserInputType ~= Enum.UserInputType.Touch
		and not (editing and input.UserInputType == Enum.UserInputType.MouseButton1)
	then
		return
	end
	local p = point(input)
	if editing then
		if name ~= "Swipe" then
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				mouseDrag = input
			end
			local r = current.rects[name]
			editStarts[input] = { name = name, x = r.x + r.w / 2, y = r.y + r.h / 2, start = p }
		end
		return
	end
	if not wanted or GuiService.MenuIsOpen or not touches:begin(input, name, p.X, p.Y, os.clock()) then
		return
	end
	pressed(name, true)
	if name == "Fire" then
		sequence:press(WeaponController.fireMobile)
	elseif name == "Move" then
		changed(input)
	elseif name == "Jump" then
		jumpHeld = true
	elseif name == "Crouch" or name == "Scoreboard" then
		InputController.trigger(name, true)
	elseif name ~= "Swipe" then
		sequence.pending = nil
		InputController.trigger(name, true)
	end
end

local function ended(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and mouseDrag then
		editStarts[mouseDrag] = nil
		mouseDrag = nil
	end
	editStarts[input] = nil
	-- Some devices deliver only a final change on touch-up. Consume at most once.
	changed(input)
	local role = touches:finish(input)
	if not role then
		return
	end
	pressed(role, false)
	if role == "Fire" then
		sequence:release()
	elseif role == "Move" then
		moveStick = Vector2.zero
	elseif role == "Jump" then
		jumpHeld = false
	elseif role == "Crouch" or role == "Scoreboard" then
		InputController.trigger(role, false)
	end
	if knobs[role] then
		knobs[role].Position = UDim2.fromScale(0.5, 0.5)
	end
end

function MobileControls.setActive(active: boolean)
	wanted = active
	if not active then
		neutral()
	end
	updateVisibility()
end

function MobileControls.edit()
	neutral()
	editing = true
	gui.DisplayOrder = 60
	editBar.Visible = true
	updateVisibility()
end

function MobileControls.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "MobileControls"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	holder =
		new("Frame", { Name = "TouchSurface", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	gui.Parent = player:WaitForChild("PlayerGui")
	for name, text in labels do
		local fire = name == "Fire"
		local b = new("TextButton", {
			Name = name,
			Text = if name == "Move" then "" else text,
			AutoButtonColor = false,
			BackgroundColor3 = if fire then C.Accent else C.Panel,
			TextColor3 = if fire then C.Ink else C.Text,
			FontFace = Theme.Fonts.Display,
			TextScaled = true,
			Active = true,
			Parent = holder,
		}, {
			new("UICorner", { CornerRadius = UDim.new(if name == "Swipe" then 0.08 else 0.5, 0) }),
			Theme.stroke(if fire then C.AccentDark else C.Stroke, 2, 0.2),
			new("UIPadding", {
				PaddingLeft = UDim.new(0.15, 0),
				PaddingRight = UDim.new(0.15, 0),
				PaddingTop = UDim.new(0.27, 0),
				PaddingBottom = UDim.new(0.27, 0),
			}),
		}) :: TextButton
		buttons[name] = b
		if name == "Move" or name == "Fire" or name == "Swipe" then
			local padding = b:FindFirstChildOfClass("UIPadding")
			if padding then
				padding:Destroy()
			end
		end
		if name == "Swipe" then
			b.Text = ""
			Theme.label({
				Text = "↓ SWAP",
				Position = UDim2.fromScale(0, 0.03),
				Size = UDim2.fromScale(1, 0.15),
				TextColor3 = C.TextDim,
				Outline = false,
				Parent = b,
			})
		end
		if name == "Move" then
			local knob = new("Frame", {
				Name = "Thumb",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.43, 0.43),
				BackgroundColor3 = C.Text,
				BackgroundTransparency = 0.45,
				Parent = b,
			}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }) :: Frame
			knobs[name] = knob
			Theme.label({
				Text = text,
				Size = UDim2.fromScale(1, 0.18),
				Position = UDim2.fromScale(0, 0.76),
				FontFace = Theme.Fonts.Bold,
				Outline = false,
				Parent = b,
			})
		elseif fire then
			-- Local vector glyph: no external image dependency.
			b.Text = ""
			Theme.label({
				Text = "⊕",
				Position = UDim2.fromScale(0.1, 0),
				Size = UDim2.fromScale(0.8, 0.63),
				TextColor3 = C.Ink,
				Outline = false,
				Parent = b,
			})
			Theme.label({
				Text = "FIRE",
				Position = UDim2.fromScale(0, 0.66),
				Size = UDim2.fromScale(1, 0.26),
				TextColor3 = C.Ink,
				Outline = false,
				Parent = b,
			})
		end
		b.InputBegan:Connect(function(input)
			began(name, input)
		end)
		pressed(name, false)
	end
	editBar = Theme.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.55, 0.12),
		Visible = false,
		Parent = gui,
	})
	Theme.label({
		Text = "Drag controls • unsafe overlaps are rejected",
		Size = UDim2.fromScale(0.6, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Outline = false,
		Parent = editBar,
	})
	local reset = Theme.button(
		"RESET",
		"Ghost",
		{ Position = UDim2.fromScale(0.62, 0.1), Size = UDim2.fromScale(0.18, 0.8), Parent = editBar }
	)
	reset.Activated:Connect(function()
		Settings.values.touchLayoutV2 = {}
		place()
	end)
	local done = Theme.button(
		"DONE",
		"Primary",
		{ Position = UDim2.fromScale(0.81, 0.1), Size = UDim2.fromScale(0.18, 0.8), Parent = editBar }
	)
	done.Activated:Connect(function()
		editing = false
		editBar.Visible = false
		gui.DisplayOrder = 12
		Settings.set("touchLayoutV2", Settings.values.touchLayoutV2)
		Settings.save()
		updateVisibility()
	end)
	CameraController.isTouchOnControl = MobileControls.isOnControl
	UserInputService.InputChanged:Connect(changed)
	UserInputService.InputEnded:Connect(ended)
	UserInputService.WindowFocusReleased:Connect(neutral)
	GuiService.MenuOpened:Connect(neutral)
	player.CharacterAdded:Connect(neutral)
	WeaponController.Reset:Connect(neutral)
	WeaponController.Rejected:Connect(function()
		sequence.pending = nil
	end)
	InputController.Action:Connect(function(action, down)
		if down and (action == "Reload" or action == "EquipA" or action == "EquipB" or action == "Swap") then
			sequence.pending = nil
		end
	end)
	InputController.InputKindChanged:Connect(function()
		neutral()
		updateVisibility()
	end)
	Settings.Changed:Connect(place)
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()
	task.spawn(function()
		local pm = player.PlayerScripts:WaitForChild("PlayerModule", 10)
		if pm and pm:IsA("ModuleScript") then
			controls = (require(pm) :: any):GetControls()
			updateVisibility()
		end
	end)
	RunService:BindToRenderStep("DoublePumpMobileMove", Enum.RenderPriority.Input.Value, function()
		updateVisibility()
		local active = wanted and gui.Enabled and not editing and not GuiService.MenuIsOpen
		if not active then
			if sequence.held or next(touches.touches) then
				neutral()
			end
		end
		if customControls then
			player:Move(if active then Vector3.new(moveStick.X, 0, moveStick.Y) else Vector3.zero, true)
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and active and jumpHeld then
				hum.Jump = true
			end
		end
	end)
	RunService.Heartbeat:Connect(function()
		local ready, reason = WeaponController.mobileReady()
		sequence:step(
			wanted and gui.Enabled and not editing and not GuiService.MenuIsOpen,
			WeaponController.state.equipped,
			ready,
			reason,
			WeaponController.fireMobile
		)
	end)
	WeaponController.Equipped:Connect(function(slot)
		for name, b in buttons do
			if name == "EquipA" or name == "EquipB" then
				local stroke = b:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = if (name == "EquipA") == (slot == 1) then C.Accent else C.Stroke
				end
			end
		end
	end)
	updateVisibility()
end
return MobileControls
