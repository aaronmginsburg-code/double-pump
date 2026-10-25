--!strict
-- Decides what the local player is looking at: menu, first-person combat, death cam,
-- or the postgame screens. Every other controller just does its job; this one switches
-- them on and off as the player's mode, character and the match state change.

local Players = game:GetService("Players")

local Controllers = script.Parent
local UI = script.Parent.Parent.UI
local CameraController = require(Controllers.CameraController)
local InputController = require(Controllers.InputController)
local WeaponController = require(Controllers.WeaponController)
local ViewmodelController = require(Controllers.ViewmodelController)
local MatchClient = require(Controllers.MatchClient)
local AudioController = require(Controllers.AudioController)
local MovementController = require(Controllers.MovementController)
local Hud = require(UI.Hud)
local MainMenu = require(UI.MainMenu)
local DeathScreen = require(UI.DeathScreen)
local Scoreboard = require(UI.Scoreboard)
local Postgame = require(UI.Postgame)
local MobileControls = require(UI.MobileControls)

local ActionCues = require(game:GetService("ReplicatedStorage").Shared.Audio.ActionCues)

local GameFlow = {}
GameFlow.feedbackOpen = false

local player = Players.LocalPlayer
local releaseCursor: (() -> ())? = nil
local lastKiller: Model? = nil
local alignedCharacter: Model? = nil
local alignedRevision: any = nil
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" })

local function alive(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return character ~= nil
		and humanoid ~= nil
		and humanoid.Health > 0
		and typeof(character:GetAttribute("SpawnCFrame")) == "CFrame"
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
	local feedbackOpen = GameFlow.feedbackOpen
	local menuOpen = MainMenu.isOpen or feedbackOpen
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
		end
		local character = player.Character :: Model
		local revision = character:GetAttribute("SpawnRevision")
		if alignedCharacter ~= character or alignedRevision ~= revision then
			CameraController.lookAlong(character:GetAttribute("SpawnCFrame") :: CFrame)
			alignedCharacter = character
			alignedRevision = revision
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
	WeaponController.active = InputController.combatEnabled
	if not InputController.combatEnabled then
		InputController.releaseAll()
	end
	ViewmodelController.setEnabled(playing and not feedbackOpen)
	MobileControls.setActive(InputController.combatEnabled)
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
			ActionCues.ambience(mode, MatchClient.myTeam() ~= nil, MatchClient.state(), ambience)
		)
	end
end

function GameFlow.toggleMenu()
	if GameFlow.feedbackOpen then return end
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
	if watched[character] then
		return
	end
	watched[character] = true
	lastKiller = nil
	local function suppressDefaultDeath(child: Instance)
		if child:IsA("Sound") and child.Name == "Died" and AudioController.configured("Death") then
			child.Volume = 0
		end
	end
	for _, child in character:GetDescendants() do
		suppressDefaultDeath(child)
	end
	character.DescendantAdded:Connect(suppressDefaultDeath)
	character:GetAttributeChangedSignal("SpawnCFrame"):Connect(GameFlow.refresh)
	character:GetAttributeChangedSignal("SpawnRevision"):Connect(GameFlow.refresh)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Once(function()
			if player.Character ~= character then
				return
			end
			AudioController.play("Death")
			GameFlow.refresh()
		end)
	end
	-- Entering play from the menu closes it
	if MainMenu.isOpen and MatchClient.mode() ~= "Menu" then
		MainMenu.close()
	end
	if player.Character == character and humanoid and humanoid.Health > 0 then
		AudioController.play("Spawn")
	end
	GameFlow.refresh()
end

function GameFlow.start()
	-- Arena replication can arrive after phase/team attributes; retry bed selection
	-- when the model or its cue attribute becomes available, without another timer.
	local function watchArena(child: Instance)
		if child.Name ~= "Arena" then
			return
		end
		child:GetAttributeChangedSignal("Ambience"):Connect(GameFlow.refresh)
		task.defer(GameFlow.refresh)
	end
	workspace.ChildAdded:Connect(watchArena)
	workspace.ChildRemoved:Connect(function(child)
		if child.Name == "Arena" then
			GameFlow.refresh()
		end
	end)
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		watchArena(arena)
	end
	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(function()
		task.defer(GameFlow.refresh)
	end)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player:GetAttributeChangedSignal("Mode"):Connect(function()
		if MatchClient.mode() ~= "Menu" and MainMenu.isOpen then
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
	-- Closing the menu with its ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ button
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
