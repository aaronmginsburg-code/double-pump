-- Server side of stances and aiming.
-- Clients tell us their stance and whether they're aiming; we sanity-check it
-- and store it as attributes on the character, which every client can read:
--   Stance = "Stand" | "Crouch" | "Prone" | "Slide" | "Dive"
--   Aiming = true | false
-- We also pose every character here so the server's copy of each body part
-- (used for hit checks) matches what players see.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Pose = require(ReplicatedStorage.Shared.Pose)

local Remotes = ReplicatedStorage.Remotes
local MoveConfig = Config.Movement

local Movement = {}

local VALID_STANCES = { Stand = true, Crouch = true, Prone = true, Slide = true, Dive = true }

-- Slides and dives have cooldowns. One used too soon is downgraded to the
-- plain stance it ends in (a slide becomes a crouch, a dive becomes prone).
local MOVES = {
	Slide = { cooldown = MoveConfig.SlideCooldown, fallback = "Crouch" },
	Dive = { cooldown = MoveConfig.DiveCooldown, fallback = "Prone" },
}
local lastUsed: { [Player]: { [string]: number } } = {}

local function onStance(player: Player, stance: any)
	local character = player.Character
	if typeof(stance) ~= "string" or not VALID_STANCES[stance] or not character then
		return
	end

	local move = MOVES[stance]
	if move then
		local now = os.clock()
		local used = lastUsed[player] or {}
		lastUsed[player] = used
		local tooSoon = now - (used[stance] or -math.huge) < move.cooldown - Config.Weapon.ServerTimingTolerance
		if tooSoon then
			stance = move.fallback
		else
			used[stance] = now
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
		lastUsed[player] = nil
	end)

	RunService.Stepped:Connect(function(_, deltaTime)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				local stance = character:GetAttribute("Stance") or "Stand"
				Pose.step(character, stance, deltaTime, false, true, character:GetAttribute("Aiming") == true)
			end
		end
	end)
end

return Movement
