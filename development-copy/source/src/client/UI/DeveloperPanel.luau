--!strict
-- Shared, metadata-driven console shell. Existing camera/input fences and aim diagnostics are retained.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.DeveloperConsole.Config)
local Catalog = require(RS.Shared.DeveloperConsole.AudioCatalog)
local Layout = require(RS.Shared.DeveloperConsole.Layout)
local A = require(script.Parent.Parent.Controllers.AimAssistController)
local C = require(script.Parent.Parent.Controllers.DeveloperConsoleController)
local Camera = require(script.Parent.Parent.Controllers.CameraController)
local Input = require(script.Parent.Parent.Controllers.InputController)
local Audio = require(script.Parent.Parent.Controllers.AudioController)
local Weapon = require(script.Parent.Parent.Controllers.WeaponController)
local Panel = { category = "movement" }
local ink = Color3.fromRGB(237, 245, 255)
local muted = Color3.fromRGB(151, 173, 193)
local accent = Color3.fromRGB(50, 221, 208)
local amber = Color3.fromRGB(255, 199, 104)
local function new(class: string, props: any, parent: Instance?): any
	local item = Instance.new(class)
	for k, v in props do
		item[k] = v
	end
	item.Parent = parent
	return item
end
local function label(parent: Instance, value: string, size: UDim2, pos: UDim2, fontSize: number?): TextLabel
	return new("TextLabel", {
		Text = value,
		Size = size,
		Position = pos,
		BackgroundTransparency = 1,
		TextColor3 = ink,
		Font = Enum.Font.GothamMedium,
		TextSize = fontSize or 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, parent)
end
local function round(item: Instance, r: number?)
	new("UICorner", { CornerRadius = UDim.new(0, r or 7) }, item)
end
local function button(parent: Instance, value: string, size: UDim2, pos: UDim2): TextButton
	local b = new("TextButton", {
		Text = value,
		Size = size,
		Position = pos,
		BackgroundColor3 = Color3.fromRGB(33, 52, 68),
		TextColor3 = ink,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = true,
		Active = true,
	}, parent)
	round(b)
	return b
end
local function textbox(parent: Instance, value: string, size: UDim2, pos: UDim2): TextBox
	local b = new("TextBox", {
		Text = value,
		Size = size,
		Position = pos,
		BackgroundColor3 = Color3.fromRGB(15, 26, 37),
		TextColor3 = ink,
		Font = Enum.Font.Code,
		TextSize = 13,
		ClearTextOnFocus = false,
		TextWrapped = false,
	}, parent)
	round(b)
	return b
end
local titles =
	{ movement = "Movement", aiming = "Aiming", autoFire = "Auto Fire", weapons = "Weapons", audio = "Audio" }
local summaries = {
	movement = "SERVER SESSION  /  Live Humanoid tuning. Unsupported mechanics stay unavailable.",
	aiming = "CLIENT PRESENTATION  /  Existing assist response; separate device eligibility and sensitivity.",
	autoFire = "VALIDATED INPUT  /  Instant touch acquisition. Optional Auto Swap Weapons; normal reloads and server shot gates.",
	weapons = "SERVER SESSION  /  Pump Shotgun - both slots. Changes wait for reload / raise boundaries.",
	audio = "CLIENT MIX  /  Developer gains multiply personal volume preferences. No asset changes.",
}
function Panel.start()
	if game.GameId ~= 10772492892 or game.PlaceId ~= 139437092998076 then
		return
	end
	task.spawn(function()
		local deadline = os.clock() + 20
		while not A.authorized and os.clock() < deadline do
			task.wait(0.1)
		end
		if A.authorized then
			Panel.build()
		end
	end)
end
function Panel.build()
	if not A.authorized or Panel.gui then
		return
	end
	local gui = new("ScreenGui", {
		Name = "DeveloperConsole",
		ResetOnSpawn = false,
		DisplayOrder = 100,
		ScreenInsets = if UIS.TouchEnabled
			then Enum.ScreenInsets.CoreUISafeInsets
			else Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer.PlayerGui)
	Panel.gui = gui
	local root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false }, gui)
	local launcher = button(
		root,
		if UIS.TouchEnabled then "DEV" else "DEV CONSOLE · F6",
		UDim2.fromOffset(if UIS.TouchEnabled then 64 else 152, 44),
		UDim2.new(1, if UIS.TouchEnabled then -76 else -164, 0, if UIS.TouchEnabled then 0 else 48)
	)
	launcher.Name = "Toggle"
	if UIS.TouchEnabled then
		-- Follow the existing ammo HUD without moving any gameplay controls.
		task.spawn(function()
			local hud = Players.LocalPlayer.PlayerGui:WaitForChild("MobileHud")
			local ammo = hud:WaitForChild("MobileHud"):WaitForChild("Weapons") :: Frame
			local function placeLauncher()
				local origin = ammo.AbsolutePosition - root.AbsolutePosition
				launcher.Position = UDim2.fromOffset(
					math.max(0, origin.X - launcher.AbsoluteSize.X - 8),
					math.max(0, origin.Y + ammo.AbsoluteSize.Y - launcher.AbsoluteSize.Y)
				)
			end
			ammo:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeLauncher)
			ammo:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeLauncher)
			root:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeLauncher)
			placeLauncher()
		end)
	end
	local window = new("Frame", {
		Name = "Window",
		Size = UDim2.fromOffset(740, 700),
		Position = UDim2.new(1, -760, 0, 80),
		BackgroundColor3 = Color3.fromRGB(12, 21, 30),
		Visible = false,
		Active = true,
	}, root)
	round(window, 12)
	new("UIStroke", { Color = Color3.fromRGB(51, 88, 104), Thickness = 1 }, window)
	local header = button(window, "", UDim2.new(1, -56, 0, 46), UDim2.fromOffset(0, 0))
	header.BackgroundTransparency = 1
	label(header, "DOUBLE PUMP  /  DEVELOPER CONSOLE", UDim2.new(1, -195, 1, 0), UDim2.fromOffset(16, 0), 14).Font =
		Enum.Font.GothamBold
	local shortcut = button(header, "F6", UDim2.fromOffset(44, 44), UDim2.new(1, -174, 0, 1))
	local diagnostics = button(header, "DIAGNOSTICS", UDim2.fromOffset(112, 44), UDim2.new(1, -122, 0, 1))
	local close = button(window, "X", UDim2.fromOffset(44, 44), UDim2.new(1, -50, 0, 1))
	local tabs = new("Frame", {
		Name = "Navigation",
		Size = UDim2.new(1, -24, 0, 44),
		Position = UDim2.fromOffset(12, 48),
		BackgroundTransparency = 1,
	}, window)
	local tabButtons = {}
	for i, cat in Config.Categories do
		local b = button(tabs, titles[cat], UDim2.new(0.2, -5, 1, 0), UDim2.new((i - 1) * 0.2, 2, 0, 0))
		b.Name = cat
		tabButtons[cat] = b
		b.Activated:Connect(function()
			Panel.select(cat)
		end)
	end
	local summary = label(window, "", UDim2.new(1, -32, 0, 36), UDim2.fromOffset(16, 92), 11)
	summary.TextColor3 = muted
	local scroll = new("ScrollingFrame", {
		Name = "Settings",
		Size = UDim2.new(1, -24, 1, -274),
		Position = UDim2.fromOffset(12, 132),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, window)
	new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, scroll)
	local footer = new(
		"Frame",
		{ Size = UDim2.new(1, -24, 0, 132), Position = UDim2.new(0, 12, 1, -138), BackgroundTransparency = 1 },
		window
	)
	local preset = textbox(footer, "default", UDim2.new(0.38, -6, 0, 44), UDim2.fromOffset(0, 0))
	preset.PlaceholderText = "preset-name"
	preset.Name = "PresetName"
	local scope = "all"
	local scopeButton = button(footer, "SCOPE: ALL", UDim2.new(0.32, -6, 0, 44), UDim2.new(0.38, 2, 0, 0))
	local compare = button(footer, "COMPARE", UDim2.new(0.30, -4, 0, 44), UDim2.new(0.70, 4, 0, 0))
	local actions = {}
	for i, name in { "LOAD", "SAVE", "RESET", "EXPORT", "HIDE" } do
		actions[name] = button(footer, name, UDim2.new(0.2, -5, 0, 44), UDim2.new((i - 1) * 0.2, 0, 0, 50))
	end
	local status = label(
		footer,
		"ACTIVE: DEFAULTS  ·  No saved baseline loaded",
		UDim2.new(1, 0, 0, 30),
		UDim2.fromOffset(0, 100),
		11
	)
	status.TextColor3 = accent
	local toolsOpen = false
	local toolsButton = button(window, "PRESETS / SAVE / EXPORT", UDim2.new(1, -24, 0, 44), UDim2.new(0, 12, 1, -50))
	toolsButton.Name = "MobileActions"
	toolsButton.Visible = false
	local function toolsLayout()
		local compact = window.AbsoluteSize.Y < 560
		toolsButton.Visible = compact
		footer.Visible = not compact or toolsOpen
		footer.Position = if compact then UDim2.fromOffset(12, 100) else UDim2.new(0, 12, 1, -138)
		scroll.Visible = not compact or not toolsOpen
		summary.Visible = not compact
		scroll.Position = UDim2.fromOffset(12, if compact then 100 else 132)
		scroll.Size = UDim2.new(1, -24, 1, if compact then -158 else -274)
		toolsButton.Text = if toolsOpen then "BACK TO SETTINGS" else "PRESETS / SAVE / EXPORT"
	end
	toolsButton.Activated:Connect(function()
		toolsOpen = not toolsOpen
		toolsLayout()
	end)
	local overlay = new("Frame", {
		Name = "ExportCompare",
		Size = UDim2.new(1, -24, 1, -142),
		Position = UDim2.fromOffset(12, 132),
		BackgroundColor3 = Color3.fromRGB(12, 21, 30),
		Visible = false,
		ZIndex = 10,
	}, window)
	local exportClose = button(overlay, "BACK TO SETTINGS", UDim2.new(1, 0, 0, 38), UDim2.fromOffset(0, 0))
	exportClose.ZIndex = 11
	local exportBox = textbox(overlay, "", UDim2.new(1, 0, 1, -46), UDim2.fromOffset(0, 44))
	exportBox.MultiLine = true
	exportBox.TextWrapped = true
	exportBox.TextXAlignment = Enum.TextXAlignment.Left
	exportBox.TextYAlignment = Enum.TextYAlignment.Top
	exportBox.TextSize = 12
	exportBox.ZIndex = 11
	exportClose.Activated:Connect(function()
		overlay.Visible = false
		exportBox:ReleaseFocus()
	end)
	local saved: { [string]: any } = {}
	local savedRevisions: { [string]: number } = {}
	local message = ""
	local confirmAction: string? = nil
	local confirmUntil = 0
	local busy = false
	local pending: any = nil
	local pendingEdits = {}
	local editDeadline = 0
	local currentSlider: any = nil
	local drag: any = nil
	local releaseCursor: any = nil
	local rowRefresh = {}
	local audioFilter = "Mixer"
	local expanded: { [string]: boolean } = {}
	local function slot(): string
		return scope .. ":" .. preset.Text
	end
	local function dirty(): boolean
		return pending ~= nil or not Config.equal(C.values, saved[slot()], scope)
	end
	local function statusText()
		local defaults = Config.equal(C.values, Config.defaults(), scope)
		local base = if savedRevisions[slot()] ~= nil
			then (if Config.equal(C.values, saved[slot()], scope) then "MATCHES SAVED" else "UNSAVED CHANGES")
			else (if defaults then "NO SAVED BASELINE" else "UNSAVED CHANGES / NO BASELINE")
		local deferred = not Config.equal({ weapons = C.values.weapons }, { weapons = C.weaponValues }, "weapons")
		status.Text = (if defaults then "DEFAULTS" else "CUSTOM")
			.. " · "
			.. base
			.. (if pending then " · APPLYING" elseif deferred then " · WEAPONS PENDING" else "")
			.. (if message ~= "" then "  |  " .. message else "")
		if toolsButton.Visible and not toolsOpen then
			toolsButton.Text = "PRESETS / SAVE / EXPORT  ·  " .. (if defaults then "DEFAULTS" else "UNSAVED")
		end
	end
	local function response(action: string, payload: any, callback: any?)
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local result = C.request(action, payload)
			message = result.message or (if result.ok then "Done" else "Request failed")
			if result.ok and callback then
				callback(result)
			end
			busy = false
			statusText()
		end)
	end
	local function edit(field: any, value: any)
		if (pending or C.values)[field.category][field.key] == value then
			return
		end
		if not Config.value(field, value) then
			message = "Value outside permitted range"
			statusText()
			return
		end
		pending = pending or Config.copy(C.values)
		pending[field.category][field.key] = value
		pendingEdits[field.category .. "." .. field.key] = { field = field, value = value }
		editDeadline = os.clock() + 0.14
		message = ""
		for _, fn in rowRefresh do
			fn()
		end
		statusText()
	end
	local function current(field: any): any
		return (pending or C.values)[field.category][field.key]
	end
	local function ensureConfirm(action: string): boolean
		if confirmAction == action and os.clock() < confirmUntil then
			confirmAction = nil
			return true
		end
		confirmAction = action
		confirmUntil = os.clock() + 5
		message = "Press " .. action .. " again to confirm; active values are preserved until then"
		statusText()
		return false
	end
	local function groupHeader(title: string, subtitle: string?)
		local frame = new("Frame", {
			Size = UDim2.new(1, 0, 0, if subtitle then 58 else 38),
			BackgroundColor3 = Color3.fromRGB(22, 37, 49),
			BorderSizePixel = 0,
		}, scroll)
		round(frame)
		label(frame, title, UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 2), 13).TextColor3 = accent
		if subtitle then
			label(frame, subtitle, UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 30), 10).TextColor3 = muted
		end
		return frame
	end
	local function row(field: any)
		local frame = new("Frame", {
			Name = field.category .. "_" .. field.key,
			Size = UDim2.new(1, 0, 0, if field.available then (if UIS.TouchEnabled then 102 else 110) else 64),
			BackgroundColor3 = Color3.fromRGB(21, 34, 46),
			BorderSizePixel = 0,
		}, scroll)
		round(frame)
		local title = label(frame, field.label, UDim2.new(1, -148, 0, 28), UDim2.fromOffset(12, 5), 13)
		local description = label(
			frame,
			field.description .. (if field.unit ~= "" then "  [" .. field.unit .. "]" else ""),
			UDim2.new(1, -160, 0, 28),
			UDim2.fromOffset(12, 34),
			10
		)
		description.TextColor3 = muted
		if not field.available then
			title.TextColor3 = muted
			label(frame, "UNAVAILABLE", UDim2.fromOffset(108, 30), UDim2.new(1, -120, 0, 5), 10).TextColor3 = amber
			return
		end
		local reset = button(frame, "RESET", UDim2.fromOffset(52, 44), UDim2.new(1, -62, 0, 5))
		reset.TextSize = 9
		reset.Activated:Connect(function()
			edit(field, field.default)
		end)
		if field.type == "boolean" then
			local b =
				button(frame, "", UDim2.fromOffset(82, 44), UDim2.new(1, -96, 0, if UIS.TouchEnabled then 54 else 62))
			local function refresh()
				local v = current(field)
				b.Text = if v then "ON" else "OFF"
				b.BackgroundColor3 = if v then Color3.fromRGB(23, 100, 93) else Color3.fromRGB(49, 60, 72)
			end
			table.insert(rowRefresh, refresh)
			refresh()
			b.Activated:Connect(function()
				edit(field, not current(field))
			end)
		elseif field.type == "enum" then
			local b = button(frame, tostring(current(field)), UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, 62))
			local choices = new("Frame", {
				Size = UDim2.new(1, -24, 0, #field.options * 46),
				Position = UDim2.fromOffset(12, 112),
				BackgroundTransparency = 1,
				Visible = false,
			}, frame)
			for i, option in field.options do
				local choice = button(choices, option, UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, (i - 1) * 46))
				choice.Activated:Connect(function()
					edit(field, option)
					choices.Visible = false
					frame.Size = UDim2.new(1, 0, 0, 110)
					b.Text = option .. "  v"
				end)
			end
			b.Activated:Connect(function()
				choices.Visible = not choices.Visible
				frame.Size = UDim2.new(1, 0, 0, if choices.Visible then 116 + #field.options * 46 else 110)
			end)
			table.insert(rowRefresh, function()
				b.Text = tostring(current(field)) .. "  v"
			end)
		else
			local value = textbox(frame, tostring(current(field)), UDim2.fromOffset(78, 44), UDim2.new(1, -146, 0, 5))
			value.TextSize = 12
			local hit =
				button(frame, "", UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, if UIS.TouchEnabled then 54 else 62))
			hit.BackgroundTransparency = 1
			local track = new("Frame", {
				Size = UDim2.new(1, 0, 0, 5),
				Position = UDim2.new(0, 0, 0.5, -2),
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.fromRGB(55, 74, 89),
			}, hit)
			round(track)
			local fill =
				new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = accent, BorderSizePixel = 0 }, track)
			round(fill)
			local knob = new("Frame", {
				Size = UDim2.fromOffset(16, 16),
				Position = UDim2.new(0, -8, 0.5, -8),
				BackgroundColor3 = ink,
				BorderSizePixel = 0,
			}, track)
			round(knob, 8)
			local function refresh()
				local v = current(field)
				if not value:IsFocused() then
					value.Text = string.format("%.3g", v)
				end
				local fraction = (v - field.min) / (field.max - field.min)
				fill.Size = UDim2.fromScale(fraction, 1)
				knob.Position = UDim2.new(fraction, -8, 0.5, -8)
			end
			local function move(x: number)
				local a = math.clamp((x - hit.AbsolutePosition.X) / math.max(1, hit.AbsoluteSize.X), 0, 1)
				local v = field.min + (field.max - field.min) * a
				v = math.clamp(math.round(v / field.step) * field.step, field.min, field.max)
				edit(field, v)
				refresh()
			end
			value.FocusLost:Connect(function()
				local v = tonumber(value.Text)
				if v then
					edit(field, v)
				end
				refresh()
			end)
			hit.InputBegan:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					currentSlider = { input = input, move = move }
					scroll.ScrollingEnabled = false
					move(input.Position.X)
				end
			end)
			table.insert(rowRefresh, refresh)
			refresh()
		end
	end
	local function rebuild()
		currentSlider = nil
		scroll.ScrollingEnabled = true
		rowRefresh = {}
		for _, item in scroll:GetChildren() do
			if item:IsA("GuiObject") then
				item:Destroy()
			end
		end
		summary.Text = summaries[Panel.category]
		for cat, b in tabButtons do
			b.BackgroundColor3 = if cat == Panel.category
				then Color3.fromRGB(25, 102, 94)
				else Color3.fromRGB(33, 52, 68)
		end
		if Panel.category == "weapons" then
			groupHeader(
				"PUMP SHOTGUN  /  Pump A + Pump B",
				"One weapon definition, independent ammo and cooldowns. Global shot interval stays 0.4s."
			)
		end
		local function legacySection()
			local legacy = groupHeader(
				"EXISTING AIM RESPONSE  /  Legacy profile import",
				"Read-only migration from previous aim-only saves. Saves now use schema2 presets."
			)
			legacy.Size = UDim2.new(1, 0, 0, 100)
			for i, name in { "default", "touch", "controller" } do
				local b = button(
					legacy,
					"IMPORT " .. name:upper(),
					UDim2.new(1 / 3, -8, 0, 34),
					UDim2.new((i - 1) / 3, 5, 0, 60)
				)
				b.TextSize = 10
				b.Activated:Connect(function()
					if pending then
						message = "Wait for active edits to apply"
						statusText()
						return
					end
					if ensureConfirm("IMPORT") then
						response("LegacyLoad", { slot = name })
					end
				end)
			end
		end
		if Panel.category == "audio" then
			local bar = groupHeader(
				"HIERARCHICAL AUDIO MIXER",
				"51 approved cues + native character sounds. Personal volume remains separate; no music asset."
			)
			bar.Size = UDim2.new(1, 0, 0, if UIS.TouchEnabled then 48 else 106)
			if UIS.TouchEnabled then
				for _, child in bar:GetChildren() do
					if child:IsA("TextLabel") then
						child.Visible = false
					end
				end
			end
			local filter = button(
				bar,
				"VIEW: " .. audioFilter,
				UDim2.new(0.6, -12, 0, 44),
				UDim2.fromOffset(8, if UIS.TouchEnabled then 2 else 60)
			)
			local audioSnapshot = button(
				bar,
				"PLAYING SOUNDS",
				UDim2.new(0.4, -12, 0, 44),
				UDim2.new(0.6, 4, 0, if UIS.TouchEnabled then 2 else 60)
			)
			audioSnapshot.Activated:Connect(function()
				local lines = {
					"CURRENT AUDIO SNAPSHOT (reopen to refresh)",
					"Source / bus / raw level / effective level / state / same-cue count",
					"",
				}
				for _, entry in Audio.diagnostics() do
					table.insert(
						lines,
						string.format(
							"%s | %s | %.3f / %.3f | %s | %dx | %s\n%s",
							entry.name,
							entry.group,
							entry.volume,
							entry.effective,
							entry.state,
							entry.simultaneous,
							entry.source,
							entry.assetId
						)
					)
				end
				exportBox.Text = table.concat(lines, "\n")
				overlay.Visible = true
			end)
			filter.Activated:Connect(function()
				local options = {
					"Mixer",
					"Gunshots",
					"Reload",
					"Switching",
					"Impacts",
					"Handling",
					"Footsteps",
					"Landing",
					"Jumping",
					"OtherMovement",
					"Ambience",
					"Interface",
				}
				audioFilter = options[(table.find(options, audioFilter) or 1) % #options + 1]
				rebuild()
			end)
			if audioFilter == "Mixer" then
				for _, field in Config.Fields do
					if field.category == "audio" and field.key:sub(1, 4) == "bus_" then
						row(field)
					end
				end
			else
				for _, entry in Catalog.Sounds do
					if entry.group == audioFilter then
						local box = groupHeader(
							entry.name .. "  /  " .. entry.group,
							(if entry.engineName then entry.id else "rbxassetid://" .. entry.id)
								.. "  ·  "
								.. (if entry.loop then "LOOP" else "ONE SHOT")
						)
						box.Size = UDim2.new(1, 0, 0, 100)
						local preview = button(box, "PREVIEW", UDim2.new(0.5, -12, 0, 34), UDim2.fromOffset(8, 60))
						preview.Activated:Connect(function()
							if Panel.preview then
								Audio.stop(Panel.preview)
							end
							Panel.preview = Audio.play(entry.name)
						end)
						local expand = button(
							box,
							if expanded[entry.name] then "COLLAPSE" else "LEVEL / DETAILS",
							UDim2.new(0.5, -12, 0, 34),
							UDim2.new(0.5, 4, 0, 60)
						)
						expand.Activated:Connect(function()
							expanded[entry.name] = not expanded[entry.name]
							rebuild()
						end)
						if expanded[entry.name] then
							for _, field in Config.Fields do
								if
									field.category == "audio"
									and field.key:sub(1, #entry.name + 1) == entry.name .. "_"
								then
									row(field)
								end
							end
						end
					end
				end
			end
		else
			for _, field in Config.Fields do
				if field.category == Panel.category then
					row(field)
				end
			end
		end
		if Panel.category == "aiming" then
			legacySection()
		end
		statusText()
	end
	Panel.select = function(category: string)
		if not table.find(Config.Categories, category) then
			return
		end
		Panel.category = category
		if scope ~= "all" then
			scope = category
			scopeButton.Text = "SCOPE: " .. scope:upper()
		end
		overlay.Visible = false
		exportBox:ReleaseFocus()
		scroll.CanvasPosition = Vector2.zero
		rebuild()
	end
	Panel.setOpen = function(open: boolean)
		window.Visible = open
		Input.tuningOpen = open
		Input.releaseAll()
		Camera.clearTouchLook()
		A.clear()
		currentSlider = nil
		drag = nil
		scroll.ScrollingEnabled = true
		overlay.Visible = false
		exportBox:ReleaseFocus()
		if open and not releaseCursor then
			releaseCursor = Camera.requestCursor()
		elseif not open and releaseCursor then
			releaseCursor()
			releaseCursor = nil
		end
	end
	launcher.Activated:Connect(function()
		Panel.setOpen(not window.Visible)
	end)
	close.Activated:Connect(function()
		Panel.setOpen(false)
	end)
	actions.HIDE.Activated:Connect(function()
		Panel.setOpen(false)
	end)
	shortcut.Activated:Connect(function()
		local keys = { Enum.KeyCode.F6, Enum.KeyCode.F7, Enum.KeyCode.F8 }
		C.shortcut = keys[(table.find(keys, C.shortcut) or 1) % #keys + 1]
		shortcut.Text = C.shortcut.Name
		launcher.Text = if UIS.TouchEnabled then "DEV" else "DEV CONSOLE · " .. C.shortcut.Name
	end)
	scopeButton.Activated:Connect(function()
		scope = if scope == "all" then Panel.category else "all"
		scopeButton.Text = "SCOPE: " .. scope:upper()
		message = ""
		statusText()
	end)
	preset.FocusLost:Connect(function()
		message = ""
		statusText()
	end)
	actions.LOAD.Activated:Connect(function()
		if pending then
			message = "Wait for edits to apply before loading"
			statusText()
			return
		end
		if dirty() and not ensureConfirm("LOAD") then
			return
		end
		local key = slot()
		response("Load", { name = preset.Text, scope = scope }, function(r)
			savedRevisions[key] = r.savedRevision
			saved[key] = r.savedValues
			rebuild()
		end)
	end)
	actions.SAVE.Activated:Connect(function()
		if pending then
			message = "Wait for edits to apply before saving"
			statusText()
			return
		end
		if not ensureConfirm("SAVE") then
			return
		end
		local key = slot()
		response("Save", { name = preset.Text, scope = scope, savedRevision = savedRevisions[key] }, function(r)
			savedRevisions[key] = r.savedRevision
			saved[key] = r.savedValues
		end)
	end)
	actions.RESET.Activated:Connect(function()
		if pending then
			message = "Wait for edits to apply"
			statusText()
			return
		end
		if ensureConfirm("RESET") then
			response("Reset", { scope = scope }, rebuild)
		end
	end)
	actions.EXPORT.Activated:Connect(function()
		if pending then
			message = "Wait for edits to apply"
			statusText()
			return
		end
		response("Export", { name = preset.Text }, function(r)
			exportBox.Text = r.json
			overlay.Visible = true
		end)
	end)
	compare.Activated:Connect(function()
		local lines =
			{ "ACTIVE / DEFAULT / LAST LOADED OR SAVED", "Scope: " .. scope .. "  Preset: " .. preset.Text, "" }
		local defaults = Config.defaults()
		for _, field in Config.Fields do
			if scope == "all" or scope == field.category then
				local activeValue = current(field)
				local savedValue = saved[slot()] and saved[slot()][field.category][field.key]
				if activeValue ~= field.default or savedValue ~= nil and savedValue ~= activeValue then
					table.insert(
						lines,
						field.category
							.. "."
							.. field.key
							.. ": "
							.. tostring(activeValue)
							.. " / "
							.. tostring(defaults[field.category][field.key])
							.. " / "
							.. tostring(savedValue)
					)
				end
			end
		end
		if #lines == 3 then
			table.insert(lines, "Active values match defaults; no differences in the selected scope.")
		end
		exportBox.Text = table.concat(lines, "\n")
		overlay.Visible = true
	end)
	header.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			drag = {
				input = input,
				start = Vector2.new(input.Position.X, input.Position.Y),
				position = window.AbsolutePosition - root.AbsolutePosition,
			}
		end
	end)
	UIS.InputBegan:Connect(function(input, processed)
		if input.KeyCode == C.shortcut and not processed then
			Panel.setOpen(not window.Visible)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		local mouse = input.UserInputType == Enum.UserInputType.MouseMovement
		if
			currentSlider
			and (
				input == currentSlider.input
				or mouse and currentSlider.input.UserInputType == Enum.UserInputType.MouseButton1
			)
		then
			currentSlider.move(input.Position.X)
		end
		if drag and (input == drag.input or mouse and drag.input.UserInputType == Enum.UserInputType.MouseButton1) then
			local pos = drag.position + Vector2.new(input.Position.X, input.Position.Y) - drag.start
			window.Position = UDim2.fromOffset(
				math.clamp(pos.X, 0, math.max(0, root.AbsoluteSize.X - window.AbsoluteSize.X)),
				math.clamp(pos.Y, 0, math.max(0, root.AbsoluteSize.Y - window.AbsoluteSize.Y))
			)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if currentSlider and input == currentSlider.input then
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				currentSlider.move(UIS:GetMouseLocation().X)
			end
			currentSlider = nil
			scroll.ScrollingEnabled = true
			editDeadline = 0
		end
		if drag and input == drag.input then
			drag = nil
		end
	end)
	UIS.WindowFocusReleased:Connect(function()
		drag = nil
		currentSlider = nil
		scroll.ScrollingEnabled = true
	end)
	local function resize()
		local size = root.AbsoluteSize
		local layout = Layout.measure(size.X, size.Y)
		local w = layout.width
		window.Size = UDim2.fromOffset(layout.width, layout.height)
		window.Position = UDim2.fromOffset(layout.x, layout.y)
		if w < 560 or UIS.TouchEnabled then
			header.Text = ""
			header:FindFirstChildOfClass("TextLabel").Text = "DEV CONSOLE"
		else
			header:FindFirstChildOfClass("TextLabel").Text = "DOUBLE PUMP / DEVELOPER CONSOLE"
		end
		toolsLayout()
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	window:GetPropertyChangedSignal("AbsoluteSize"):Connect(toolsLayout)
	resize()
	local diag = new(
		"ScreenGui",
		{ Name = "DeveloperConsoleDiagnostics", ResetOnSpawn = false, DisplayOrder = 99, IgnoreGuiInset = true },
		Players.LocalPlayer.PlayerGui
	)
	local droot = new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false, Visible = false },
		diag
	)
	local aimCircle = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Active = false,
	}, droot)
	round(aimCircle, 999)
	new("UIStroke", { Color = accent, Thickness = 1 }, aimCircle)
	local fireCircle = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Active = false,
	}, droot)
	round(fireCircle, 999)
	new("UIStroke", { Color = amber, Thickness = 1 }, fireCircle)
	local marker = label(droot, "+", UDim2.fromOffset(22, 22), UDim2.fromOffset(0, 0), 20)
	marker.TextColor3 = accent
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	local diagnosticText = label(droot, "", UDim2.fromOffset(330, 170), UDim2.fromOffset(12, 100), 11)
	diagnosticText.BackgroundTransparency = 0.15
	diagnosticText.BackgroundColor3 = Color3.fromRGB(12, 21, 30)
	diagnosticText.TextYAlignment = Enum.TextYAlignment.Top
	round(diagnosticText)
	diagnostics.Activated:Connect(function()
		C.diagnostics = not C.diagnostics
		A.diagnostics = C.diagnostics
		diagnostics.BackgroundColor3 = if C.diagnostics then Color3.fromRGB(25, 102, 94) else Color3.fromRGB(33, 52, 68)
	end)
	local interval = 0
	RunService.Heartbeat:Connect(function(dt)
		if currentSlider and currentSlider.input.UserInputType == Enum.UserInputType.MouseButton1 then
			currentSlider.move(UIS:GetMouseLocation().X)
		end
		if pending and not busy and os.clock() >= editDeadline then
			local proposed = Config.copy(C.values)
			for _, entry in pendingEdits do
				proposed[entry.field.category][entry.field.key] = entry.value
			end
			pending = nil
			pendingEdits = {}
			response("Apply", { values = proposed }, function()
				for _, fn in rowRefresh do
					fn()
				end
			end)
		end
		interval += dt
		if interval < 0.1 then
			return
		end
		interval = 0
		statusText()
		droot.Visible = C.diagnostics and Camera.mode == "Combat" and not window.Visible and not Camera.cursorVisible()
		if not droot.Visible then
			return
		end
		local short = math.min(droot.AbsoluteSize.X, droot.AbsoluteSize.Y)
		aimCircle.Size = UDim2.fromOffset(short * A.values.radius * 2, short * A.values.radius * 2)
		fireCircle.Size = UDim2.fromOffset(short * C.values.autoFire.radius * 2, short * C.values.autoFire.radius * 2)
		marker.Visible = A.targetPosition ~= nil
		if A.targetPosition then
			local point = workspace.CurrentCamera:WorldToViewportPoint(A.targetPosition)
			marker.Position = UDim2.fromOffset(point.X, point.Y)
		end
		local s = Weapon.state
		local sounds = Audio.diagnostics()
		local audioLines = {}
		for i = 1, math.min(3, #sounds) do
			local sound = sounds[i]
			table.insert(
				audioLines,
				sound.name
					.. " ["
					.. sound.group
					.. "] "
					.. string.format("%.3f", sound.effective)
					.. " @"
					.. sound.source
					.. " "
					.. sound.state
			)
		end
		diagnosticText.Text = string.format(
			"AIM %s · %.1f studs\nSlow %.2f · rotate %s · weight %.2f\nAUTO %s · %.2fs · %s\nPUMP %s · ammo %s · reload %s · raise %.2fs\nLast hit %.0f HP / %d pellets · interval %.3fs\nHit range %.1f studs · nearest-pellet falloff %.2fx\nScans max %.3fms / %.3fms · audio %d\n%s",
			A.stats.target,
			A.stats.distance,
			A.stats.slowdown,
			tostring(A.stats.rotation),
			A.stats.weight,
			C.autoTarget or "none",
			C.auto.remaining,
			C.auto.reason,
			s.equipped,
			s.slots[s.equipped].ammo,
			tostring(s.slots[s.equipped].reloading),
			math.max(0, s.readyAt - os.clock()),
			C.stats.damage,
			C.stats.pellets,
			C.stats.shotInterval,
			C.stats.distance,
			C.stats.falloff,
			A.stats.maxScanMs,
			C.stats.scanMs,
			#sounds,
			table.concat(audioLines, "\n")
		)
	end)
	C.changed.Event:Connect(function()
		for _, fn in rowRefresh do
			fn()
		end
		statusText()
	end)
	rebuild()
end
return Panel
