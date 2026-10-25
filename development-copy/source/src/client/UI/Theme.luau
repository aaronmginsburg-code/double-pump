--!strict
-- Double Pump's visual language: bold, high-contrast arcade style. Dark slate panels,
-- warm "muzzle-flash" orange accent, team red/blue, heavy display type.
-- Also a tiny element builder so UI code stays declarative.

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	Ink = Color3.fromRGB(14, 16, 22),
	Panel = Color3.fromRGB(24, 27, 36),
	PanelLight = Color3.fromRGB(38, 42, 56),
	Stroke = Color3.fromRGB(70, 76, 98),
	Text = Color3.fromRGB(245, 246, 250),
	TextDim = Color3.fromRGB(160, 166, 186),
	Accent = Color3.fromRGB(255, 168, 38), -- muzzle-flash orange
	AccentDark = Color3.fromRGB(196, 110, 12),
	Hot = Color3.fromRGB(255, 72, 96),
	Good = Color3.fromRGB(80, 230, 140),
	Gold = Color3.fromRGB(255, 214, 80),
	Red = Color3.fromRGB(255, 72, 72),
	Blue = Color3.fromRGB(64, 156, 255),
	Headshot = Color3.fromRGB(255, 70, 70),
}

Theme.Fonts = {
	Display = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
	Heavy = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
	Bold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
	Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
}

function Theme.teamColor(team: string?): Color3
	if team == "Red" then
		return Theme.Colors.Red
	elseif team == "Blue" then
		return Theme.Colors.Blue
	end
	return Theme.Colors.TextDim
end

-- new("Frame", { Size = ..., [children] = {...} })
function Theme.new(className: string, props: { [any]: any }?, children: { any }?): any
	local inst = Instance.new(className :: any)
	local parent = nil
	for key, value in (props or {}) :: { [any]: any } do
		if key == "Parent" then
			parent = value
		elseif typeof(key) == "string" then
			(inst :: any)[key] = value
		end
	end
	for _, child in (children or {}) :: { any } do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local new = Theme.new

function Theme.corner(radius: number?): any
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Theme.stroke(color: Color3?, thickness: number?, transparency: number?): any
	return new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.padding(px: number): any
	local u = UDim.new(0, px)
	return new("UIPadding", { PaddingLeft = u, PaddingRight = u, PaddingTop = u, PaddingBottom = u })
end

function Theme.list(direction: Enum.FillDirection?, gap: number?, align: Enum.HorizontalAlignment?): any
	return new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 8),
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Theme.gradient(top: Color3, bottom: Color3, rotation: number?): any
	return new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

-- Text label with an outline stroke so it reads over any background.
function Theme.label(props: { [string]: any }): TextLabel
	local p = table.clone(props)
	p.BackgroundTransparency = p.BackgroundTransparency or 1
	p.FontFace = p.FontFace or Theme.Fonts.Heavy
	p.TextColor3 = p.TextColor3 or Theme.Colors.Text
	p.TextScaled = if p.TextScaled == nil then true else p.TextScaled
	local outline = p.Outline
	p.Outline = nil
	local label = new("TextLabel", p)
	if outline ~= false then
		new("UIStroke", {
			Color = Color3.new(0, 0, 0),
			Thickness = if typeof(outline) == "number" then outline else 1.5,
			Transparency = 0.35,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Parent = label,
		})
	end
	return label
end

export type ButtonStyle = "Primary" | "Secondary" | "Ghost" | "Danger"

-- Chunky arcade button with a hover/press bounce. Returns the button.
function Theme.button(text: string, style: ButtonStyle?, props: { [string]: any }?): TextButton
	local s = style or "Secondary"
	local bg = if s == "Primary"
		then Theme.Colors.Accent
		elseif s == "Danger" then Theme.Colors.Hot
		elseif s == "Ghost" then Theme.Colors.Panel
		else Theme.Colors.PanelLight
	local p: { [string]: any } = {
		Text = text,
		AutoButtonColor = false,
		BackgroundColor3 = bg,
		FontFace = Theme.Fonts.Heavy,
		TextColor3 = if s == "Primary" then Theme.Colors.Ink else Theme.Colors.Text,
		TextScaled = true,
		Size = UDim2.fromOffset(220, 52),
	}
	for k, v in (props or {}) :: { [string]: any } do
		p[k] = v
	end
	local button = new("TextButton", p, {
		Theme.corner(10),
		Theme.stroke(if s == "Primary" then Theme.Colors.AccentDark else Theme.Colors.Stroke, 2),
		new("UIPadding", {
			PaddingTop = UDim.new(0.18, 0),
			PaddingBottom = UDim.new(0.18, 0),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
	}) :: TextButton
	local scale = new("UIScale", { Parent = button }) :: UIScale
	local function tween(to: number)
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = to }):Play()
	end
	button.MouseEnter:Connect(function()
		tween(1.04)
		if Theme.onHover then
			Theme.onHover()
		end
	end)
	button.MouseLeave:Connect(function()
		tween(1)
	end)
	button.MouseButton1Down:Connect(function()
		tween(0.96)
	end)
	button.MouseButton1Up:Connect(function()
		tween(1.04)
	end)
	button.Activated:Connect(function()
		if Theme.onClick then
			Theme.onClick()
		end
	end)
	return button
end

-- Panel with the standard look.
function Theme.panel(props: { [string]: any }, children: { any }?): Frame
	local p = table.clone(props)
	p.BackgroundColor3 = p.BackgroundColor3 or Theme.Colors.Panel
	p.BackgroundTransparency = p.BackgroundTransparency or 0.08
	local frame = new("Frame", p, children) :: Frame
	Theme.corner(14).Parent = frame
	Theme.stroke(Theme.Colors.Stroke, 2, 0.3).Parent = frame
	return frame
end

function Theme.tween(
	inst: Instance,
	time: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- Set by the client bootstrap to play UI sounds.
Theme.onHover = nil :: (() -> ())?
Theme.onClick = nil :: (() -> ())?

function Theme.formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return Theme
