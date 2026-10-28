--!strict
-- Client entry point. Starts controllers in dependency order, then the UI, then the
-- flow controller that switches between menu, combat and postgame.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Controllers = script.Controllers
local UI = script.UI

local Settings = require(Controllers.Settings)
local InputController = require(Controllers.InputController)
local CameraController = require(Controllers.CameraController)
local MovementController = require(Controllers.MovementController)
local WeaponController = require(Controllers.WeaponController)
local ViewmodelController = require(Controllers.ViewmodelController)
local AudioController = require(Controllers.AudioController)
local MovementAudio = require(Controllers.MovementAudio)
local EffectsController = require(Controllers.EffectsController)
local MatchClient = require(Controllers.MatchClient)
local ProfileClient = require(Controllers.ProfileClient)
local GameFlow = require(Controllers.GameFlow)

local Theme = require(UI.Theme)
local UIRoot = require(UI.UIRoot)
local Hud = require(UI.Hud)
local MainMenu = require(UI.MainMenu)
local Scoreboard = require(UI.Scoreboard)
local DeathScreen = require(UI.DeathScreen)
local Postgame = require(UI.Postgame)
local Tutorial = require(UI.Tutorial)
local Toasts = require(UI.Toasts)
local MobileControls = require(UI.MobileControls)
local SettingsPanel = require(UI.SettingsPanel)
local DebugOverlay = require(UI.DebugOverlay)

local player = Players.LocalPlayer

-- Roblox's own HUD pieces we replace
for _, coreType in { Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.PlayerList } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(coreType, false)
	end)
end
player.CameraMode = Enum.CameraMode.Classic

local function start(name: string, fn: (...any) -> ...any)
	local ok, err = pcall(fn)
	if not ok then
		warn(`[DoublePump] {name} failed to start: {err}`)
	end
end

start("UIRoot", UIRoot.start)
start("InputController", InputController.start)
start("CameraController", CameraController.start)
start("MovementController", MovementController.start)
start("AudioController", AudioController.start)
start("MovementAudio", MovementAudio.start)
start("WeaponController", WeaponController.start)
start("ViewmodelController", ViewmodelController.start)
start("EffectsController", EffectsController.start)
start("MatchClient", MatchClient.start)
start("ProfileClient", ProfileClient.start)

start("Toasts", Toasts.start)
start("Hud", Hud.start)
start("Scoreboard", Scoreboard.start)
start("DeathScreen", DeathScreen.start)
start("Postgame", Postgame.start)
start("Tutorial", Tutorial.start)
start("MainMenu", MainMenu.start)
start("MobileControls", MobileControls.start)
start("DebugOverlay", DebugOverlay.start)

-- Wiring between pieces
Theme.onClick = function()
	AudioController.play("UIClick")
end
Theme.onHover = function()
	AudioController.play("UIHover", { volume = 0.5 })
end
SettingsPanel.editTouchLayout = MobileControls.edit
MainMenu.onStartTutorial = function()
	MainMenu.close()
	Tutorial.begin()
end

local function applySettings()
	InputController.wheelSwitching = Settings.values.wheelSwitching
end
Settings.Changed:Connect(applySettings)
applySettings()

local settingsLoaded = false
ProfileClient.Changed:Connect(function(data)
	if not settingsLoaded then
		settingsLoaded = true
		Settings.apply(data.settings)
		if data.tutorialDone then
			Settings.values.tutorialDone = true
		else
			Toasts.show("New here? Open HOW TO PLAY for a 1-minute tutorial.", "info", 8)
		end
	end
end)
ProfileClient.onSkin(ViewmodelController.setSkin)
ProfileClient.Unlocked:Connect(function(item)
	Toasts.show(`Unlocked: {item.name}`, "reward", 5)
end)
MatchClient.Notify:Connect(function(text, kind)
	Toasts.show(text, kind)
end)
MatchClient.Starting:Connect(function(data)
	if MatchClient.myTeam() then
		Toasts.show(`Next match: {data.mapName or data.mapId}`, "info")
	end
end)

start("GameFlow", GameFlow.start)

-- Approved public aiming and trigger presentation; no developer UI or remotes.
start("AimAssist", require(Controllers.AimAssistController).start)
start("AutoFire", require(Controllers.AutoFireController).start)
