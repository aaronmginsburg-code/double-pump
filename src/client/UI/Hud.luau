--!strict
-- In-match HUD. Layout (1920x1080 reference):
--   top centre    team scores, timer, kill target, state banner
--   top right     kill feed
--   centre        crosshair, hitmarkers, damage numbers, damage direction
--   lower centre  elimination banner (HEADSHOT / DOUBLE PUMP!)
--   bottom left   health
--   bottom right  the two shotguns: shells, cooldown readiness, which is equipped
-- Kept away from the middle of the screen so it never blocks the fight.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local UIRoot = require(script.Parent.UIRoot)
local Controllers = script.Parent.Parent.Controllers
local WeaponController = require(Controllers.WeaponController)
local MatchClient = require(Controllers.MatchClient)
local Settings = require(Controllers.Settings)
local InputController = require(Controllers.InputController)
local AudioController = require(Controllers.AudioController)

local Hud = {}

local player = Players.LocalPlayer
local C = Theme.Colors
local new = Theme.new

local gui: ScreenGui
local root: Frame
local refs: { [string]: any } = {}
local slotCards: { { frame: Frame, pips: { Frame }, bar: Frame, status: TextLabel, glow: UIStroke, scale: UIScale, key: TextLabel } } =
	{}
local feedEntries: { Frame } = {}
local damageArcs: { { frame: Frame, from: Vector3, born: number } } = {}

---------------------------------------------------------------------------------------
-- Construction

local function buildTop()
	local top = new("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.fromOffset(520, 82),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local function teamBox(team: string, x: number)
		local box = new("Frame", {
			Name = team,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, x, 0, 0),
			Size = UDim2.fromOffset(140, 70),
			BackgroundColor3 = Theme.teamColor(team),
			Parent = top,
		}, { Theme.corner(12), Theme.gradient(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)) })
		local label = Theme.label({
			Name = "Score",
			Text = "0",
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.Fonts.Display,
			Parent = box,
		})
		local you = Theme.label({
			Name = "You",
			Text = "YOU",
			Size = UDim2.fromOffset(60, 18),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 4),
			TextColor3 = Theme.teamColor(team),
			FontFace = Theme.Fonts.Heavy,
			Visible = false,
			Parent = box,
		})
		refs[team .. "Score"] = label
		refs[team .. "You"] = you
		refs[team .. "Box"] = box
	end
	teamBox("Red", -170)
	teamBox("Blue", 170)
	local timerBox = Theme.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(180, 70),
		Parent = top,
	})
	refs.Timer = Theme.label({
		Text = "5:00",
		Size = UDim2.fromScale(1, 0.66),
		FontFace = Theme.Fonts.Display,
		Parent = timerBox,
	})
	refs.Target = Theme.label({
		Text = "FIRST TO 40",
		Size = UDim2.fromScale(1, 0.3),
		Position = UDim2.fromScale(0, 0.66),
		TextColor3 = C.TextDim,
		FontFace = Theme.Fonts.Bold,
		Outline = false,
		Parent = timerBox,
	})
	refs.Top = top

	-- State banner under the scores
	refs.Banner = Theme.label({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.fromOffset(900, 34),
		Text = "",
		FontFace = Theme.Fonts.Heavy,
		TextColor3 = C.Accent,
		Parent = root,
	})
	refs.BigCount = Theme.label({
		Name = "BigCount",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(300, 160),
		Text = "",
		FontFace = Theme.Fonts.Display,
		TextColor3 = C.Accent,
		Outline = 3,
		Visible = false,
		Parent = root,
	})
end

