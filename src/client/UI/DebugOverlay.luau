--!strict
-- Performance overlay, toggled with F2.
-- Shows frame rate, frame time, ping, client memory, instance count and the weapon
-- state the client is predicting. Off by default; only reads numbers, changes nothing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local UIRoot = require(script.Parent.UIRoot)
local WeaponController = require(script.Parent.Parent.Controllers.WeaponController)

local DebugOverlay = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local label: TextLabel
local frames = 0
local frameTimeSum = 0
local worst = 0
local elapsed = 0

local function update(dt: number)
	frames += 1
	frameTimeSum += dt
	worst = math.max(worst, dt)
	elapsed += dt
	if elapsed < 0.5 then
		return
	end
	local fps = frames / elapsed
	local avg = frameTimeSum / frames * 1000
	local ping = player:GetNetworkPing() * 2000 -- round trip in ms
	local memory = Stats:GetTotalMemoryUsageMb()
	local s = WeaponController.state
	local lines = {
		string.format("FPS %.0f   frame %.1f ms   worst %.1f ms", fps, avg, worst * 1000),
		string.format("Ping %.0f ms   Memory %.0f MB   Instances %d", ping, memory, Stats.InstanceCount),
		string.format("Parts in workspace %d", Stats.PrimitivesCount),
	}
	if s then
		for i = 1, 2 do
			local v = WeaponController.view(i)
			table.insert(
				lines,
				string.format(
					"Gun %d%s  shells %d  ready in %.2fs%s",
					i,
					if s.equipped == i then "*" else " ",
					v.ammo,
					v.cooldownRemaining,
					if v.reloading then "  reloading" else ""
				)
			)
		end
	end
	label.Text = table.concat(lines, "\n")
	frames, frameTimeSum, worst, elapsed = 0, 0, 0, 0
end

function DebugOverlay.start()
	local root
	gui, root = UIRoot.screen("DebugOverlay", 100)
	gui.Enabled = false
	label = Theme.label({
		Text = "",
		Position = UDim2.fromOffset(16, 120),
		Size = UDim2.fromOffset(620, 150),
		TextScaled = false,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json"),
		BackgroundTransparency = 0.4,
		BackgroundColor3 = Color3.new(0, 0, 0),
		Parent = root,
	})
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F2 then
			gui.Enabled = not gui.Enabled
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if gui.Enabled then
			update(dt)
		end
	end)
end

return DebugOverlay
