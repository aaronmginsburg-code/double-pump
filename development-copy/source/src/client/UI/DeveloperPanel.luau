--!strict
-- Private developer console shell: Aim Assist is its first module.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.AimAssist.Config)
local A = require(script.Parent.Parent.Controllers.AimAssistController)
local Camera = require(script.Parent.Parent.Controllers.CameraController)
local Input = require(script.Parent.Parent.Controllers.InputController)
local Panel = {}
local ink, muted, accent = Color3.fromRGB(237, 245, 255), Color3.fromRGB(151, 173, 193), Color3.fromRGB(50, 221, 208)
local function new(class: string, properties: any, parent: Instance?): any
	local item = Instance.new(class)
	for key, value in properties do
		item[key] = value
	end
	item.Parent = parent
	return item
end
local function text(parent: Instance, value: string, size: UDim2, position: UDim2): TextLabel
	return new("TextLabel", {
		Text = value,
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		TextColor3 = ink,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, parent)
end
local function button(parent: Instance, value: string, size: UDim2, position: UDim2): TextButton
	local b = new("TextButton", {
		Text = value,
		Size = size,
		Position = position,
		TextColor3 = ink,
		BackgroundColor3 = Color3.fromRGB(35, 57, 73),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = true,
		Active = true,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 7) }, b)
	return b
end
function Panel.start()
	if game.GameId ~= 10772492892 or game.PlaceId ~= 139437092998076 then
		return
	end
	task.spawn(function()
		local deadline = os.clock() + 20
		while not A.authorized and os.clock() < deadline do
			task.wait(0.1)
		end
		if not A.authorized then
			return
		end
		Panel.build()
	end)
