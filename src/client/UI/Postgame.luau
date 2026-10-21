--!strict
-- End of match: the result (victory / defeat / draw), MVP, the full scoreboard and your
-- rewards; then map voting with live vote counts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local AssetIds = require(Shared.Config.AssetIds)
local Levels = require(Shared.Progression.Levels)

local Theme = require(script.Parent.Theme)
local UIRoot = require(script.Parent.UIRoot)
local Controllers = script.Parent.Parent.Controllers
local MatchClient = require(Controllers.MatchClient)
local ProfileClient = require(Controllers.ProfileClient)
local AudioController = require(Controllers.AudioController)

local Postgame = {}

local player = Players.LocalPlayer
local C = Theme.Colors
local new = Theme.new

local gui: ScreenGui
local root: Frame
local resultsFrame: Frame
local votingFrame: Frame
local rewardPanel: Frame
local voteCards: { [string]: { frame: TextButton, count: TextLabel, stroke: UIStroke } } = {}
local myVote: string? = nil
local votingEndsAt = 0
local votingTimer: TextLabel

-- Fallback card colours when map art hasn't been uploaded yet.
local MAP_COLORS: { [string]: { Color3 } } = {
	Warehouse = { Color3.fromRGB(70, 82, 100), Color3.fromRGB(26, 30, 40) },
	DustTown = { Color3.fromRGB(214, 160, 96), Color3.fromRGB(110, 70, 40) },
	Rooftops = { Color3.fromRGB(90, 120, 200), Color3.fromRGB(30, 30, 70) },
}

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function hideAll()
	resultsFrame.Visible = false
	votingFrame.Visible = false
end

function Postgame.hide()
	gui.Enabled = false
	hideAll()
end

---------------------------------------------------------------------------------------
-- Results

