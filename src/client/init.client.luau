-- Client entry point: sets up the HUD and guns, then runs them every frame.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Hud = require(script.Hud)
local Viewmodel = require(script.Viewmodel)
local Weapons = require(script.Weapons)

local player = Players.LocalPlayer

-- Hide Roblox's default backpack bar and health bar; we draw our own
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

Hud.init()
Viewmodel.init()
Weapons.start()

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	local _, humanoid = Weapons.getAliveCharacter()

	Weapons.update()
	Viewmodel.update(camera, Weapons.state, humanoid ~= nil)
	Hud.update(camera, humanoid, Weapons.state)
end)

print(`Double Pump client started for {player.Name}`)