end
function Panel.build()
	if not A.authorized then
		return
	end
	local gui = new("ScreenGui", {
		Name = "DeveloperConsole",
		ResetOnSpawn = false,
		DisplayOrder = 100,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	}, Players.LocalPlayer.PlayerGui)
	local root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false }, gui)
	local launcher = button(root, "DEV TUNING · F6", UDim2.fromOffset(136, 44), UDim2.new(1, -148, 0, 52))
	launcher.Name = "Toggle"
	local window = new("Frame", {
		Name = "Window",
		Size = UDim2.fromOffset(398, 580),
		Position = UDim2.new(1, -410, 0, 102),
		BackgroundColor3 = Color3.fromRGB(14, 25, 36),
		Visible = false,
		Active = true,
		ClipsDescendants = true,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, window)
	new("UIStroke", { Color = accent, Thickness = 1, Transparency = 0.3 }, window)
	local header =
		button(window, "DEVELOPER CONSOLE   /   AIM ASSIST", UDim2.new(1, -56, 0, 46), UDim2.fromOffset(0, 0))
	header.BackgroundTransparency = 1
	header.TextXAlignment = Enum.TextXAlignment.Left
	new("UIPadding", { PaddingLeft = UDim.new(0, 14) }, header)
	local close = button(window, "×", UDim2.fromOffset(44, 44), UDim2.new(1, -48, 0, 2))
	local status = text(
		window,
		"Private server · live config #0 · NOT SAVED",
		UDim2.new(1, -28, 0, 38),
		UDim2.fromOffset(14, 46)
	)
	status.TextWrapped = true
	status.TextSize = 12
	status.TextColor3 = accent
	local scroll = new("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 88),
		Size = UDim2.new(1, -24, 1, -204),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, window)
	local layout = new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	local slot = "default"
	local loadedRevisions = {}
	local savedValues = {}
	local armed = false
	local operation = false
	local release: (() -> ())? = nil
	local pending = {}
	local flushing = false
	local lastSend = 0
	local rows = {}
	local activeSlider: any = nil
	local activeFinger: InputObject? = nil
	local dragging: any = nil
	local note = text(
		window,
		"Live changes affect this private server. Load a slot before Save.",
		UDim2.new(1, -28, 0, 36),
		UDim2.new(0, 14, 1, -112)
	)
	note.TextWrapped = true
	note.TextSize = 11
	note.TextColor3 = muted
	local profile = button(window, "SLOT: DEFAULT", UDim2.new(0.34, -10, 0, 44), UDim2.new(0, 12, 1, -72))
	local load = button(window, "LOAD", UDim2.new(0.22, -8, 0, 44), UDim2.new(0.34, 2, 1, -72))
	local save = button(window, "SAVE…", UDim2.new(0.22, -8, 0, 44), UDim2.new(0.56, 2, 1, -72))
	local export = button(window, "JSON", UDim2.new(0.22, -8, 0, 44), UDim2.new(0.78, 2, 1, -72))
	local footer = text(
		window,
		"DEVELOPMENT ONLY  ·  no production promotion",
		UDim2.new(1, -28, 0, 20),
		UDim2.new(0, 14, 1, -25)
	)
	footer.TextColor3 = muted
	footer.TextSize = 10
	local exportBox = new("TextBox", {
		Name = "JSONExport",
		Size = UDim2.new(1, -24, 1, -104),
		Position = UDim2.fromOffset(12, 88),
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(9, 18, 27),
		TextColor3 = ink,
		Font = Enum.Font.Code,
		TextSize = 13,
		MultiLine = true,
		TextWrapped = true,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, window)
	local function refresh()
		local saved = savedValues[slot]
		status.Text = `Private server · live #{A.revision} · {if saved and Config.equal(saved, A.values)
			then "MATCHES SAVED"
			else "UNSAVED / NO SAVED BASELINE"}`
		for key, row in rows do
			local value = A.values[key]
			if row.field.min then
				row.value.Text = string.format("%.2f", value)
				row.fill.Size = UDim2.fromScale((value - row.field.min) / (row.field.max - row.field.min), 1)
			else
				row.toggle.Text = if value then "ON" else "OFF"
				row.toggle.TextColor3 = if value then accent else muted
			end
		end
	end
	local function request(action: string, payload: any): any
		local ok, response = pcall(function()
			return A.request:InvokeServer(action, payload)
		end)
		if not ok or type(response) ~= "table" then
			note.Text = "Request failed; current session retained"
			return nil
		end
		if response.state then
			A.accept(response.state)
		end
		note.Text = response.message or (if response.ok then "Ready" else "Request rejected")
		if response.ok and response.slot then
			loadedRevisions[response.slot] = response.savedRevision
			savedValues[response.slot] = response.savedValues
		end
		refresh()
		return response
	end
	local function queue(key: string, value: any)
		pending[key] = value
		armed = false
		save.Text = "SAVE…"
		if flushing then
			return
		end
		flushing = true
		task.spawn(function()
			while next(pending) do
				task.wait(math.max(0.12 - (os.clock() - lastSend), 0))
				local values = table.clone(A.values)
				for k, v in pending do
					values[k] = v
				end
				table.clear(pending)
				lastSend = os.clock()
				request("Apply", { values = values, revision = A.revision })
			end
			flushing = false
		end)
	end
	local function section(title: string, order: number): Frame
		local group = new("Frame", {
			Name = title,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = order,
		}, scroll)
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, group)
		local toggle = button(group, "−  " .. title, UDim2.new(1, 0, 0, 44), UDim2.new())
		toggle.LayoutOrder = 0
		local open = true
		toggle.Activated:Connect(function()
			open = not open
			toggle.Text = (if open then "−  " else "+  ") .. title
			for _, child in group:GetChildren() do
				if child:IsA("Frame") then
					child.Visible = open
				end
			end
		end)
		return group
	end
	local groups =
		{ section("ASSIST RESPONSE", 1), section("TARGET ACQUISITION", 2), section("TOOLS & DIAGNOSTICS", 3) }
	for i, field in Config.Fields do
		local row = new(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, if field.min then 76 else 48), BackgroundTransparency = 1, LayoutOrder = i },
			groups[if i <= 5 then 1 else 2]
		)
		text(row, field.label, UDim2.new(1, -80, 0, 28), UDim2.fromOffset(2, 0))
		if field.min then
			local value = text(row, "", UDim2.fromOffset(64, 28), UDim2.new(1, -66, 0, 0))
			value.TextXAlignment = Enum.TextXAlignment.Right
			value.TextColor3 = accent
			local slider = button(row, "", UDim2.new(1, -8, 0, 44), UDim2.fromOffset(4, 28))
			slider.BackgroundTransparency = 0.4
			local track = new("Frame", {
				Size = UDim2.new(1, -14, 0, 4),
				Position = UDim2.new(0, 7, 0.5, -2),
				BackgroundColor3 = Color3.fromRGB(70, 92, 110),
			}, slider)
			local fill =
				new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = accent, BorderSizePixel = 0 }, track)
			local function move(x: number)
				local ratio = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
				local n = math.clamp(
					math.floor((field.min + ratio * (field.max - field.min)) / field.step + 0.5) * field.step,
					field.min,
					field.max
				)
				queue(field.key, n)
				value.Text = string.format("%.2f", n)
				fill.Size = UDim2.fromScale(ratio, 1)
			end
			slider.InputBegan:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					activeSlider = move
					activeFinger = input
					move(input.Position.X)
				end
			end)
			rows[field.key] = { field = field, value = value, fill = fill }
		else
			local toggle = button(row, "", UDim2.fromOffset(68, 44), UDim2.new(1, -70, 0, 0))
			toggle.Activated:Connect(function()
				queue(field.key, not A.values[field.key])
			end)
			rows[field.key] = { field = field, toggle = toggle }
		end
	end
	local reset = button(groups[3], "RESET LIVE TO DEFAULTS (does not save)", UDim2.new(1, 0, 0, 44), UDim2.new())
	reset.LayoutOrder = 1
	reset.Activated:Connect(function()
		if not flushing and not operation then
			task.spawn(function()
				request("Reset", { revision = A.revision })
			end)
		end
	end)
	local diag = button(groups[3], "DIAGNOSTICS: OFF", UDim2.new(1, 0, 0, 44), UDim2.new())
	diag.LayoutOrder = 2
	diag.Activated:Connect(function()
		A.diagnostics = not A.diagnostics
		diag.Text = "DIAGNOSTICS: " .. (if A.diagnostics then "ON" else "OFF")
	end)
	local help = text(
		groups[3],
		"Radius = fraction of shorter screen edge. Solid walls ALWAYS block assistance. JSON opens selectable export; close/reopen panel to return.",
		UDim2.new(1, -4, 0, 76),
		UDim2.new()
	)
	help.TextWrapped = true
	help.TextColor3 = muted
	help.TextSize = 12
	help.LayoutOrder = 3
	local function show(on: boolean)
		window.Visible = on
		Input.tuningOpen = on
		Input.releaseAll()
		Camera.clearTouchLook()
		A.clear()
		activeSlider = nil
		activeFinger = nil
		dragging = nil
		if on then
			if not release then
				release = Camera.requestCursor()
			end
			exportBox.Visible = false
			scroll.Visible = true
		elseif release then
			release()
			release = nil
			exportBox:ReleaseFocus()
		end
	end
	Panel.setOpen = show
	launcher.Activated:Connect(function()
		show(not window.Visible)
	end)
	close.Activated:Connect(function()
		show(false)
	end)
	UIS.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.F6 and not processed then
			show(not window.Visible)
		end
	end)
	header.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = {
				input = input,
				start = Vector2.new(input.Position.X, input.Position.Y),
				origin = window.AbsolutePosition - root.AbsolutePosition,
			}
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if
			activeSlider
			and (
				input == activeFinger
				or (
					activeFinger
					and activeFinger.UserInputType == Enum.UserInputType.MouseButton1
					and input.UserInputType == Enum.UserInputType.MouseMovement
				)
			)
		then
			activeSlider(input.Position.X)
		end
		if
			dragging
			and (
				input == dragging.input
				or (
					dragging.input.UserInputType == Enum.UserInputType.MouseButton1
					and input.UserInputType == Enum.UserInputType.MouseMovement
				)
			)
		then
			local pos = dragging.origin + Vector2.new(input.Position.X, input.Position.Y) - dragging.start
			window.Position = UDim2.fromOffset(
				math.clamp(pos.X, 0, math.max(0, root.AbsoluteSize.X - window.AbsoluteSize.X)),
				math.clamp(pos.Y, 0, math.max(0, root.AbsoluteSize.Y - window.AbsoluteSize.Y))
			)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input == activeFinger then
			activeSlider = nil
			activeFinger = nil
		end
		if dragging and input == dragging.input then
			dragging = nil
		end
	end)
	UIS.WindowFocusReleased:Connect(function()
		activeSlider = nil
		activeFinger = nil
		dragging = nil
	end)
	profile.Activated:Connect(function()
		if operation or flushing then
			return
		end
		local index = table.find(Config.Slots, slot) or 1
		slot = Config.Slots[index % #Config.Slots + 1]
		profile.Text = "SLOT: " .. string.upper(slot)
		armed = false
		save.Text = "SAVE…"
		refresh()
	end)
	load.Activated:Connect(function()
		if operation or flushing then
			return
		end
		operation = true
		armed = false
		save.Text = "SAVE…"
		task.spawn(function()
			request("Load", { slot = slot, revision = A.revision })
			operation = false
		end)
	end)
	save.Activated:Connect(function()
		if operation or flushing then
			return
		end
		if loadedRevisions[slot] == nil then
			note.Text = "Click LOAD first to check this slot; current values stay if it is empty"
			return
		end
		if not armed then
			armed = true
			save.Text = "CONFIRM"
			note.Text = "Click CONFIRM to save over the loaded slot revision"
			return
		end
		armed = false
		save.Text = "SAVE…"
		operation = true
		task.spawn(function()
			request("Save", { slot = slot, savedRevision = loadedRevisions[slot] })
			operation = false
		end)
	end)
	export.Activated:Connect(function()
		if operation or flushing then
			return
		end
		task.spawn(function()
			local response = request("Export", {})
			if response and response.ok then
				A.diagnostics = false
				exportBox.Text = response.json
				scroll.Visible = false
				exportBox.Visible = true
				note.Text = "Select/copy this JSON. Closing/reopening returns to controls."
				exportBox:CaptureFocus()
			end
		end)
	end)
	local function fit()
		local w, h = root.AbsoluteSize.X, root.AbsoluteSize.Y
		window.Size = UDim2.fromOffset(math.min(398, math.max(240, w - 16)), math.min(580, math.max(220, h - 16)))
		window.Position = UDim2.fromOffset(
			math.max(8, w - window.AbsoluteSize.X - 12),
			math.min(102, math.max(8, h - window.AbsoluteSize.Y - 8))
		)
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	refresh()
	A.changed.Event:Connect(refresh)
	local overlay = new(
		"ScreenGui",
		{ Name = "AimAssistDiagnostics", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 90 },
		Players.LocalPlayer.PlayerGui
	)
	local circle = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
	}, overlay)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, circle)
	new("UIStroke", { Color = accent, Thickness = 1, Transparency = 0.4 }, circle)
	local marker = new("Frame", {
		Size = UDim2.fromOffset(12, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
	}, overlay)
	new("UIStroke", { Color = accent, Thickness = 2 }, marker)
	local info = text(overlay, "", UDim2.new(1, -24, 0, 76), UDim2.fromOffset(12, 104))
	info.TextColor3 = accent
	info.TextSize = 12
	info.TextYAlignment = Enum.TextYAlignment.Top
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		local enabled = A.diagnostics and not window.Visible and Camera.mode == "Combat" and not Camera.cursorVisible()
		circle.Visible = enabled
		info.Visible = enabled
		marker.Visible = false
		if not enabled then
			return
		end
		local viewport = workspace.CurrentCamera.ViewportSize
		local diameter = math.min(viewport.X, viewport.Y) * A.values.radius * 2
		circle.Size = UDim2.fromOffset(diameter, diameter)
		if A.targetPosition then
			local p, visible = workspace.CurrentCamera:WorldToViewportPoint(A.targetPosition)
			marker.Visible = visible
			marker.Position = UDim2.fromOffset(p.X, p.Y)
		end
		local s = A.stats
		info.Text = string.format(
			"AIM ASSIST · %s · %.1f studs\nSlowdown %s (%.2fx sensitivity) · rotation %s · effective %.2f\nScans %d · rays %d · max acquisition %.3fms · mouse excluded",
			s.target,
			s.distance,
			if s.slowdown < 0.999 then "ACTIVE" else "idle",
			s.slowdown,
			if s.rotation then "ACTIVE" else "idle",
			A.values.rotationStrength * s.weight,
			s.scans,
			s.rays,
			s.maxScanMs
		)
	end)
end
return Panel
