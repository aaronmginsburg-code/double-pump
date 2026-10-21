--!strict
-- Main menu (and in-match pause menu). Left: logo and navigation. Right: the selected
-- page. Top right: level, XP and coins. The world keeps rendering behind it (the
-- camera slowly orbits the current map).
--
-- Pages: Play, Locker, Profile, Leaderboards, Settings, How to play.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local Cosmetics = require(Shared.Progression.Cosmetics)
local Levels = require(Shared.Progression.Levels)

local Theme = require(script.Parent.Theme)
local UIRoot = require(script.Parent.UIRoot)
local SettingsPanel = require(script.Parent.SettingsPanel)
local Controllers = script.Parent.Parent.Controllers
local MatchClient = require(Controllers.MatchClient)
local ProfileClient = require(Controllers.ProfileClient)
local InputController = require(Controllers.InputController)

local MainMenu = {}

local player = Players.LocalPlayer
local C = Theme.Colors
local new = Theme.new

local gui: ScreenGui
local root: Frame
local content: Frame
local navButtons: { [string]: TextButton } = {}
local pages: { [string]: Frame } = {}
local pageBuilders: { [string]: (Frame) -> () } = {}
local pageRefreshers: { [string]: () -> () } = {}
local currentPage = "Play"
local refs: { [string]: any } = {}

MainMenu.isOpen = false
-- Set by the bootstrap.
MainMenu.onStartTutorial = nil :: (() -> ())?

---------------------------------------------------------------------------------------
-- Helpers

local function sectionTitle(parent: Instance, text: string, order: number?): TextLabel
	return Theme.label({
		Text = text,
		Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Display,
		TextColor3 = C.Text,
		LayoutOrder = order or 0,
		Parent = parent,
	})
end

local function body(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local p: { [string]: any } = {
		Text = text,
		Size = UDim2.new(1, 0, 0, 24),
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		FontFace = Theme.Fonts.Body,
		TextColor3 = C.TextDim,
		Outline = false,
		Parent = parent,
	}
	for k, v in (props or {}) :: { [string]: any } do
		p[k] = v
	end
	return Theme.label(p)
end

local function progressBar(parent: Instance, props: { [string]: any }, color: Color3?): (Frame, Frame)
	local p = table.clone(props)
	p.BackgroundColor3 = C.Ink
	p.Parent = parent
	local bar = new("Frame", p, { Theme.corner(6) }) :: Frame
	local fill = new(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = color or C.Accent, Parent = bar },
		{ Theme.corner(6) }
	) :: Frame
	return bar, fill
end

local function formatDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d = seconds // 86400
	local h = (seconds % 86400) // 3600
	local m = (seconds % 3600) // 60
	if d > 0 then
		return `{d}d {h}h`
	elseif h > 0 then
		return `{h}h {m}m`
	end
	return `{m}m`
end

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

-- A small drawing of the shotgun in a skin's colours, for locker cards.
local function gunSwatch(parent: Instance, skin: any, size: UDim2, position: UDim2)
	local holder = new("Frame", { Size = size, Position = position, BackgroundTransparency = 1, Parent = parent })
	local function bar(x: number, y: number, w: number, h: number, color: Color3, radius: number?)
		new("Frame", {
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = holder,
		}, { Theme.corner(radius or 3) })
	end
	bar(0.02, 0.38, 0.3, 0.2, skin.wood, 4) -- stock
	bar(0.28, 0.34, 0.34, 0.2, skin.metal, 3) -- receiver
	bar(0.6, 0.34, 0.38, 0.08, skin.metal, 2) -- barrel
	bar(0.6, 0.46, 0.3, 0.1, skin.metal, 2) -- magazine tube
	bar(0.55, 0.52, 0.22, 0.14, skin.wood, 4) -- pump
	bar(0.33, 0.54, 0.07, 0.24, skin.wood, 3) -- grip
	bar(0.4, 0.54, 0.04, 0.1, skin.accent, 2) -- trigger guard
end

---------------------------------------------------------------------------------------
-- Pages