local function showResults(data: any)
	gui.Enabled = true
	hideAll()
	resultsFrame.Visible = true
	clear(resultsFrame)

	local myTeam = MatchClient.myTeam()
	local winner = data.winner
	local headline, color
	if winner == nil or winner == "" then
		headline, color = "DRAW", C.Text
	elseif myTeam == nil then
		headline, color = `{string.upper(winner)} WINS`, Theme.teamColor(winner)
	elseif winner == myTeam then
		headline, color = "VICTORY", C.Gold
	else
		headline, color = "DEFEAT", C.Hot
	end
	if myTeam then
		AudioController.play(
			if headline == "VICTORY" then "Victory" elseif headline == "DEFEAT" then "Defeat" else "MatchEnd"
		)
	else
		AudioController.play("MatchEnd")
	end

	local title = Theme.label({
		Text = headline,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(900, 120),
		TextColor3 = color,
		FontFace = Theme.Fonts.Display,
		Outline = 4,
		Parent = resultsFrame,
	})
	local scale = new("UIScale", { Scale = 1.6, Parent = title }) :: UIScale
	Theme.tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	local scores = data.scores or {}
	Theme.label({
		Text = `<font color="#{Theme.teamColor("Red"):ToHex()}">{scores.Red or 0}</font>  –  <font color="#{Theme
			.teamColor("Blue")
			:ToHex()}">{scores.Blue or 0}</font>`,
		RichText = true,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.fromOffset(400, 56),
		FontFace = Theme.Fonts.Display,
		Parent = resultsFrame,
	})
	local reasonText = if data.reason == "Draw"
		then "Still tied after overtime"
		elseif data.reason == "Overtime" then "Decided in overtime"
		elseif data.reason == "NotEnoughPlayers" then "Ended early: not enough players"
		else nil
	if reasonText then
		Theme.label({
			Text = reasonText,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 216),
			Size = UDim2.fromOffset(500, 26),
			TextColor3 = C.TextDim,
			FontFace = Theme.Fonts.Bold,
			Parent = resultsFrame,
		})
	end

	-- MVP card
	local mvpCard = Theme.panel({
		Position = UDim2.fromOffset(120, 270),
		Size = UDim2.fromOffset(380, 300),
		Parent = resultsFrame,
	})
	Theme.label({
		Text = "MVP",
		Size = UDim2.new(1, 0, 0, 46),
		Position = UDim2.fromOffset(0, 18),
		TextColor3 = C.Gold,
		FontFace = Theme.Fonts.Display,
		Parent = mvpCard,
	})
	if data.mvp then
		local thumb = new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 72),
			Size = UDim2.fromOffset(130, 130),
			BackgroundColor3 = Theme.teamColor(data.mvp.team),
			Image = "",
			Parent = mvpCard,
		}, { Theme.corner(65) })
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(
					data.mvp.userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size150x150
				)
			end)
			if ok then
				thumb.Image = image
			end
		end)
		Theme.label({
			Text = data.mvp.name,
			Size = UDim2.new(1, -30, 0, 36),
			Position = UDim2.fromOffset(15, 214),
			TextColor3 = Theme.teamColor(data.mvp.team),
			FontFace = Theme.Fonts.Heavy,
			Parent = mvpCard,
		})
		for _, row in data.board or {} do
			if row.userId == data.mvp.userId then
				Theme.label({
					Text = `{row.kills} elims  ·  {row.doublePumps} double pumps`,
					Size = UDim2.new(1, -30, 0, 24),
					Position = UDim2.fromOffset(15, 254),
					TextColor3 = C.TextDim,
					FontFace = Theme.Fonts.Bold,
					Outline = false,
					Parent = mvpCard,
				})
			end
		end
	else
		Theme.label({
			Text = "–",
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 130),
			Parent = mvpCard,
		})
	end

	-- Scoreboard table
	local tablePanel = Theme.panel({
		Position = UDim2.fromOffset(530, 270),
		Size = UDim2.new(1, -1060, 0, 560),
		Parent = resultsFrame,
	})
	local cols = {
		{ key = "kills", title = "E" },
		{ key = "deaths", title = "D" },
		{ key = "assists", title = "A" },
		{ key = "headshots", title = "HS" },
		{ key = "doublePumps", title = "DP" },
		{ key = "damage", title = "DMG" },
		{ key = "accuracy", title = "ACC" },
		{ key = "score", title = "SCORE" },
	}
	local colWidth = 74
	local head = new(
		"Frame",
		{
			Size = UDim2.new(1, -40, 0, 26),
			Position = UDim2.fromOffset(20, 16),
			BackgroundTransparency = 1,
			Parent = tablePanel,
		}
	)
	for i, col in cols do
		Theme.label({
			Text = col.title,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -(#cols - i) * colWidth, 0, 0),
			Size = UDim2.new(0, colWidth, 1, 0),
			TextColor3 = C.TextDim,
			FontFace = Theme.Fonts.Bold,
			Outline = false,
			Parent = head,
		})
	end
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, -40, 1, -60),
		Position = UDim2.fromOffset(20, 48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = tablePanel,
	}, { Theme.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left) })
	local board = table.clone(data.board or {})
	table.sort(board, function(a: any, b: any)
		if a.team ~= b.team then
			return (a.team or "") == (winner or "Red")
		end
		return a.score > b.score
	end)
	for i, row in board do
		local mine = row.userId == player.UserId
		local r = new(
			"Frame",
			{
				Size = UDim2.new(1, -8, 0, 44),
				BackgroundColor3 = Theme.teamColor(row.team),
				BackgroundTransparency = if mine then 0.45 else 0.8,
				LayoutOrder = i,
				Parent = list,
			},
			{ Theme.corner(6) }
		)
		Theme.label({
			Text = row.name,
			Size = UDim2.new(1, -(#cols * colWidth) - 20, 0, 26),
			Position = UDim2.fromOffset(12, 9),
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Theme.Fonts.Bold,
			Outline = false,
			Parent = r,
		})
		for c, col in cols do
			local v = row[col.key] or 0
			local text = if col.key == "accuracy" then string.format("%d%%", math.round(v * 100)) else tostring(v)
			Theme.label({
				Text = text,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -(#cols - c) * colWidth, 0, 9),
				Size = UDim2.fromOffset(colWidth, 26),
				FontFace = if col.key == "score" then Theme.Fonts.Heavy else Theme.Fonts.Bold,
				Outline = false,
				Parent = r,
			})
		end
	end

	-- Rewards (filled when the server sends them)
	rewardPanel = Theme.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -120, 0, 270),
		Size = UDim2.fromOffset(380, 300),
		Parent = resultsFrame,
	})
	Theme.label({
		Text = "REWARDS",
		Size = UDim2.new(1, 0, 0, 46),
		Position = UDim2.fromOffset(0, 18),
		FontFace = Theme.Fonts.Display,
		Parent = rewardPanel,
	})
	Theme.label({
		Name = "Pending",
		Text = if myTeam then "Calculating..." else "Play a match to earn XP",
		Size = UDim2.new(1, -30, 0, 24),
		Position = UDim2.fromOffset(15, 120),
		TextColor3 = C.TextDim,
		FontFace = Theme.Fonts.Bold,
		Outline = false,
		Parent = rewardPanel,
	})
