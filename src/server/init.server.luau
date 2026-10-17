local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

print(`Double Pump server started. Kill target: {Config.Round.KillTarget}`)
