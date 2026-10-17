-- Server side of crouch / slide / aim.
-- Clients tell us their stance and whether they're aiming; we sanity-check it
-- and store it as attributes on the character, which every client can read:
--   Stance = "Stand" | "Crouch" | "Slide"
--   Aiming = true | false
-- We also pose every character here so the server's copy of each body part
-- (used for hit checks) matches what players see.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Pose = require(ReplicatedStorage.Shared.Pose)

local Remotes = ReplicatedStorage.Remotes

local Movement = {}

local VALID_STANCES = { Stand = true, Crouch = true, Slide = true }
local lastSlideAt: { [Player]: number } = {}

local function onStance(player: Player, stance: any)
	local character = player.Character
	if typeof(stance) ~= "string" or not VALID_STANCES[stance] or not character then
		return
	end
	-- Slides have a cooldown; a slide too soon just counts as a crouch
	if stance == "Slide" then
		local now = os.clock()
		local tooSoon = now - (lastSlideAt[player] or -math.huge)
			< Config.Movement.SlideCooldown - Config.Weapon.ServerTimingTolerance
		if tooSoon then
			stance = "Crouch"
		else
			lastSlideAt[player] = now
		end
	end
	character:SetAttribute("Stance", stance)
end

local function onAim(player: Player, aiming: any)
	local character = player.Character
	if typeof(aiming) == "boolean" and character then
		character:SetAttribute("Aiming", aiming)
	end
end

function Movement.start()
	Remotes.Stance.OnServerEvent:Connect(onStance)
	Remotes.Aim.OnServerEvent:Connect(onAim)
	Players.PlayerRemoving:Connect(function(player)
		lastSlideAt[player] = nil
	end)

	RunService.Stepped:Connect(function(_, deltaTime)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				Pose.step(character, character:GetAttribute("Stance") or "Stand", deltaTime, false, true)
			end
		end
	end)
end

return Movement