end

local function showReward(reward: any)
	if not rewardPanel or not rewardPanel.Parent then
		return
	end
	local pending = rewardPanel:FindFirstChild("Pending")
	if pending then
		pending:Destroy()
	end
	local list = new(
		"Frame",
		{
			Size = UDim2.new(1, -40, 1, -80),
			Position = UDim2.fromOffset(20, 70),
			BackgroundTransparency = 1,
			Parent = rewardPanel,
		},
		{ Theme.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left) }
	)
	local function line(order: number, left: string, right: string, color: Color3?)
		local row = new(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = order, Parent = list }
		)
		Theme.label({
			Text = left,
			Size = UDim2.fromScale(0.65, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.TextDim,
			FontFace = Theme.Fonts.Bold,
			Outline = false,
			Parent = row,
		})
		Theme.label({
			Text = right,
			Size = UDim2.fromScale(0.35, 1),
			Position = UDim2.fromScale(0.65, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = color or C.Text,
			FontFace = Theme.Fonts.Heavy,
			Outline = false,
			Parent = row,
		})
	end
	for i, item in reward.breakdown or {} do
		line(i, item.label, `+{item.xp} XP`)
	end
	for i, ch in reward.challenges or {} do
		line(20 + i, "✓ " .. ch.text, `+{ch.xp} XP`, C.Good)
	end
	line(50, "Total", `+{reward.xp} XP`, C.Accent)
	line(51, "Coins", `◉ {reward.coins}`, C.Gold)
	if reward.idle then
		line(52, "Inactive: no match bonus", "", C.Hot)
	end
	if reward.levelAfter and reward.levelBefore and reward.levelAfter > reward.levelBefore then
		line(53, "LEVEL UP!", `{reward.levelAfter}`, C.Gold)
		AudioController.play("LevelUp")
	else
		AudioController.play("Reward")
	end
	local info = Levels.fromXp(reward.totalXp or 0)
	local bar = new(
		"Frame",
		{
			Size = UDim2.new(1, -40, 0, 10),
			Position = UDim2.new(0, 20, 1, -24),
			BackgroundColor3 = C.Ink,
			Parent = rewardPanel,
		},
		{ Theme.corner(5) }
	)
	local fill = new(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent, Parent = bar },
		{ Theme.corner(5) }
	)
	Theme.tween(fill, 0.8, { Size = UDim2.fromScale(if info.isMax then 1 else info.into / info.need, 1) })
end

---------------------------------------------------------------------------------------
-- Voting

local function showVoting(data: any)
	gui.Enabled = true
	hideAll()
	votingFrame.Visible = true
	clear(votingFrame)
	voteCards = {}
	myVote = nil
	votingEndsAt = os.clock() + (data.duration or 12)

	Theme.label({
		Text = "VOTE FOR THE NEXT MAP",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(1000, 80),
		FontFace = Theme.Fonts.Display,
		Outline = 3,
		Parent = votingFrame,
	})
	votingTimer = Theme.label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 170),
		Size = UDim2.fromOffset(400, 34),
		TextColor3 = C.TextDim,
		FontFace = Theme.Fonts.Bold,
		Parent = votingFrame,
	})
	local row = new(
		"Frame",
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.56),
			Size = UDim2.fromOffset(1500, 520),
			BackgroundTransparency = 1,
			Parent = votingFrame,
		},
		{
			new(
				"UIListLayout",
				{
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 30),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}
			),
		}
	)
	for i, option in data.options or {} do
		local colors = MAP_COLORS[option.id] or { C.PanelLight, C.Panel }
		local card = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(460, 520),
			BackgroundColor3 = colors[1],
			LayoutOrder = i,
			Parent = row,
		}, { Theme.corner(16), new("UIGradient", { Color = ColorSequence.new(colors[1], colors[2]), Rotation = 90 }) }) :: TextButton
		local stroke = Theme.stroke(C.Stroke, 3)
		stroke.Parent = card
		local image = (AssetIds.Images :: any)["Map" .. option.id]
		if image and image ~= "" then
			new(
				"ImageLabel",
				{
					Size = UDim2.new(1, 0, 0, 300),
					BackgroundTransparency = 1,
					Image = image,
					ScaleType = Enum.ScaleType.Crop,
					Parent = card,
				},
				{ Theme.corner(16) }
			)
		else
			Theme.label({
				Text = string.upper(option.name),
				Size = UDim2.new(1, -40, 0, 120),
				Position = UDim2.fromOffset(20, 90),
				TextTransparency = 0.75,
				FontFace = Theme.Fonts.Display,
				Outline = false,
				Parent = card,
			})
		end
		local info = new(
			"Frame",
			{
				Size = UDim2.new(1, 0, 0, 220),
				Position = UDim2.new(0, 0, 1, -220),
				BackgroundColor3 = C.Ink,
				BackgroundTransparency = 0.15,
				Parent = card,
			},
			{ Theme.corner(16) }
		)
		Theme.label({
			Text = option.name,
			Size = UDim2.new(1, -40, 0, 50),
			Position = UDim2.fromOffset(20, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Theme.Fonts.Display,
			Parent = info,
		})
		Theme.label({
			Text = option.description,
			Size = UDim2.new(1, -40, 0, 70),
			Position = UDim2.fromOffset(20, 70),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextScaled = false,
			TextSize = 19,
			TextWrapped = true,
			TextColor3 = C.TextDim,
			FontFace = Theme.Fonts.Body,
			Outline = false,
			Parent = info,
		})
		local count = Theme.label({
			Text = "0 votes",
			Size = UDim2.new(1, -40, 0, 34),
			Position = UDim2.new(0, 20, 1, -50),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.Accent,
			FontFace = Theme.Fonts.Heavy,
			Parent = info,
		})
		card.Activated:Connect(function()
			myVote = option.id
			Net.event("PlayerAction"):FireServer("Vote", option.id)
			AudioController.play("Vote")
			for id, entry in voteCards do
				entry.stroke.Color = if id == myVote then C.Accent else C.Stroke
				entry.stroke.Thickness = if id == myVote then 6 else 3
			end
		end)
		voteCards[option.id] = { frame = card, count = count, stroke = stroke }
	end
end

local function showVoteCounts(counts: { [string]: number })
	for id, entry in voteCards do
		local n = counts[id] or 0
		entry.count.Text = if n == 1 then "1 vote" else `{n} votes`
	end
end

local function showVoteResult(data: any)
	for id, entry in voteCards do
		if id == data.mapId then
			entry.stroke.Color = C.Gold
			entry.stroke.Thickness = 8
			Theme.tween(entry.frame, 0.3, { Size = UDim2.fromOffset(490, 550) }, Enum.EasingStyle.Back)
		else
			Theme.tween(entry.frame, 0.3, { BackgroundTransparency = 0.6 })
		end
	end
	if votingTimer then
		votingTimer.Text = `Next map: {data.name}`
		votingTimer.TextColor3 = C.Gold
	end
end

function Postgame.start()
	gui, root = UIRoot.screen("Postgame", 20)
	gui.Enabled = false
	new(
		"Frame",
		{
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Parent = root,
		}
	)
	resultsFrame = new(
		"Frame",
		{ Name = "Results", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = root }
	)
	votingFrame = new(
		"Frame",
		{ Name = "Voting", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = root }
	)

	MatchClient.Ended:Connect(showResults)
	MatchClient.Voting:Connect(showVoting)
	MatchClient.VoteCounts:Connect(showVoteCounts)
	MatchClient.VoteResult:Connect(showVoteResult)
	ProfileClient.Reward:Connect(showReward)
	MatchClient.StateChanged:Connect(function(state)
		if state ~= "Results" and state ~= "Voting" then
			Postgame.hide()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if votingFrame.Visible and votingTimer and votingTimer.TextColor3 ~= C.Gold then
			local left = math.max(0, votingEndsAt - os.clock())
			votingTimer.Text = string.format("%d", math.ceil(left))
				.. (if myVote then "  ·  vote locked in" else "  ·  click a map")
		end
	end)
end

return Postgame
