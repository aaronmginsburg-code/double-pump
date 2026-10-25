--!strict
-- Explicit owner-authorized skin access in the isolated private development universe.
local Identity = require(script.Parent.DevelopmentIdentity)
if not Identity.allowed(game.GameId, game.PlaceId) then
	warn("[Double Pump DEV] Skin override refused: this is not the development experience")
	return
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local server = script.Parent:WaitForChild("Server")
local services = server:WaitForChild("Services")
local DataService = require(services.DataService)
local Progression = require(services.ProgressionService)
local Cosmetics = require(ReplicatedStorage.Shared.Progression.Cosmetics)
local Net = require(ReplicatedStorage.Shared.Net)
local function grant(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	DataService.update(player, function(profile)
		for _, skin in Cosmetics.Skins do
			profile.owned[skin.id] = true
		end
	end)
	-- Use the existing snapshot/remote, without depending on Progression.start order.
	Net.event("ProfileEvent"):FireClient(player, "Profile", Progression.snapshot(data))
	print("[Double Pump DEV] All " .. #Cosmetics.Skins .. " skins available to " .. player.Name)
end
DataService.Loaded:Connect(function(player: Player)
	task.defer(grant, player)
end)
for _, player in Players:GetPlayers() do
	task.defer(grant, player)
end

local ready = Instance.new("RemoteEvent")
ready.Name = "DevelopmentSkinReady"
ready.OnServerEvent:Connect(grant)
ready.Parent = ReplicatedStorage