pageBuilders.Play = function(page)
	local match = Theme.panel({
		Name = "Match",
		Size = UDim2.new(1, 0, 0, 330),
		BackgroundColor3 = C.Panel,
		Parent = page,
	})
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 190)),
		Rotation = 90,
		Parent = match,
	})
	Theme.label({
		Text = "TEAM DEATHMATCH",
		Size = UDim2.fromOffset(620, 64),
		Position = UDim2.fromOffset(32, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Display,
		Parent = match,
	})
	local M = GameConfig.Match
	body(
		match,
		`Red vs Blue, up to {M.MaxTeamSize}v{M.MaxTeamSize}. First team to {M.ScoreToWin} eliminations or the most after {M.Duration // 60} minutes wins. Two pump shotguns, no building, no second chances.`,
		{
			Size = UDim2.fromOffset(640, 60),
			Position = UDim2.fromOffset(34, 98),
		}
	)
	refs.MatchStatus = body(match, "", {
		Size = UDim2.fromOffset(640, 30),
		Position = UDim2.fromOffset(34, 172),
		TextColor3 = C.Text,
		FontFace = Theme.Fonts.Bold,
	})
	local play = Theme.button("PLAY", "Primary", {
		Size = UDim2.fromOffset(300, 84),
		Position = UDim2.new(0, 32, 1, -112),
		FontFace = Theme.Fonts.Display,
		Parent = match,
	})
	play.Activated:Connect(function()
		Net.event("PlayerAction"):FireServer("Deploy")
	end)
	refs.PlayButton = play

	local practice = Theme.panel({
		Name = "Practice",
		Size = UDim2.new(0.5, -10, 0, 190),
		Position = UDim2.fromOffset(0, 350),
		Parent = page,
	})
	Theme.label({
		Text = "PRACTICE RANGE",
		Size = UDim2.new(1, -40, 0, 44),
		Position = UDim2.fromOffset(24, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Display,
		Parent = practice,
	})
	body(practice, "Static, strafing and jumping targets. Drill the swap.", {
		Size = UDim2.new(1, -48, 0, 50),
		Position = UDim2.fromOffset(26, 68),
	})
	local practiceButton = Theme.button("PRACTICE", "Secondary", {
		Size = UDim2.fromOffset(220, 56),
		Position = UDim2.new(0, 24, 1, -76),
		Parent = practice,
	})
	practiceButton.Activated:Connect(function()
		Net.event("PlayerAction"):FireServer("Practice")
	end)

	local controls = Theme.panel({
		Name = "Controls",
		Size = UDim2.new(0.5, -10, 0, 190),
		Position = UDim2.new(0.5, 10, 0, 350),
		Parent = page,
	})
	Theme.label({
		Text = "CONTROLS",
		Size = UDim2.new(1, -40, 0, 44),
		Position = UDim2.fromOffset(24, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Display,
		Parent = controls,
	})
	refs.ControlsText = body(controls, "", {
		Size = UDim2.new(1, -48, 0, 110),
		Position = UDim2.fromOffset(26, 68),
		RichText = true,
	})
end

local function controlsText(): string
	local kind = InputController.LastInputKind
	if kind == "Gamepad" then
		return "<b>R2</b> fire   <b>R1/L1</b> swap   <b>D-pad</b> pick gun\n<b>X</b> reload   <b>B</b> crouch   <b>A</b> jump\n<b>Select</b> scoreboard   <b>Start</b> menu"
	elseif kind == "Touch" then
		return "Drag the right side to aim. <b>FIRE</b>, <b>SWAP</b>, <b>1</b>/<b>2</b>, <b>RELOAD</b>, <b>CROUCH</b> and <b>JUMP</b> buttons are on screen. Move them in Settings."
	end
	return "<b>LMB</b> fire   <b>1</b>/<b>2</b> pick gun   <b>Q</b> swap\n<b>R</b> reload   <b>C</b>/<b>Ctrl</b> crouch   <b>Space</b> jump\n<b>Tab</b> scoreboard   <b>M</b> menu"
end

pageRefreshers.Play = function()
	local state = MatchClient.state()
	local count = MatchClient.get("Players") or 0
	local mapName = MatchClient.get("MapName") or ""
	local mode = MatchClient.mode()
	local text
	if state == "Waiting" then
		text =
			`Waiting for players ({count}/{GameConfig.Match.MinPlayersToStart}). You'll warm up in the range until a match starts.`
	elseif state == "Active" or state == "Overtime" then
		text = `Match in progress{if mapName ~= "" then " on " .. mapName else ""}. Jump in now.`
	elseif state == "Results" or state == "Voting" then
		text = "Match just ended. Next one starts shortly."
	else
		text = `Next match starting{if mapName ~= "" then " on " .. mapName else ""}.`
	end
	refs.MatchStatus.Text = text
	refs.PlayButton.Text = if mode == "Match" then "RESUME" else "PLAY"
	refs.ControlsText.Text = controlsText()
end

pageBuilders.Locker = function(page)
	local scroll = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = page,
	}, { Theme.list(Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Left) }) :: ScrollingFrame
	sectionTitle(scroll, "SHOTGUN SKINS", 1)
	body(scroll, "Skins only change colours. Every skin fires exactly the same.", { LayoutOrder = 2 })
	local grid = new("Frame", {
		Size = UDim2.new(1, -14, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = scroll,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(250, 230),
			CellPadding = UDim2.fromOffset(14, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	refs.SkinCards = {}
	for i, skin in Cosmetics.Skins do
		local card = Theme.panel({ LayoutOrder = i, Parent = grid })
		local rarity = Cosmetics.RarityColors[skin.rarity]
		new(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = rarity, BorderSizePixel = 0, Parent = card },
			{ Theme.corner(3) }
		)
		gunSwatch(card, skin, UDim2.fromOffset(210, 100), UDim2.fromOffset(20, 18))
		Theme.label({
			Text = skin.name,
			Size = UDim2.new(1, -24, 0, 28),
			Position = UDim2.fromOffset(12, 118),
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Theme.Fonts.Bold,
			Outline = false,
			Parent = card,
		})
		Theme.label({
			Text = skin.rarity:upper(),
			Size = UDim2.new(1, -24, 0, 18),
			Position = UDim2.fromOffset(12, 146),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = rarity,
			FontFace = Theme.Fonts.Bold,
			Outline = false,
			Parent = card,
		})
		local button = Theme.button("", "Secondary", {
			Size = UDim2.new(1, -24, 0, 44),
			Position = UDim2.new(0, 12, 1, -56),
			Parent = card,
		})
		button.Activated:Connect(function()
			local data = ProfileClient.get()
			if not data then
				return
			end
			if ProfileClient.owns(skin.id) then
				ProfileClient.equip(skin.id)
			elseif Cosmetics.price(skin) then
				ProfileClient.buy(skin.id)
			end
		end)
		refs.SkinCards[skin.id] = { button = button, card = card }
	end

	sectionTitle(scroll, "COIN PACKS", 4)
	refs.PackNote = body(scroll, "", { LayoutOrder = 5, Size = UDim2.new(1, -14, 0, 48) })
	local packRow = new("Frame", {
		Size = UDim2.new(1, -14, 0, 150),
		BackgroundTransparency = 1,
		LayoutOrder = 6,
		Parent = scroll,
	}, { Theme.list(Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Left) })
	refs.PackRow = packRow
end

pageRefreshers.Locker = function()
	local data = ProfileClient.get()
	for _, skin in Cosmetics.Skins do
		local entry = refs.SkinCards[skin.id]
		local button = entry.button :: TextButton
		local owned = data ~= nil and data.owned ~= nil and data.owned[skin.id] == true
		local equipped = data ~= nil and data.equipped ~= nil and data.equipped.skin == skin.id
		local price = Cosmetics.price(skin)
		if equipped then
			button.Text = "EQUIPPED"
			button.BackgroundColor3 = C.Good
			button.TextColor3 = C.Ink
		elseif owned then
			button.Text = "EQUIP"
			button.BackgroundColor3 = C.PanelLight
			button.TextColor3 = C.Text
		elseif price then
			local canAfford = data ~= nil and (data.coins or 0) >= price
			button.Text = `◉ {price}`
			button.BackgroundColor3 = if canAfford then C.Accent else C.PanelLight
			button.TextColor3 = if canAfford then C.Ink else C.TextDim
		else
			button.Text = "🔒 " .. Cosmetics.unlockText(skin)
			button.BackgroundColor3 = C.Ink
			button.TextColor3 = C.TextDim
		end
	end
	-- Coin packs
	local packRow = refs.PackRow :: Frame
	for _, child in packRow:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local packs = (data and data.packs) or {}
	local anyAvailable = false
	for i, pack in packs do
		anyAvailable = anyAvailable or pack.available
		local card = Theme.panel({ Size = UDim2.fromOffset(280, 150), LayoutOrder = i, Parent = packRow })
		Theme.label({
			Text = pack.name,
			Size = UDim2.new(1, -24, 0, 30),
			Position = UDim2.fromOffset(12, 12),
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Theme.Fonts.Bold,
			Outline = false,
			Parent = card,
		})
		Theme.label({
			Text = `◉ {formatNumber(pack.coins)}`,
			Size = UDim2.new(1, -24, 0, 36),
			Position = UDim2.fromOffset(12, 44),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.Gold,
			FontFace = Theme.Fonts.Display,
			Parent = card,
		})
		local button = Theme.button(
			if pack.available then "BUY" else "COMING SOON",
			if pack.available then "Primary" else "Ghost",
			{
				Size = UDim2.new(1, -24, 0, 44),
				Position = UDim2.new(0, 12, 1, -56),
				Parent = card,
			}
		)
		button.Active = pack.available == true
		if pack.available then
			button.Activated:Connect(function()
				ProfileClient.buyPack(pack.key)
			end)
		end
	end
	refs.PackNote.Text = if anyAvailable
		then "Coins are also earned by playing: eliminations, finishing matches, wins and challenges."
		else "Coins are earned by playing: eliminations, finishing matches, wins and challenges. Coin packs are not on sale yet."
end

pageBuilders.Profile = function(page)
	local top = Theme.panel({ Size = UDim2.new(1, 0, 0, 170), Parent = page })
	refs.ProfileName = Theme.label({
		Text = player.DisplayName,
		Size = UDim2.fromOffset(600, 50),
		Position = UDim2.fromOffset(28, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Display,
		Parent = top,
	})
	refs.ProfileLevel = body(top, "", {
		Position = UDim2.fromOffset(30, 80),
		Size = UDim2.fromOffset(600, 26),
		TextColor3 = C.Text,
		FontFace = Theme.Fonts.Bold,
	})
	local _, fill = progressBar(top, { Size = UDim2.new(1, -60, 0, 14), Position = UDim2.fromOffset(30, 120) })
	refs.ProfileXpFill = fill

	local statsPanel =
		Theme.panel({ Size = UDim2.new(0.5, -10, 0, 380), Position = UDim2.fromOffset(0, 190), Parent = page })
	Theme.label({
		Text = "CAREER",
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.fromOffset(24, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Display,
		Parent = statsPanel,
	})
	local grid = new("Frame", {
		Size = UDim2.new(1, -48, 1, -80),
		Position = UDim2.fromOffset(24, 66),
		BackgroundTransparency = 1,
		Parent = statsPanel,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -8, 0, 64),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	refs.StatCells = {}
	for i, key in { "Eliminations", "K/D", "Wins", "Matches", "Headshots", "Double pumps", "Assists", "Accuracy" } do
		local cell = new(
			"Frame",
			{ BackgroundColor3 = C.PanelLight, BackgroundTransparency = 0.3, LayoutOrder = i, Parent = grid },
			{ Theme.corner(8) }
		)
		Theme.label({
			Text = key:upper(),
			Size = UDim2.new(1, -20, 0, 18),
			Position = UDim2.fromOffset(10, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.TextDim,
			FontFace = Theme.Fonts.Bold,
			Outline = false,
			Parent = cell,
		})
		refs.StatCells[key] = Theme.label({
			Text = "0",
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.fromOffset(10, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Theme.Fonts.Heavy,
			Outline = false,
			Parent = cell,
		})
	end

	local right = new("Frame", {
		Size = UDim2.new(0.5, -10, 0, 380),
		Position = UDim2.new(0.5, 10, 0, 190),
		BackgroundTransparency = 1,
		Parent = page,
	})
	local mastery = Theme.panel({ Size = UDim2.new(1, 0, 0, 120), Parent = right })
	Theme.label({
		Text = "PUMP SHOTGUN MASTERY",
		Size = UDim2.new(1, -40, 0, 34),
		Position = UDim2.fromOffset(24, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Display,
		Parent = mastery,
	})
	refs.MasteryText =
		body(mastery, "", { Position = UDim2.fromOffset(26, 52), Size = UDim2.new(1, -52, 0, 24), TextColor3 = C.Text })
	local _, mfill =
		progressBar(mastery, { Size = UDim2.new(1, -52, 0, 12), Position = UDim2.fromOffset(26, 88) }, C.Gold)
	refs.MasteryFill = mfill

	local challenges =
		Theme.panel({ Size = UDim2.new(1, 0, 0, 244), Position = UDim2.fromOffset(0, 136), Parent = right })
	Theme.label({
		Text = "CHALLENGES",
		Size = UDim2.new(0.6, 0, 0, 34),
		Position = UDim2.fromOffset(24, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Display,
		Parent = challenges,
	})
	local toggleButton = Theme.button("DAILY", "Secondary", {
		Size = UDim2.fromOffset(140, 34),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 14),
		Parent = challenges,
	})
	refs.ChallengeKind = "daily"
	toggleButton.Activated:Connect(function()
		refs.ChallengeKind = if refs.ChallengeKind == "daily" then "weekly" else "daily"
		toggleButton.Text = string.upper(refs.ChallengeKind)
		pageRefreshers.Profile()
	end)
	refs.ChallengeList = new("Frame", {
		Size = UDim2.new(1, -48, 1, -64),
		Position = UDim2.fromOffset(24, 58),
		BackgroundTransparency = 1,
		Parent = challenges,
	}, { Theme.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Left) })
end

pageRefreshers.Profile = function()
	local data = ProfileClient.get()
	if not data then
		refs.ProfileLevel.Text = "Loading profile..."
		return
	end
	local info = Levels.fromXp(data.xp or 0)
	refs.ProfileLevel.Text = if info.isMax
		then `Level {info.level} (max)`
		else `Level {info.level}  ·  {formatNumber(info.into)} / {formatNumber(info.need)} XP`
	refs.ProfileXpFill.Size = UDim2.fromScale(if info.isMax then 1 else info.into / info.need, 1)
	local s = data.stats or {}
	local kills, deaths = s.kills or 0, s.deaths or 0
	local cells = refs.StatCells
	cells["Eliminations"].Text = formatNumber(kills)
	cells["K/D"].Text = string.format("%.2f", kills / math.max(1, deaths))
	cells["Wins"].Text = formatNumber(s.wins or 0)
	cells["Matches"].Text = formatNumber(s.matches or 0)
	cells["Headshots"].Text = formatNumber(s.headshots or 0)
	cells["Double pumps"].Text = formatNumber(s.doublePumps or 0)
	cells["Assists"].Text = formatNumber(s.assists or 0)
	cells["Accuracy"].Text =
		string.format("%d%%", math.round(100 * (s.pelletsHit or 0) / math.max(1, s.pelletsFired or 0)))

	local m = Levels.mastery(data.masteryKills or 0)
	local prevAt = if m.tier > 0 then Levels.Mastery[m.tier].kills else 0
	if m.nextAt then
		refs.MasteryText.Text = `{m.name}  ·  {m.kills} / {m.nextAt} eliminations to {Levels.Mastery[m.tier + 1].name}`
		refs.MasteryFill.Size = UDim2.fromScale((m.kills - prevAt) / (m.nextAt - prevAt), 1)
	else
		refs.MasteryText.Text = `{m.name}  ·  {formatNumber(m.kills)} eliminations`
		refs.MasteryFill.Size = UDim2.fromScale(1, 1)
	end

	local list = refs.ChallengeList :: Frame
	for _, child in list:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local set = data[refs.ChallengeKind]
	if not set then
		return
	end
	for i, entry in set.entries or {} do
		local rowFrame = new("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = C.PanelLight,
			BackgroundTransparency = 0.4,
			LayoutOrder = i,
			Parent = list,
		}, { Theme.corner(8) })
		Theme.label({
			Text = (if entry.done then "✓  " else "") .. entry.text,
			Size = UDim2.new(0.62, 0, 0, 20),
			Position = UDim2.fromOffset(12, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if entry.done then C.Good else C.Text,
			FontFace = Theme.Fonts.Bold,
			Outline = false,
			Parent = rowFrame,
		})
		Theme.label({
			Text = `+{entry.xp} XP  ◉ {entry.coins}`,
			Size = UDim2.new(0.34, 0, 0, 18),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 5),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = C.Gold,
			FontFace = Theme.Fonts.Bold,
			Outline = false,
			Parent = rowFrame,
		})
		local _, fill = progressBar(
			rowFrame,
			{ Size = UDim2.new(1, -24, 0, 8), Position = UDim2.new(0, 12, 1, -14) },
			if entry.done then C.Good else C.Accent
		)
		fill.Size = UDim2.fromScale(math.clamp(entry.progress / math.max(1, entry.goal), 0, 1), 1)
	end
	Theme.label({
		Text = `New {refs.ChallengeKind} challenges in {formatDuration(set.secondsLeft or 0)}`,
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.TextDim,
		FontFace = Theme.Fonts.Body,
		Outline = false,
		LayoutOrder = 99,
		Parent = list,
	})
end

pageBuilders.Leaderboards = function(page)
	local tabs = new(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, Parent = page },
		{ Theme.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left) }
	)
	refs.BoardTabs = tabs
	refs.BoardList = Theme.panel({ Size = UDim2.new(1, 0, 1, -70), Position = UDim2.fromOffset(0, 66), Parent = page })
	refs.BoardKey = "Kills"
	refs.BoardData = nil
	refs.BoardFetchedAt = -math.huge
end

local function drawBoard()
	local panel = refs.BoardList :: Frame
	for _, child in panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local data = refs.BoardData
	if not data then
		body(panel, "Loading leaderboards...", { Position = UDim2.fromOffset(24, 24), Size = UDim2.new(1, -48, 0, 30) })
		return
	end
	if data.unavailable then
		body(
			panel,
			data.note or "Leaderboards are not available here (they need a published place with DataStores).",
			{ Position = UDim2.fromOffset(24, 24), Size = UDim2.new(1, -48, 0, 60) }
		)
		return
	end
	local board
	for _, b in data.boards or {} do
		if b.key == refs.BoardKey then
			board = b
		end
	end
	if not board then
		return
	end
	local list = new("Frame", {
		Size = UDim2.new(1, -48, 1, -40),
		Position = UDim2.fromOffset(24, 20),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Theme.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left) })
	if #board.entries == 0 then
		body(list, "No entries yet. Be the first.", {})
	end
	for i, entry in board.entries do
		if i > 12 then
			break
		end
		local mine = entry.userId == player.UserId
		local rowFrame = new("Frame", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = if mine then C.AccentDark else C.PanelLight,
			BackgroundTransparency = if mine then 0.3 else 0.55,
			LayoutOrder = i,
			Parent = list,
		}, { Theme.corner(6) })
		local rankColor = if i == 1
			then C.Gold
			elseif i == 2 then Color3.fromRGB(200, 205, 215)
			elseif i == 3 then Color3.fromRGB(205, 127, 50)
			else C.TextDim
		Theme.label({
			Text = `#{entry.rank}`,
			Size = UDim2.fromOffset(70, 26),
			Position = UDim2.fromOffset(12, 7),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = rankColor,
			FontFace = Theme.Fonts.Heavy,
			Outline = false,
			Parent = rowFrame,
		})
		Theme.label({
			Text = entry.name,
			Size = UDim2.new(0.6, 0, 0, 26),
			Position = UDim2.fromOffset(90, 7),
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Theme.Fonts.Bold,
			Outline = false,
			Parent = rowFrame,
		})
		Theme.label({
			Text = formatNumber(entry.value),
			Size = UDim2.fromOffset(200, 26),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 7),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = C.Text,
			FontFace = Theme.Fonts.Heavy,
			Outline = false,
			Parent = rowFrame,
		})
	end
end

local function drawBoardTabs()
	local tabs = refs.BoardTabs :: Frame
	for _, child in tabs:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local data = refs.BoardData
	for i, b in (data and data.boards) or {} do
		local selected = b.key == refs.BoardKey
		local button = Theme.button(
			b.title,
			if selected then "Primary" else "Secondary",
			{ Size = UDim2.fromOffset(220, 46), LayoutOrder = i, Parent = tabs }
		)
		button.Activated:Connect(function()
			refs.BoardKey = b.key
			drawBoardTabs()
			drawBoard()
		end)
	end
end

pageRefreshers.Leaderboards = function()
	if os.clock() - refs.BoardFetchedAt < 30 then
		return
	end
	refs.BoardFetchedAt = os.clock()
	drawBoard()
	task.spawn(function()
		local result = ProfileClient.leaderboards()
		refs.BoardData = result or { unavailable = true }
		drawBoardTabs()
		drawBoard()
	end)
end

pageBuilders.Settings = function(page)
	SettingsPanel.build(page)
end

pageBuilders.Tutorial = function(page)
	local panel = Theme.panel({ Size = UDim2.new(1, 0, 0, 520), Parent = page })
	local list = new("Frame", {
		Size = UDim2.new(1, -60, 1, -40),
		Position = UDim2.fromOffset(30, 24),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Theme.list(Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Left) })
	sectionTitle(list, "THE DOUBLE PUMP", 1)
	local lines = {
		"You carry two identical pump shotguns. Each one has its own shells and its own pump cooldown.",
		"After a shot, the gun you fired needs about a second to pump. The other gun is ready almost immediately.",
		"Fire, switch, fire. Do it yourself: switching is always your own key press, nothing is automatic.",
		"Headshots do 1.75x damage. Pellets lose damage with distance, so get close.",
		"Eliminate an enemy with both guns in quick succession for a DOUBLE PUMP.",
	}
	for i, line in lines do
		body(
			list,
			`{i}.  {line}`,
			{ LayoutOrder = i + 1, Size = UDim2.new(1, 0, 0, 52), TextSize = 22, TextColor3 = C.Text }
		)
	end
	local start =
		Theme.button("START TUTORIAL", "Primary", { Size = UDim2.fromOffset(320, 64), LayoutOrder = 10, Parent = list })
	start.Activated:Connect(function()
		if MainMenu.onStartTutorial then
			MainMenu.onStartTutorial()
		end
	end)
end

---------------------------------------------------------------------------------------
-- Frame

local NAV = {
	{ key = "Play", text = "PLAY" },
	{ key = "Locker", text = "LOCKER" },
	{ key = "Profile", text = "PROFILE" },
	{ key = "Leaderboards", text = "LEADERBOARDS" },
	{ key = "Settings", text = "SETTINGS" },
	{ key = "Tutorial", text = "HOW TO PLAY" },
}

function MainMenu.show(page: string)
	if not pages[page] then
		local frame =
			new("Frame", { Name = page, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content })
		pages[page] = frame
		pageBuilders[page](frame)
	end
	currentPage = page
	for key, frame in pages do
		frame.Visible = key == page
	end
	for key, button in navButtons do
		local selected = key == page
		button.BackgroundColor3 = if selected then C.Accent else C.Panel
		button.TextColor3 = if selected then C.Ink else C.Text
	end
	local refresh = pageRefreshers[page]
	if refresh then
		refresh()
	end
end

local function updateTopBar()
	local data = ProfileClient.get()
	if not data then
		refs.Level.Text = "–"
		refs.Coins.Text = "◉ –"
		return
	end
	local info = Levels.fromXp(data.xp or 0)
	refs.Level.Text = tostring(info.level)
	refs.XpFill.Size = UDim2.fromScale(if info.isMax then 1 else info.into / info.need, 1)
	refs.Coins.Text = `◉ {formatNumber(data.coins or 0)}`
end

function MainMenu.open(page: string?)
	MainMenu.isOpen = true
	gui.Enabled = true
	local inGame = MatchClient.mode() ~= "Menu"
	refs.Leave.Visible = inGame
	refs.Close.Visible = inGame
	MainMenu.show(page or (if inGame then currentPage else "Play"))
	updateTopBar()
	local first = navButtons[currentPage]
	if first and InputController.LastInputKind == "Gamepad" then
		GuiService.SelectedObject = first
	end
end

function MainMenu.close()
	MainMenu.isOpen = false
	gui.Enabled = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
end

function MainMenu.start()
	gui, root = UIRoot.screen("MainMenu", 30)
	gui.Enabled = false

	-- Dark wash so text reads over the scenic camera
	new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = root,
	}, { new("UIGradient", { Transparency = NumberSequence.new(0, 0.55), Rotation = 0 }) })

	local side = new("Frame", {
		Name = "Side",
		Size = UDim2.new(0, 400, 1, 0),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local logo = Theme.label({
		Text = "DOUBLE\nPUMP",
		Size = UDim2.fromOffset(340, 190),
		Position = UDim2.fromOffset(48, 48),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Display,
		TextColor3 = C.Accent,
		Outline = 3,
		Parent = side,
	})
	new("UIGradient", { Color = ColorSequence.new(C.Gold, C.Accent), Rotation = 90, Parent = logo })
	local nav = new("Frame", {
		Size = UDim2.fromOffset(320, 460),
		Position = UDim2.fromOffset(48, 270),
		BackgroundTransparency = 1,
		Parent = side,
	}, { Theme.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Left) })
	for i, item in NAV do
		local button = Theme.button(item.text, "Ghost", {
			Size = UDim2.fromOffset(300, 58),
			LayoutOrder = i,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = nav,
		})
		button.Activated:Connect(function()
			MainMenu.show(item.key)
		end)
		navButtons[item.key] = button
	end
	local leave =
		Theme.button("LEAVE TO MENU", "Danger", { Size = UDim2.fromOffset(300, 54), LayoutOrder = 20, Parent = nav })
	leave.Activated:Connect(function()
		Net.event("PlayerAction"):FireServer("Menu")
	end)
	refs.Leave = leave

	-- Top bar: level badge, XP, coins, close
	local topBar = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 36),
		Size = UDim2.fromOffset(560, 64),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local badge = new(
		"Frame",
		{ Size = UDim2.fromOffset(64, 64), BackgroundColor3 = C.Accent, Parent = topBar },
		{ Theme.corner(32), Theme.stroke(C.AccentDark, 3) }
	)
	refs.Level = Theme.label({
		Text = "1",
		Size = UDim2.fromScale(0.7, 0.6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		TextColor3 = C.Ink,
		FontFace = Theme.Fonts.Display,
		Outline = false,
		Parent = badge,
	})
	Theme.label({
		Text = player.DisplayName,
		Size = UDim2.fromOffset(240, 28),
		Position = UDim2.fromOffset(78, 2),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Bold,
		Parent = topBar,
	})
	local _, xpFill = progressBar(topBar, { Size = UDim2.fromOffset(240, 10), Position = UDim2.fromOffset(78, 40) })
	refs.XpFill = xpFill
	refs.Coins = Theme.label({
		Text = "◉ 0",
		Size = UDim2.fromOffset(150, 34),
		Position = UDim2.fromOffset(330, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Gold,
		FontFace = Theme.Fonts.Heavy,
		Parent = topBar,
	})
	local close = Theme.button("✕", "Ghost", {
		Size = UDim2.fromOffset(56, 56),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Parent = topBar,
	})
	close.Activated:Connect(function()
		MainMenu.close()
	end)
	refs.Close = close

	content = new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(440, 130),
		Size = UDim2.new(1, -480, 1, -170),
		BackgroundTransparency = 1,
		Parent = root,
	})

	ProfileClient.Changed:Connect(function()
		updateTopBar()
		if MainMenu.isOpen then
			local refresh = pageRefreshers[currentPage]
			if refresh then
				refresh()
			end
		end
	end)
	MatchClient.StateChanged:Connect(function()
		if MainMenu.isOpen and currentPage == "Play" then
			pageRefreshers.Play()
		end
	end)
	InputController.InputKindChanged:Connect(function()
		if MainMenu.isOpen and currentPage == "Play" then
			pageRefreshers.Play()
		end
	end)
end

return MainMenu
