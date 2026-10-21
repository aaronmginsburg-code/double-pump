--!strict
-- Hold Tab / Select: both teams side by side, sorted by score. Columns read from the
-- per-player attributes the server keeps up to date.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local UIRoot = require(script.Parent.UIRoot)
local MatchClient = require(script.Parent.Parent.Controllers.MatchClient)

local Scoreboard = {}

local player = Players.LocalPlayer
local C = Theme.Colors
local new = Theme.new

local gui: ScreenGui
local columns: { [string]: Frame } = {}
local headers: { [string]: TextLabel } = {}
local footer: TextLabel
local lastDraw = 0

local COLS = {
	{ key = "Kills", title = "E", width = 60 },
	{ key = "Deaths", title = "D", width = 60 },
	{ key = "Assists", title = "A", width = 60 },
	{ key = "DoublePumps", title = "DP", width = 60 },
	{ key = "Score", title = "SCORE", width = 100 },
}

local function attr(p: Player, key: string): number
	local v = p:GetAttribute(key)
	return if typeof(v) == "number" then v else 0
end

local function buildColumn(parent: Instance, team: string, x: number)
	local panel = Theme.panel({
		Name = team,
		Size = UDim2.new(0.5, -10, 1, 0),
		Position = UDim2.new(x, if x > 0 then 10 else 0, 0, 0),
		Parent = parent,
	})
	new(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Theme.teamColor(team), BorderSizePixel = 0, Parent = panel },
		{ Theme.corner(4) }
	)
	headers[team] = Theme.label({
		Text = team:upper(),
		Size = UDim2.new(0.6, 0, 0, 44),
		Position = UDim2.fromOffset(20, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.teamColor(team),
		FontFace = Theme.Fonts.Display,
		Parent = panel,
	})
	local head = new(
		"Frame",
		{
			Size = UDim2.new(1, -40, 0, 24),
			Position = UDim2.fromOffset(20, 70),
			BackgroundTransparency = 1,
			Parent = panel,
		}
	)
	local right = 0
	for i = #COLS, 1, -1 do
		local col = COLS[i]
		Theme.label({
			Text = col.title,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -right, 0, 0),
			Size = UDim2.new(0, col.width, 1, 0),
			TextColor3 = C.TextDim,
			FontFace = Theme.Fonts.Bold,
			Outline = false,
			Parent = head,
		})
		right += col.width
	end
	local list = new("Frame", {
		Size = UDim2.new(1, -40, 1, -110),
		Position = UDim2.fromOffset(20, 100),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Theme.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left) })
	columns[team] = list
end

local function draw()
	local scores = { Red = MatchClient.get("RedScore") or 0, Blue = MatchClient.get("BlueScore") or 0 }
	for team, list in columns do
		headers[team].Text = `{team:upper()}  {scores[team]}`
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local members = {}
		for _, p in Players:GetPlayers() do
			if p.Team and p.Team.Name == team then
				table.insert(members, p)
			end
		end
		table.sort(members, function(a, b)
			local sa, sb = attr(a, "Score"), attr(b, "Score")
			if sa ~= sb then
				return sa > sb
			end
			return a.UserId < b.UserId
		end)
		for i, p in members do
			local mine = p == player
			local alive = p.Character ~= nil and p.Character:GetAttribute("Dead") ~= true
			local row = new("Frame", {
				Size = UDim2.new(1, 0, 0, 46),
				BackgroundColor3 = if mine then Theme.teamColor(team) else C.PanelLight,
				BackgroundTransparency = if mine then 0.55 else 0.5,
				LayoutOrder = i,
				Parent = list,
			}, { Theme.corner(6) })
			Theme.label({
				Text = p.DisplayName,
				Size = UDim2.new(1, -330, 0, 26),
				Position = UDim2.fromOffset(12, 10),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTransparency = if alive then 0 else 0.45,
				FontFace = Theme.Fonts.Bold,
				Outline = false,
				Parent = row,
			})
			local right = 0
			for c = #COLS, 1, -1 do
				local col = COLS[c]
				Theme.label({
					Text = tostring(attr(p, col.key)),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -right, 0, 10),
					Size = UDim2.fromOffset(col.width, 26),
					FontFace = if col.key == "Score" then Theme.Fonts.Heavy else Theme.Fonts.Bold,
					Outline = false,
					Parent = row,
				})
				right += col.width
			end
		end
	end
	local others = {}
	for _, p in Players:GetPlayers() do
		if not p.Team then
			table.insert(others, p.DisplayName)
		end
	end
	local mapName = MatchClient.get("MapName") or ""
	footer.Text = (if mapName ~= "" then mapName .. "   ·   " else "")
		.. (if #others > 0 then "Not in match: " .. table.concat(others, ", ") else "")
end

function Scoreboard.setVisible(on: boolean)
	gui.Enabled = on
	if on then
		draw()
	end
end

function Scoreboard.start()
	local root
	gui, root = UIRoot.screen("Scoreboard", 25)
	gui.Enabled = false
	local frame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1300, 620),
		BackgroundTransparency = 1,
		Parent = root,
	})
	buildColumn(frame, "Red", 0)
	buildColumn(frame, "Blue", 0.5)
	footer = Theme.label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 12),
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = C.TextDim,
		FontFace = Theme.Fonts.Bold,
		Parent = frame,
	})
	RunService.Heartbeat:Connect(function()
		if gui.Enabled and os.clock() - lastDraw > 0.5 then
			lastDraw = os.clock()
			draw()
		end
	end)
end

return Scoreboard