local function buildHealth()
	local box = Theme.panel({
		Name = "Health",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 28, 1, -28),
		Size = UDim2.fromOffset(380, 74),
		Parent = root,
	})
	Theme.label({
		Text = "HP",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(46, 50),
		TextColor3 = C.TextDim,
		FontFace = Theme.Fonts.Display,
		Parent = box,
	})
	local track = new("Frame", {
		Position = UDim2.fromOffset(70, 22),
		Size = UDim2.new(1, -170, 0, 30),
		BackgroundColor3 = C.Ink,
		Parent = box,
	}, { Theme.corner(8) })
	local lag = new("Frame", {
		Name = "Lag",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Hot,
		Parent = track,
	}, { Theme.corner(8) })
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Good,
		Parent = track,
	}, { Theme.corner(8), Theme.gradient(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)) })
	refs.HealthFill = fill
	refs.HealthLag = lag
	refs.HealthText = Theme.label({
		Text = "100",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(86, 50),
		FontFace = Theme.Fonts.Display,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = box,
	})
	refs.Protected = Theme.label({
		Text = "SPAWN PROTECTED",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(0, -6),
		Size = UDim2.fromOffset(220, 24),
		TextColor3 = C.Blue,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		Parent = box,
	})
end

local function buildWeapons()
	local holder = new("Frame", {
		Name = "Weapons",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -28),
		Size = UDim2.fromOffset(460, 120),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for slot = 1, 2 do
		local card = Theme.panel({
			Name = "Slot" .. slot,
			LayoutOrder = slot,
			Size = UDim2.fromOffset(220, 110),
			Parent = holder,
		})
		local scale = new("UIScale", { Parent = card }) :: UIScale
		local glow = card:FindFirstChildOfClass("UIStroke") :: UIStroke
		Theme.label({
			Text = if slot == 1 then "PUMP A" else "PUMP B",
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.fromOffset(130, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Theme.Fonts.Display,
			Parent = card,
		})
		local key = Theme.label({
			Text = tostring(slot),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 8),
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Ink,
			TextColor3 = C.TextDim,
			Outline = false,
			Parent = card,
		})
		Theme.corner(6).Parent = key
		-- Shell pips
		local pipRow = new("Frame", {
			Position = UDim2.fromOffset(14, 44),
			Size = UDim2.fromOffset(192, 26),
			BackgroundTransparency = 1,
			Parent = card,
		}, {
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local pips = {}
		for i = 1, 5 do
			local pip = new("Frame", {
				LayoutOrder = i,
				Size = UDim2.fromOffset(30, 26),
				BackgroundColor3 = C.Hot,
				Parent = pipRow,
			}, {
				Theme.corner(5),
				new("Frame", {
					Name = "Brass",
					AnchorPoint = Vector2.new(0, 0),
					Size = UDim2.fromScale(0.3, 1),
					BackgroundColor3 = C.Gold,
					BorderSizePixel = 0,
				}, { Theme.corner(5) }),
			})
			pips[i] = pip
		end
		-- Cooldown / readiness bar
		local track = new("Frame", {
			Position = UDim2.fromOffset(14, 80),
			Size = UDim2.fromOffset(192, 10),
			BackgroundColor3 = C.Ink,
			Parent = card,
		}, { Theme.corner(5) })
		local bar = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.Good,
			Parent = track,
		}, { Theme.corner(5) })
		local status = Theme.label({
			Text = "READY",
			Position = UDim2.fromOffset(14, 92),
			Size = UDim2.fromOffset(192, 14),
			TextColor3 = C.Good,
			FontFace = Theme.Fonts.Bold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Outline = false,
			Parent = card,
		})
		slotCards[slot] =
			{ frame = card, pips = pips, bar = bar, status = status, glow = glow, scale = scale, key = key }
	end
	refs.SwapHint = Theme.label({
		Text = "Q  SWAP   •   R  RELOAD",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -150),
		Size = UDim2.fromOffset(300, 20),
		TextColor3 = C.TextDim,
		FontFace = Theme.Fonts.Bold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = root,
	})
end

