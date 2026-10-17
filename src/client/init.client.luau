-- Client entry point: sets up the HUD, movement and guns, then runs them every frame.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local CameraController = require(script.CameraController)
local Hud = require(script.Hud)
local Movement = require(script.Movement)
local Viewmodel = require(script.Viewmodel)
local Weapons = require(script.Weapons)

local player = Players.LocalPlayer

-- Hide Roblox's default backpack bar and health bar; we draw our own
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

Hud.init()
Viewmodel.init()
Movement.start()
CameraController.start()
Weapons.start()

-- Runs every frame after the camera has moved (and after CameraController),
-- so the gun and HUD line up with what the camera sees this frame.
RunService:BindToRenderStep("DoublePump", Enum.RenderPriority.Camera.Value + 2, function(deltaTime)
	local camera = workspace.CurrentCamera
	local _, humanoid = Weapons.getAliveCharacter()

	Movement.update(deltaTime)
	Weapons.update()
	local aimAmount = Movement.state.aimAmount
	-- The first-person gun hides in third person (you see the one in your hands instead)
	local showViewmodel = humanoid ~= nil and not CameraController.isThirdPerson()
	Viewmodel.update(camera, Weapons.state, showViewmodel, aimAmount)
	Hud.update(camera, humanoid, Weapons.state, aimAmount)
end)

print(`Double Pump client started for {player.Name}`)
