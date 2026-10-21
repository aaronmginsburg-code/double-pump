--!strict
-- Decides what the local player is looking at: menu, first-person combat, death cam,
-- or the postgame screens. Every other controller just does its job; this one switches
-- them on and off as the player's mode, character and the match state change.

local Players = game:GetService("Players")

local Controllers = script.Parent
local UI = script.Parent.Parent.UI
local CameraController = require(Controllers.CameraController)
local InputController = require(Controllers.InputController)
local ViewmodelController = require(Controllers.ViewmodelController)
local MatchClient = require(Controllers.MatchClient)
local AudioController = require(Controllers.AudioController)
local MovementController = require(Controllers.MovementController)
local Hud = require(UI.Hud)
local MainMenu = require(UI.MainMenu)
local DeathScreen = require(UI.DeathScreen)
local Scoreboard = require(UI.Scoreboard)
local Postgame = require(UI.Postgame)

local GameFlow = {}

local player = Players.LocalPlayer
local releaseCursor: (() -> ())? = nil
local lastKiller: Model? = nil

local function alive(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function postgame(): boolean
	local state = MatchClient.state()
	return MatchClient.myTeam() ~= nil and (state == "Results" or state == "Voting")
end

local function scenicTarget(): (Vector3, number)
	local arena = workspace:FindFirstChild("Arena")
	local markers = arena and arena:FindFirstChild("Markers")
	local cam = markers and markers:FindFirstChild("Camera") :: BasePart?
	if cam then
		return cam.Position + cam.CFrame.LookVector * 40, 70
	end
	local range = workspace:FindFirstChild("Range")
	local rangeMarkers = range and range:FindFirstChild("Markers")
	local rangeCam = rangeMarkers and rangeMarkers:FindFirstChild("Camera") :: BasePart?
	if rangeCam then
		return rangeCam.Position + rangeCam.CFrame.LookVector * 40, 60
	end
	return Vector3.new(0, 10, 0), 60
end

-- Re-evaluates everything. Cheap; called on any relevant change.
function GameFlow.refresh()
	local mode = MatchClient.mode()
	local menuOpen = MainMenu.isOpen
	local isAlive = alive()
	local inPostgame = postgame()
	local playing = mode ~= "Menu" and isAlive and not inPostgame

	if mode == "Menu" and not menuOpen then
		MainMenu.open("Play")
		menuOpen = true
	end

	-- Camera
	if playing then
		if CameraController.mode ~= "Combat" then
			CameraController.setCombat()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				CameraController.lookAlong(root.CFrame)
			end
		end
	elseif mode ~= "Menu" and not isAlive and not inPostgame then
		if CameraController.mode ~= "Dead" then
			CameraController.setDead(player.Character, lastKiller)
		end
	else
		local center, radius = scenicTarget()
		CameraController.setScenic(center, radius)
	end

	-- Input, viewmodel, HUD
	InputController.combatEnabled = playing and not menuOpen
	if not InputController.combatEnabled then
		InputController.releaseAll()
	end
	ViewmodelController.setEnabled(playing)
	Hud.setVisible(mode ~= "Menu" and not inPostgame and not menuOpen)
	if isAlive or mode == "Menu" or inPostgame then
		DeathScreen.hide()
	end
	if menuOpen and mode ~= "Menu" then
		if not releaseCursor then
			releaseCursor = CameraController.requestCursor()
		end
	elseif releaseCursor then
		releaseCursor()
		releaseCursor = nil
	end
	if not playing then
		MovementController.setCrouch(false)
	end

	-- Sound bed: menu music in the menu, map ambience in the arena
	if mode == "Menu" then
		AudioController.setMusic("MusicMenu")
		AudioController.setAmbience(nil)
	else
		AudioController.setMusic(nil)
		local arena = workspace:FindFirstChild("Arena")
		local ambience = arena and arena:GetAttribute("Ambience")
		AudioController.setAmbience(
			if MatchClient.myTeam() and typeof(ambience) == "string" and ambience ~= "" then ambience else nil
		)
	end
end

function GameFlow.toggleMenu()
	if MatchClient.mode() == "Menu" then
		return -- the menu is the screen; nothing to close to
	end
	if MainMenu.isOpen then
		MainMenu.close()
	else
		MainMenu.open()
	end
	GameFlow.refresh()
end

local function onCharacter(character: Model)
	lastKiller = nil
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(function()
			AudioController.play("Death")
			GameFlow.refresh()
		end)
	end
	-- Entering play from the menu closes it
	if MainMenu.isOpen and MatchClient.mode() ~= "Menu" then
		MainMenu.close()
	end
	AudioController.play("Spawn")
	GameFlow.refresh()
end

function GameFlow.start()
	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(function()
		task.defer(GameFlow.refresh)
	end)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player:GetAttributeChangedSignal("Mode"):Connect(function()
		if MatchClient.mode() ~= "Menu" and MainMenu.isOpen and not alive() then
			-- Waiting for the spawn: close the menu now so the transition is immediate
			MainMenu.close()
		end
		GameFlow.refresh()
	end)
	player:GetPropertyChangedSignal("Team"):Connect(GameFlow.refresh)
	MatchClient.StateChanged:Connect(GameFlow.refresh)
	MatchClient.Elimination:Connect(function(data)
		if data.victimUserId == player.UserId and data.killerUserId ~= 0 then
			local killer = Players:GetPlayerByUserId(data.killerUserId)
			lastKiller = killer and killer.Character
		end
	end)
	InputController.Action:Connect(function(action, pressed)
		if action == "Menu" and pressed then
			GameFlow.toggleMenu()
		elseif action == "Scoreboard" then
			Scoreboard.setVisible(pressed and MatchClient.myTeam() ~= nil and not MainMenu.isOpen and not postgame())
		end
	end)
	-- Closing the menu with its ✕ button
	local wasOpen = MainMenu.isOpen
	game:GetService("RunService").Heartbeat:Connect(function()
		if MainMenu.isOpen ~= wasOpen then
			wasOpen = MainMenu.isOpen
			GameFlow.refresh()
		end
	end)
	Postgame.hide()
	GameFlow.refresh()
end

return GameFlow