local function buildCrosshair()
	local center = new("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(80, 80),
		BackgroundTransparency = 1,
		Parent = root,
	})
	refs.Crosshair = center
	-- Hitmarker: four diagonal ticks
	local hit = new("Frame", {
		Name = "Hitmarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(44, 44),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	})
	for i = 0, 3 do
		local angle = 45 + i * 90
		local rad = math.rad(angle)
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(rad) * 14, 0.5, math.sin(rad) * 14),
			Size = UDim2.fromOffset(14, 3),
			Rotation = angle,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = hit,
		}, { Theme.stroke(Color3.new(0, 0, 0), 1, 0.4) })
	end
	refs.Hitmarker = hit
	refs.HitScale = new("UIScale", { Parent = hit })
	-- Damage direction arcs live here
	refs.DamageRing = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 300),
		BackgroundTransparency = 1,
		Parent = root,
	})
	-- Low-health vignette
	refs.Vignette = new("ImageLabel", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "rbxasset://textures/ui/TopBar/WhiteOverlay.png",
		ImageTransparency = 1,
		ImageColor3 = C.Hot,
		Parent = gui,
	})
	refs.DamageFlash = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Hot,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.25, 0.85),
				NumberSequenceKeypoint.new(0.75, 0.85),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}),
	})
end

local function drawCrosshair()
	local center = refs.Crosshair :: Frame
	center:ClearAllChildren()
	local v = Settings.values
	local color = (Settings.CROSSHAIR_COLORS :: any)[v.crosshairColor] or Color3.new(1, 1, 1)
	local size = v.crosshairSize
	local style = v.crosshairStyle
	local function bar(x: number, y: number, w: number, h: number)
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, x * size, 0.5, y * size),
			Size = UDim2.fromOffset(w * size, h * size),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = center,
		}, { Theme.stroke(Color3.new(0, 0, 0), 1, 0.3) })
	end
	if style == "Cross" or style == "CrossDot" then
		-- Gap sized to the inner pellet ring so the crosshair shows the spread
		bar(-13, 0, 10, 2)
		bar(13, 0, 10, 2)
		bar(0, -13, 2, 10)
		bar(0, 13, 2, 10)
	end
	if style == "Dot" or style == "CrossDot" then
		bar(0, 0, 3, 3)
	end
	if style == "Circle" then
		local ring = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(34 * size, 34 * size),
			BackgroundTransparency = 1,
			Parent = center,
		}, { Theme.corner(100), Theme.stroke(color, 2) })
		ring.Name = "Ring"
		bar(0, 0, 3, 3)
	end
end

local function buildFeed()
	refs.Feed = new("Frame", {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(460, 260),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	refs.ElimBanner = new("Frame", {
		Name = "ElimBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.68),
		Size = UDim2.fromOffset(640, 110),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	})
	refs.ElimTitle = Theme.label({
		Size = UDim2.fromScale(1, 0.55),
		Text = "ELIMINATED",
		FontFace = Theme.Fonts.Display,
		Outline = 2.5,
		Parent = refs.ElimBanner,
	})
	refs.ElimSub = Theme.label({
		Position = UDim2.fromScale(0, 0.58),
		Size = UDim2.fromScale(1, 0.36),
		Text = "",
		TextColor3 = C.TextDim,
		Parent = refs.ElimBanner,
	})
	refs.ElimScale = new("UIScale", { Parent = refs.ElimBanner })
end

---------------------------------------------------------------------------------------
-- Feedback

local hitToken = 0
function Hud.hitmarker(headshot: boolean, killed: boolean)
	hitToken += 1
	local token = hitToken
	local hit = refs.Hitmarker :: Frame
	local color = if killed then C.Hot elseif headshot then C.Gold else Color3.new(1, 1, 1)
	for _, tick in hit:GetChildren() do
		if tick:IsA("Frame") then
			tick.BackgroundColor3 = color
			tick.Size = UDim2.fromOffset(if headshot or killed then 18 else 14, if headshot or killed then 4 else 3)
		end
	end
	hit.Visible = true
	refs.HitScale.Scale = if killed then 1.6 elseif headshot then 1.4 else 1.15
	Theme.tween(refs.HitScale, 0.12, { Scale = 1 })
	task.delay(if killed then 0.4 else 0.22, function()
		if token == hitToken then
			hit.Visible = false
		end
	end)
end

function Hud.damageNumber(amount: number, headshot: boolean)
	if not Settings.values.showDamageNumbers or amount <= 0 then
		return
	end
	local label = Theme.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 40 + math.random(-10, 10), 0.5, -30 + math.random(-6, 6)),
		Size = UDim2.fromOffset(110, 40),
		Text = tostring(amount),
		TextColor3 = if headshot then C.Gold else Color3.new(1, 1, 1),
		FontFace = Theme.Fonts.Display,
		Outline = 2,
		Parent = root,
	})
	Theme.tween(label, 0.6, { Position = label.Position - UDim2.fromOffset(0, 40), TextTransparency = 1 })
	task.delay(0.65, function()
		label:Destroy()
	end)
