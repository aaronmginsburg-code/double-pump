--!strict
-- Server entry point: creates remotes and collision groups, then starts each service in
-- dependency order. Every service is a ModuleScript in Services/ with a start() function.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Collision = require(Shared.Collision)
local Net = require(Shared.Net)

Net.setupServer()
Collision.setup()

local Services = script.Services
local order = {
	"DeveloperTuningService",
	"MapService",
	"TeamService",
	"CharacterService",
	"DamageService",
	"CombatService",
	"PracticeService",
	"MatchService",
	"DataService",
	"ProgressionService",
	"CosmeticService",
	"MonetizationService",
	"LeaderboardService",
}

for _, name in order do
	local module = Services:FindFirstChild(name)
	if module then
		local service = require(module) :: any
		local ok, err = pcall(service.start)
		if not ok then
			warn(`[Double Pump] {name} failed to start: {err}`)
		end
	end
end

print("[Double Pump] server ready")
