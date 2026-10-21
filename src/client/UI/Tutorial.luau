--!strict
-- Interactive tutorial in the practice range. Each step waits for the player to do the
-- thing (fire, switch, reload, crouch, double pump). Skippable at any time; finishing or
-- skipping marks it done in the profile so it isn't offered again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local WeaponConfig = require(Shared.Config.WeaponConfig)

local Theme = require(script.Parent.Theme)
local UIRoot = require(script.Parent.UIRoot)
local Controllers = script.Parent.Parent.Controllers
local WeaponController = require(Controllers.WeaponController)
local InputController = require(Controllers.InputController)
local AudioController = require(Controllers.AudioController)
local Settings = require(Controllers.Settings)

local Tutorial = {}

local C = Theme.Colors
local new = Theme.new

local gui: ScreenGui
local panel: Frame
local stepLabel: TextLabel
local textLabel: TextLabel
local hintLabel: TextLabel
local dots: { Frame } = {}
local step = 0
local active = false
local connections: { any } = {}

type Step = { text: string, keys: { Keyboard: string, Gamepad: string, Touch: string } }

local STEPS: { Step } = {
	{ text = "Shoot a target.", keys = { Keyboard = "Left mouse button", Gamepad = "R2", Touch = "FIRE button" } },
	{
		text = "Switch to your other shotgun.",
		keys = { Keyboard = "Press 2 or Q", Gamepad = "R1 or L1", Touch = "SWAP button" },
	},
	{
		text = "Double pump: hit a target, switch, and hit it again within a second.",
		keys = { Keyboard = "Click, Q, click", Gamepad = "R2, R1, R2", Touch = "FIRE, SWAP, FIRE" },
	},
	{
		text = "Reload. Shells go in one at a time; firing or switching stops the reload.",
		keys = { Keyboard = "R", Gamepad = "X", Touch = "RELOAD button" },
	},
	{
		text = "Crouch. It tightens your spread a little but slows you down.",
		keys = { Keyboard = "C or Left Ctrl", Gamepad = "B", Touch = "CROUCH button" },
	},
	{
		text = "Eliminate a target with a double pump.",
		keys = {
			Keyboard = "Close range, aim high",
			Gamepad = "Close range, aim high",
			Touch = "Close range, aim high",
		},
	},
}

local function disconnectAll()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
end

local function render()
	local s = STEPS[step]
	if not s then
		return
	end
	stepLabel.Text = `STEP {step} OF {#STEPS}`
	textLabel.Text = s.text
	hintLabel.Text = (s.keys :: any)[InputController.LastInputKind] or s.keys.Keyboard
	for i, dot in dots do
		dot.BackgroundColor3 = if i < step then C.Good elseif i == step then C.Accent else C.PanelLight
	end
	local scale = panel:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.9
	Theme.tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function finish(completed: boolean)
	active = false
	disconnectAll()
	Settings.set("tutorialDone", true)
	Net.event("SettingsAction"):FireServer("TutorialDone")
	if completed then
		stepLabel.Text = "TUTORIAL COMPLETE"
		textLabel.Text = "You're ready. Press PLAY in the menu (M) when you want a real match."
		hintLabel.Text = ""
		AudioController.play("LevelUp")
		task.delay(5, function()
			if not active then
				gui.Enabled = false
			end
		end)
	else
		gui.Enabled = false
	end
end

local function advance(from: number)
	if not active or step ~= from then
		return
	end
	AudioController.play("Reward")
	step += 1
	if step > #STEPS then
		finish(true)
	else
		render()
	end
end

function Tutorial.isActive(): boolean
	return active
end

function Tutorial.begin()
	disconnectAll()
	active = true
	step = 1
	gui.Enabled = true
	Net.event("PlayerAction"):FireServer("Practice")
	render()

	local lastFiredSlot = 1
	local lastHit: { slot: number, time: number }? = nil
	table.insert(
		connections,
		WeaponController.Fired:Connect(function(info)
			lastFiredSlot = info.slot
			advance(1)
		end)
	)
	table.insert(
		connections,
		WeaponController.Equipped:Connect(function(_slot, _previous, isSpawn)
			if not isSpawn then
				advance(2)
			end
		end)
	)
	table.insert(
		connections,
		WeaponController.HitConfirmed:Connect(function(results)
			local now = os.clock()
			local landed = false
			for _, r in results do
				if not r.protected then
					landed = true
				end
				if r.killed and r.doublePump then
					advance(6)
				end
			end
			if not landed then
				return
			end
			if
				lastHit
				and lastHit.slot ~= lastFiredSlot
				and now - lastHit.time <= WeaponConfig.DoublePumpWindow + 0.2
			then
				advance(3)
			end
			lastHit = { slot = lastFiredSlot, time = now }
		end)
	)
	table.insert(
		connections,
		WeaponController.ReloadStarted:Connect(function()
			advance(4)
		end)
	)
	table.insert(
		connections,
		InputController.Action:Connect(function(action, pressed)
			if action == "Crouch" and pressed then
				advance(5)
			end
		end)
	)
	table.insert(connections, InputController.InputKindChanged:Connect(render))
	-- The mouse is locked while aiming, so skipping also works from the keyboard/pad
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and (input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.ButtonY) then
				Tutorial.skip()
			end
		end)
	)
end

function Tutorial.skip()
	if active then
		finish(false)
	end
end

function Tutorial.start()
	local root
	gui, root = UIRoot.screen("Tutorial", 18)
	gui.Enabled = false
	panel = Theme.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(760, 168),
		BackgroundTransparency = 0.12,
		Parent = root,
	})
	new("UIScale", { Parent = panel })
	stepLabel = Theme.label({
		Text = "",
		Size = UDim2.fromOffset(400, 24),
		Position = UDim2.fromOffset(24, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Accent,
		FontFace = Theme.Fonts.Heavy,
		Outline = false,
		Parent = panel,
	})
	textLabel = Theme.label({
		Text = "",
		Size = UDim2.new(1, -48, 0, 60),
		Position = UDim2.fromOffset(24, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		FontFace = Theme.Fonts.Bold,
		Parent = panel,
	})
	hintLabel = Theme.label({
		Text = "",
		Size = UDim2.new(0.6, 0, 0, 26),
		Position = UDim2.fromOffset(24, 112),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Gold,
		FontFace = Theme.Fonts.Heavy,
		Outline = false,
		Parent = panel,
	})
	local dotRow = new(
		"Frame",
		{
			Size = UDim2.fromOffset(200, 12),
			Position = UDim2.new(1, -224, 0, 22),
			BackgroundTransparency = 1,
			Parent = panel,
		},
		{ Theme.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right) }
	)
	for i = 1, #STEPS do
		dots[i] = new(
			"Frame",
			{ Size = UDim2.fromOffset(24, 10), BackgroundColor3 = C.PanelLight, LayoutOrder = i, Parent = dotRow },
			{ Theme.corner(5) }
		)
	end
	local skip = Theme.button(
		"SKIP  [Backspace]",
		"Ghost",
		{
			Size = UDim2.fromOffset(220, 40),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -20, 1, -16),
			Parent = panel,
		}
	)
	skip.Activated:Connect(Tutorial.skip)
end

return Tutorial
