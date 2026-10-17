-- Server entry point: builds the test room, spawns dummies, starts the guns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Arena = require(script.Arena)
local Dummies = require(script.Dummies)
local Movement = require(script.Movement)
local Weapons = require(script.Weapons)

Players.RespawnTime = Config.Player.RespawnTime

Arena.build()
Weapons.start()
Movement.start()
Dummies.spawnAll()

print("Double Pump feel test server started")