end

local bannerToken = 0
function Hud.eliminationBanner(title: string, subtitle: string, color: Color3, big: boolean)
	bannerToken += 1
	local token = bannerToken
	refs.ElimTitle.Text = title
	refs.ElimTitle.TextColor3 = color
	refs.ElimSub.Text = subtitle
	refs.ElimBanner.Visible = true
	refs.ElimScale.Scale = if big then 1.6 else 1.25
	Theme.tween(refs.ElimScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(if big then 2.2 else 1.6, function()
		if token == bannerToken then
			refs.ElimBanner.Visible = false
		end
	end)
end

function Hud.feed(data: any)
	local me = player.UserId
	local involved = data.killerUserId == me or data.victimUserId == me
	local row = new("Frame", {
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = if involved then C.PanelLight else C.Ink,
		BackgroundTransparency = if involved then 0.05 else 0.35,
		LayoutOrder = -os.clock() * 100,
		Parent = refs.Feed,
	}, {
		Theme.corner(8),
		Theme.padding(6),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local function text(t: string, color: Color3, order: number, font: Font?)
		local label = Theme.label({
			Text = t,
			TextScaled = false,
			TextSize = 20,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			TextColor3 = color,
			FontFace = font or Theme.Fonts.Heavy,
			LayoutOrder = order,
			Outline = false,
			Parent = row,
		})
		return label
	end
	if data.killer ~= "" then
		text(data.killer, Theme.teamColor(data.killerTeam), 1)
	end
	local icon = if data.doublePump then "✦✦ DOUBLE PUMP" elseif data.headshot then "◎ PUMP" else "PUMP"
	text(icon, if data.doublePump then C.Accent elseif data.headshot then C.Gold else C.TextDim, 2, Theme.Fonts.Display)
	text(data.victim, Theme.teamColor(data.victimTeam), 3)
	table.insert(feedEntries, row)
	while #feedEntries > 5 do
		(table.remove(feedEntries, 1) :: Frame):Destroy()
	end
	task.delay(6, function()
		if row.Parent then
			Theme.tween(row, 0.4, { BackgroundTransparency = 1 })
			for _, child in row:GetChildren() do
				if child:IsA("TextLabel") then
					Theme.tween(child, 0.4, { TextTransparency = 1 })
				end
			end
			task.delay(0.45, function()
				local i = table.find(feedEntries, row)
				if i then
					table.remove(feedEntries, i)
				end
				row:Destroy()
			end)
		end
	end)
end

function Hud.damageTaken(from: Vector3?)
	local flash = refs.DamageFlash :: Frame
	flash.BackgroundTransparency = 0.55
	Theme.tween(flash, 0.35, { BackgroundTransparency = 1 })
	if from then
		local arc = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(90, 10),
			BackgroundColor3 = C.Hot,
			BorderSizePixel = 0,
			Parent = refs.DamageRing,
		}, { Theme.corner(5) })
		table.insert(damageArcs, { frame = arc, from = from, born = os.clock() })
	end
end

---------------------------------------------------------------------------------------
-- Per-frame update

local function updateWeapons()
	local equipped = WeaponController.state.equipped
	for slot, card in slotCards do
		local view = WeaponController.view(slot)
		local isEquipped = slot == equipped
		for i, pip in card.pips do
			pip.BackgroundTransparency = if i <= view.ammo then 0 else 0.8
			local brass = pip:FindFirstChild("Brass") :: Frame?
			if brass then
				brass.BackgroundTransparency = pip.BackgroundTransparency
			end
		end
		local ready = view.cooldownRemaining <= 0
		card.bar.Size = UDim2.fromScale(1 - view.cooldownFraction, 1)
		card.bar.BackgroundColor3 = if ready then C.Good else C.Accent
		if view.reloading then
			card.status.Text = "RELOADING"
			card.status.TextColor3 = C.Accent
		elseif view.ammo == 0 then
			card.status.Text = "EMPTY — R"
			card.status.TextColor3 = C.Hot
		elseif ready then
			card.status.Text = if isEquipped then "READY" else "READY — SWAP!"
			card.status.TextColor3 = C.Good
		else
			card.status.Text = string.format("PUMPING %.1fs", view.cooldownRemaining)
			card.status.TextColor3 = C.TextDim
		end
		local targetScale = if isEquipped then 1 else 0.86
		card.scale.Scale += (targetScale - card.scale.Scale) * 0.35
		card.frame.BackgroundTransparency = if isEquipped then 0.02 else 0.35
		card.glow.Color = if isEquipped then C.Accent else C.Stroke
		card.glow.Thickness = if isEquipped then 3 else 2
		card.glow.Transparency = if isEquipped then 0 else 0.4
	end
	local kind = InputController.LastInputKind
	refs.SwapHint.Text = if kind == "Gamepad"
		then "RB  SWAP   •   X  RELOAD"
		elseif kind == "Touch" then ""
		else "Q  SWAP   •   R  RELOAD"
	for slot, card in slotCards do
		card.key.Text = if kind == "Gamepad" then (if slot == 1 then "◀" else "▶") else tostring(slot)
		card.key.Visible = kind ~= "Touch"
	end
end

local function updateHealth()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local health = if humanoid then math.max(0, humanoid.Health) else 0
	local max = if humanoid then humanoid.MaxHealth else 100
	local frac = math.clamp(health / max, 0, 1)
	refs.HealthFill.Size = UDim2.fromScale(frac, 1)
	refs.HealthFill.BackgroundColor3 = if frac > 0.5 then C.Good elseif frac > 0.25 then C.Gold else C.Hot
	local lag = refs.HealthLag :: Frame
	local lagFrac = lag.Size.X.Scale
	lag.Size = UDim2.fromScale(if lagFrac > frac then lagFrac - math.min(lagFrac - frac, 0.02) else frac, 1)
	refs.HealthText.Text = tostring(math.ceil(health))
	refs.Vignette.ImageTransparency = if frac < 0.35 and frac > 0 then 0.55 + frac else 1
	local protectedUntil = character and character:GetAttribute("ProtectedUntil")
	refs.Protected.Visible = typeof(protectedUntil) == "number" and workspace:GetServerTimeNow() < protectedUntil
end

local function updateTop()
	local state = MatchClient.state()
	local inMatch = MatchClient.myTeam() ~= nil
	local showScores = inMatch and state ~= "Waiting" and state ~= "Intermission"
	refs.Top.Visible = showScores
	if showScores then
		refs.RedScore.Text = tostring(MatchClient.get("RedScore") or 0)
		refs.BlueScore.Text = tostring(MatchClient.get("BlueScore") or 0)
		local left = MatchClient.timeLeft()
		refs.Timer.Text = if state == "Starting" then "0:00" else Theme.formatTime(left)
		refs.Timer.TextColor3 = if state == "Overtime" or (state == "Active" and left < 30) then C.Hot else C.Text
		refs.Target.Text = `FIRST TO {MatchClient.get("Target") or 40}`
		local mine = MatchClient.myTeam()
		refs.RedYou.Visible = mine == "Red"
		refs.BlueYou.Visible = mine == "Blue"
	end
	local banner = ""
	if MatchClient.mode() == "Practice" then
		banner = "PRACTICE RANGE  •  open the menu (M) to join a match"
	elseif state == "Waiting" and MatchClient.mode() == "Match" then
		banner =
			`WAITING FOR PLAYERS  ({MatchClient.get("Players") or 1}/{MatchClient.get("MinPlayers") or 2})  •  warm up on the range`
	elseif state == "Intermission" and MatchClient.mode() == "Match" then
		banner = `MATCH STARTS IN {math.ceil(MatchClient.timeLeft())}`
	elseif state == "Overtime" then
		banner = "OVERTIME  •  NEXT ELIMINATION WINS"
	elseif state == "Starting" then
		banner = `{string.upper(MatchClient.get("MapName") or "")}  •  TEAM DEATHMATCH`
	end
	refs.Banner.Text = banner
end

local function updateDamageArcs()
	local camera = workspace.CurrentCamera.CFrame
	local now = os.clock()
	for i = #damageArcs, 1, -1 do
		local arc = damageArcs[i]
		local age = now - arc.born
		if age > 1.2 then
			arc.frame:Destroy()
			table.remove(damageArcs, i)
		else
			local rel = camera:PointToObjectSpace(arc.from)
			local angle = math.atan2(rel.X, -rel.Z)
			arc.frame.Position = UDim2.new(0.5, math.sin(angle) * 120, 0.5, -math.cos(angle) * 120)
			arc.frame.Rotation = math.deg(angle)
			arc.frame.BackgroundTransparency = age / 1.2
		end
	end
end

function Hud.setVisible(visible: boolean)
	gui.Enabled = visible
end

function Hud.start()
	gui, root = UIRoot.screen("Hud", 10)
	buildTop()
	buildHealth()
	buildWeapons()
	buildCrosshair()
	buildFeed()
	drawCrosshair()
	Settings.Changed:Connect(drawCrosshair)

	WeaponController.HitConfirmed:Connect(function(results)
		local anyHead, anyKill, anyDouble = false, false, false
		for _, r in results do
			if r.protected then
				continue
			end
			Hud.damageNumber(r.damage, r.headshot)
			anyHead = anyHead or r.headshot
			anyKill = anyKill or r.killed
			anyDouble = anyDouble or r.doublePump
		end
		Hud.hitmarker(anyHead, anyKill)
		if anyKill then
			AudioController.play(if anyDouble then "DoublePumpElim" else "Elimination")
		elseif anyHead then
			AudioController.play("HitHead")
		else
			AudioController.play("HitBody")
		end
	end)
	MatchClient.Elimination:Connect(function(data)
		Hud.feed(data)
		if data.killerUserId == player.UserId then
			if data.doublePump then
				Hud.eliminationBanner("DOUBLE PUMP!", `eliminated {data.victim}`, C.Accent, true)
			elseif data.headshot then
				Hud.eliminationBanner("HEADSHOT", `eliminated {data.victim}`, C.Gold, false)
			else
				Hud.eliminationBanner("ELIMINATED", data.victim, C.Text, false)
			end
		end
	end)
	MatchClient.Damaged:Connect(function(data)
		Hud.damageTaken(if typeof(data.from) == "Vector3" then data.from else nil)
		AudioController.play("DamageTaken")
	end)
	MatchClient.Countdown:Connect(function(n)
		local big = refs.BigCount :: TextLabel
		big.Text = tostring(n)
		big.Visible = true
		big.TextTransparency = 0
		AudioController.play("CountdownTick")
		Theme.tween(big, 0.9, { TextTransparency = 0.6 })
	end)
	MatchClient.Started:Connect(function()
		local big = refs.BigCount :: TextLabel
		big.Text = "GO!"
		big.Visible = true
		big.TextTransparency = 0
		AudioController.play("MatchStart")
		Theme.tween(big, 1.2, { TextTransparency = 1 })
		task.delay(1.2, function()
			big.Visible = false
		end)
	end)
	RunService.RenderStepped:Connect(function()
		if not gui.Enabled then
			return
		end
		updateWeapons()
		updateHealth()
		updateTop()
		updateDamageArcs()
	end)
end

return Hud
