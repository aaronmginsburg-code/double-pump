--!strict
-- Red and Blue teams: assignment, balancing, and the Team objects Roblox replicates
-- (so player.Team works everywhere, including friendly-fire checks).

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local TeamBalance = require(Shared.Match.TeamBalance)

local Actors = require(script.Parent.Participants)
local TrainingPolicy = require(Shared.Training.Policy)
local TeamService = {}

local teamObjects: { [string]: Team } = {}

function TeamService.team(name: string): Team
	return teamObjects[name]
end

function TeamService.members(name: string): { Player }
	local list = {}
	local team = teamObjects[name]
	for _, player in Actors.all() do
		if team and TeamService.teamOf(player) == name then
			table.insert(list, player)
		end
	end
	return list
end

function TeamService.teamOf(player: Player): string?
	if Actors.isBot(player) then
		return player.team
	end
	local team = player.Team
	if team == teamObjects.Red then
		return "Red"
	elseif team == teamObjects.Blue then
		return "Blue"
	end
	return nil
end

local function snapshot()
	return { Red = TeamService.members("Red"), Blue = TeamService.members("Blue") }
end

local function setTeam(player: Player, name: string?)
	if Actors.isBot(player) then
		player.team = name
	else
		player.Team = (if name then teamObjects[name] else nil) :: any
		player.Neutral = name == nil
	end
	local character = Actors.character(player)
	if character then
		character:SetAttribute("Team", name)
	end
end

-- Puts a player on the team that needs them. Returns the team name, or nil if full.
function TeamService.assign(player: Player, scores: { [string]: number }?): string?
	local current = TeamService.teamOf(player)
	if current then
		return current
	end
	local name = TeamBalance.pick(snapshot(), scores, GameConfig.Match.MaxTeamSize)
	if name then
		setTeam(player, name)
	end
	return name
end

function TeamService.clear(player: Player)
	setTeam(player, nil)
end

-- Fresh, even teams for a new match from the given players (shuffled).
function TeamService.reshuffle(players: { Player })
	local bots = {}
	for _, p in players do
		if Actors.isBot(p) then
			table.insert(bots, p)
		end
	end
	if #bots > 0 then
		table.sort(players, function(a, b)
			return Actors.sortKey(a) < Actors.sortKey(b)
		end)
		local assignment = TrainingPolicy.teams(players, bots[1].owner, bots, GameConfig.Match.MaxTeamSize)
		assert(assignment, "Invalid training roster")
		Actors.trainingRound = true
		for _, p in Actors.all() do
			setTeam(p, assignment[p])
		end
		return
	end
	Actors.trainingRound = false
	local list = table.clone(players)
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	for _, p in Actors.all() do
		if not table.find(list, p) then
			setTeam(p, nil)
		end
	end
	local split = TeamBalance.split(list)
	for name, members in split do
		for _, p in members do
			setTeam(p, name)
		end
	end
end

-- Called when a player is about to respawn: if the teams are lopsided and this player
-- is on the bigger team, move them. Returns true if they moved.
function TeamService.rebalance(player: Player): boolean
	if Actors.trainingRound then
		return false
	end
	local from, to = TeamBalance.needsMove(snapshot(), GameConfig.Teams.RebalanceGap)
	if from and to and TeamService.teamOf(player) == from then
		setTeam(player, to)
		return true
	end
	return false
end

function TeamService.start()
	for _, name in { "Red", "Blue" } do
		local cfg = (GameConfig.Teams :: any)[name]
		local team = Teams:FindFirstChild(name) :: Team?
		if not team then
			local t = Instance.new("Team")
			t.Name = name
			t.Parent = Teams
			team = t
		end
		assert(team, "team missing")
		team.TeamColor = BrickColor.new(cfg.BrickColor)
		team.AutoAssignable = false
		teamObjects[name] = team
	end
end

return TeamService
