--!strict
-- Shown while waiting to respawn: who eliminated you, how, and a respawn timer.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local UIRoot = require(script.Parent.UIRoot)
local MatchClient = require(script.Parent.Parent.Controllers.MatchClient)

local DeathScreen = {}

local player = Players.LocalPlayer
local C = Theme.Colors
local new = Theme.new

local gui: ScreenGui
local title: TextLabel
local killerLabel: TextLabel
local detail: TextLabel
local barFill: Frame
local timerLabel: TextLabel
local respawnAt = 0
local respawnDelay = 1

function DeathScreen.hide()
	gui.Enabled = false
end

function DeathScreen.showFor(delay: number)
	respawnDelay = math.max(0.1, delay)
	respawnAt = os.clock() + delay
	gui.Enabled = true
end

function DeathScreen.start()
	local root
	gui, root = UIRoot.screen("DeathScreen", 15)
	gui.Enabled = false
	new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(60, 0, 10),
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Parent = root,
	})
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.fromOffset(640, 210),
		BackgroundTransparency = 1,
		Parent = root,
	})
	title = Theme.label({
		Text = "ELIMINATED",
		Size = UDim2.new(1, 0, 0, 70),
		TextColor3 = C.Hot,
		FontFace = Theme.Fonts.Display,
		Outline = 3,
		Parent = card,
	})
	killerLabel = Theme.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 74),
		FontFace = Theme.Fonts.Heavy,
		Parent = card,
	})
	detail = Theme.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 118),
		TextColor3 = C.TextDim,
		FontFace = Theme.Fonts.Bold,
		Parent = card,
	})
	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 162),
		Size = UDim2.fromOffset(360, 10),
		BackgroundColor3 = C.Ink,
		Parent = card,
	}, { Theme.corner(5) })
	barFill = new(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Text, Parent = bar },
		{ Theme.corner(5) }
	)
	timerLabel = Theme.label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 178),
		Size = UDim2.fromOffset(360, 24),
		TextColor3 = C.TextDim,
		FontFace = Theme.Fonts.Bold,
		Parent = card,
	})

	MatchClient.Elimination:Connect(function(data)
		if data.victimUserId ~= player.UserId then
			return
		end
		if data.killer ~= "" and data.killerUserId ~= player.UserId then
			title.Text = "ELIMINATED"
			killerLabel.Text = `by {data.killer}`
			killerLabel.TextColor3 = Theme.teamColor(data.killerTeam)
			detail.Text = if data.doublePump then "Double pumped." elseif data.headshot then "Headshot." else ""
		else
			title.Text = "YOU DIED"
			killerLabel.Text = ""
			detail.Text = ""
		end
	end)
	MatchClient.Respawning:Connect(function(data)
		DeathScreen.showFor(data.delay or 2.5)
	end)
	RunService.RenderStepped:Connect(function()
		if not gui.Enabled then
			return
		end
		local left = respawnAt - os.clock()
		barFill.Size = UDim2.fromScale(math.clamp(1 - left / respawnDelay, 0, 1), 1)
		timerLabel.Text = if left > 0 then string.format("Respawning in %.1f", left) else "Respawning..."
	end)
end

return DeathScreen
