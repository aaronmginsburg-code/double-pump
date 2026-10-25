--!strict
-- Development-only handshake after the ordinary initial profile response settles.
if game.GameId ~= 10772492892 or game.PlaceId ~= 139437092998076 then
	return
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local client = Players.LocalPlayer.PlayerScripts:WaitForChild("Client")
local profile = require(client.Controllers.ProfileClient)
while not profile.loaded() do
	task.wait(0.1)
end
local ready = ReplicatedStorage:WaitForChild("DevelopmentSkinReady") :: RemoteEvent
ready:FireServer()
