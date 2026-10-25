--!strict
-- Client view of the match: mirrors ReplicatedStorage.MatchState attributes and turns
-- MatchEvent / CombatEvent messages into signals the UI listens to.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local MatchClient = {}

local player = Players.LocalPlayer
local folder: Folder

MatchClient.StateChanged = Signal.new() :: Signal.Signal<string>
MatchClient.Countdown = Signal.new() :: Signal.Signal<number>
MatchClient.Started = Signal.new() :: Signal.Signal<any>
MatchClient.Starting = Signal.new() :: Signal.Signal<any>
MatchClient.Ended = Signal.new() :: Signal.Signal<any>
MatchClient.Voting = Signal.new() :: Signal.Signal<any>
MatchClient.VoteCounts = Signal.new() :: Signal.Signal<{ [string]: number }>
MatchClient.VoteResult = Signal.new() :: Signal.Signal<any>
MatchClient.Respawning = Signal.new() :: Signal.Signal<any>
MatchClient.Elimination = Signal.new() :: Signal.Signal<any>
MatchClient.Damaged = Signal.new() :: Signal.Signal<any>
MatchClient.Notify = Signal.new() :: Signal.Signal<string, string?>

function MatchClient.get(name: string): any
	return folder and folder:GetAttribute(name)
end

function MatchClient.state(): string
	return MatchClient.get("State") or "Waiting"
end

function MatchClient.timeLeft(): number
	local endsAt = MatchClient.get("EndsAt")
	if typeof(endsAt) ~= "number" then
		return 0
	end
	return math.max(0, endsAt - workspace:GetServerTimeNow())
end

function MatchClient.myTeam(): string?
	local team = player.Team
	return if team then team.Name else nil
end

function MatchClient.mode(): string
	return (player:GetAttribute("Mode") :: string?) or "Menu"
end

function MatchClient.inCombat(): boolean
	local s = MatchClient.state()
	return s == "Active" or s == "Overtime"
end

function MatchClient.start()
	folder = ReplicatedStorage:WaitForChild("MatchState") :: Folder
	folder:GetAttributeChangedSignal("State"):Connect(function()
		MatchClient.StateChanged:Fire(MatchClient.state())
	end)

	Net.event("MatchEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Countdown" then
			MatchClient.Countdown:Fire(data)
		elseif kind == "Started" then
			MatchClient.Started:Fire(data)
		elseif kind == "Starting" then
			MatchClient.Starting:Fire(data)
		elseif kind == "Ended" then
			MatchClient.Ended:Fire(data)
		elseif kind == "Voting" then
			MatchClient.Voting:Fire(data)
		elseif kind == "VoteCounts" then
			MatchClient.VoteCounts:Fire(data)
		elseif kind == "VoteResult" then
			MatchClient.VoteResult:Fire(data)
		elseif kind == "Respawning" then
			MatchClient.Respawning:Fire(data)
		end
	end)
	Net.event("CombatEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Elimination" then
			MatchClient.Elimination:Fire(data)
		elseif kind == "Damaged" then
			MatchClient.Damaged:Fire(data)
		end
	end)
	Net.event("Notify").OnClientEvent:Connect(function(text: string, kind: string?)
		MatchClient.Notify:Fire(text, kind)
	end)
end

return MatchClient
