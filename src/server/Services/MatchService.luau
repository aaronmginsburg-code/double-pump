--!strict
-- Runs the game: who is playing, practice vs match, the team-deathmatch state machine
-- (MatchRules), spawning/respawning, scoring, map voting and map loading.
--
-- Player modes:
--   "Menu"     in the main menu, no character
--   "Match"    pressed Play: in the current match, or waiting in the range for one
--   "Practice" chose the range from the menu; never pulled into a match
--
-- Match state is replicated through attributes on ReplicatedStorage.MatchState so late
-- joiners see it immediately; one-off moments (countdown, results, voting) go through
-- the MatchEvent remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Combatants = require(Shared.Combatants)
local GameConfig = require(Shared.Config.GameConfig)
local MatchRules = require(Shared.Match.MatchRules)
local Net = require(Shared.Net)
local RateLimiter = require(Shared.Util.RateLimiter)
local Signal = require(Shared.Util.Signal)
local SpawnScoring = require(Shared.Match.SpawnScoring)
local VoteTally = require(Shared.Match.VoteTally)

local CharacterService = require(script.Parent.CharacterService)
local CombatService = require(script.Parent.CombatService)
local DamageService = require(script.Parent.DamageService)
local MapService = require(script.Parent.MapService)
local TeamService = require(script.Parent.TeamService)

local MatchService = {}

export type Mode = "Menu" | "Match" | "Practice"

export type PlayerStats = {
	kills: number,
	deaths: number,
	assists: number,
	headshots: number,
	doublePumps: number,
	damage: number,
	shots: number,
	pelletsFired: number,
	pelletsHit: number,
	score: number,
	joinedAt: number,
}

export type MatchResult = {
	winner: string?,
	reason: string,
	scores: { [string]: number },
	mapId: string?,
	mvp: Player?,
	participants: { [Player]: { team: string?, stats: PlayerStats, timePlayed: number } },
}

MatchService.MatchStarted = Signal.new() :: Signal.Signal<string>
MatchService.MatchEnded = Signal.new() :: Signal.Signal<MatchResult>
-- (killer, victimPlayer?, elimination) counted eliminations (not dummies, not suicides)
MatchService.Scored = Signal.new() :: Signal.Signal<Player, Player?, any>

local M = GameConfig.Match
local match = MatchRules.new(M)
local modes: { [Player]: Mode } = {}
local stats: { [Player]: PlayerStats } = {}
local votes: { [Player]: string } = {}
local voteOptions: { string } = {}
local respawnThreads: { [Player]: thread } = {}
local spawnUse: { [BasePart]: number } = {}
local nextMapId: string? = nil
local rng = Random.new()
local stateFolder: Folder
local matchEvent: RemoteEvent
local voteLimiter = RateLimiter.new(6, 2)

local function newStats(): PlayerStats
	return {
		kills = 0,
		deaths = 0,
		assists = 0,
		headshots = 0,
		doublePumps = 0,
		damage = 0,
		shots = 0,
		pelletsFired = 0,
		pelletsHit = 0,
		score = 0,
		joinedAt = os.clock(),
	}
end

local function statsOf(player: Player): PlayerStats
	local s = stats[player]
	if not s then
		s = newStats()
		stats[player] = s
	end
	return s
end

-- Scoreboard columns replicate as player attributes.
local function publishStats(player: Player)
	local s = statsOf(player)
	player:SetAttribute("Kills", s.kills)
	player:SetAttribute("Deaths", s.deaths)
	player:SetAttribute("Assists", s.assists)
	player:SetAttribute("Score", s.score)
	player:SetAttribute("DoublePumps", s.doublePumps)
end

local function inCombat(): boolean
	return MatchRules.inCombat(match)
end

local function matchPlayers(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if modes[p] == "Match" then
			table.insert(list, p)
		end
	end
	return list
end

local function publishState()
	stateFolder:SetAttribute("State", match.state)
	stateFolder:SetAttribute("EndsAt", workspace:GetServerTimeNow() + match.timeLeft)
	stateFolder:SetAttribute("RedScore", match.scores.Red)
	stateFolder:SetAttribute("BlueScore", match.scores.Blue)
	stateFolder:SetAttribute("Target", match.target)
	stateFolder:SetAttribute("MapId", MapService.currentId or "")
	local map = MapService.currentId and MapService.Registry[MapService.currentId]
	stateFolder:SetAttribute("MapName", if map then map.displayName else "")
	stateFolder:SetAttribute("Winner", match.winner or "")
	stateFolder:SetAttribute("MatchNumber", match.matchNumber)
	stateFolder:SetAttribute("Players", #matchPlayers())
	stateFolder:SetAttribute("MinPlayers", M.MinPlayersToStart)
end

---------------------------------------------------------------------------------------
-- Spawning

local function enemyPositions(team: string?): { Vector3 }
	local list = {}
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and character and Combatants.isAlive(character) and TeamService.teamOf(p) ~= team then
			table.insert(list, root.Position)
		end
	end
	return list
end

local function lineOfSight(from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = MapService.worldRoots()
	local eyeFrom = from + Vector3.new(0, 1.5, 0)
	local eyeTo = to + Vector3.new(0, 3, 0)
	return workspace:Raycast(eyeFrom, eyeTo - eyeFrom, params) == nil
end

local function pickSpawn(player: Player): CFrame?
	local team = TeamService.teamOf(player)
	local arenaPhase = match.state ~= "Waiting" and match.state ~= "Intermission"
	local markers: { BasePart } = if team
			and arenaPhase
			and MapService.arena()
		then MapService.spawns(team)
		else MapService.rangeSpawns()
	if #markers == 0 then
		markers = MapService.rangeSpawns()
	end
	if #markers == 0 then
		return nil
	end
	local now = os.clock()
	local candidates = {}
	for i, m in markers do
		candidates[i] = { position = m.Position, lastUsed = spawnUse[m] or -math.huge }
	end
	local enemies = if team then enemyPositions(team) else {}
	local index = SpawnScoring.best(candidates, enemies, now, GameConfig.Player.SpawnEnemyRadius, lineOfSight) or 1
	-- Small shuffle among equally good spawns before the first enemy appears
	if #enemies == 0 then
		index = rng:NextInteger(1, #markers)
	end
	local marker = markers[index]
	spawnUse[marker] = now
	return marker.CFrame
end

local function spawnPlayer(player: Player)
	if not player.Parent or modes[player] == "Menu" or modes[player] == nil then
		return
	end
	local cf = pickSpawn(player)
	if cf then
		CharacterService.spawn(player, cf)
	end
end

local function cancelRespawn(player: Player)
	local thread = respawnThreads[player]
	if thread then
		respawnThreads[player] = nil
		pcall(task.cancel, thread)
	end
end

local function scheduleRespawn(player: Player, delay: number)
	cancelRespawn(player)
	respawnThreads[player] = task.delay(delay, function()
		respawnThreads[player] = nil
		if modes[player] == "Match" and inCombat() then
			TeamService.rebalance(player)
		end
		spawnPlayer(player)
	end)
end

local function freezeAll(frozen: boolean)
	for _, p in matchPlayers() do
		local character = p.Character
		if character and TeamService.teamOf(p) then
			CharacterService.setFrozen(character, frozen)
		end
	end
end

---------------------------------------------------------------------------------------
-- Transitions

local function chooseFirstMap(): string
	local ids = MapService.ArenaIds
	return ids[rng:NextInteger(1, #ids)]
end

-- Starting: load the map (if not already) and put everyone on a team at a spawn.
local function onEnterStarting()
	local mapId = nextMapId or MapService.currentId or chooseFirstMap()
	nextMapId = nil
	if MapService.currentId ~= mapId or not MapService.arena() then
		MapService.load(mapId)
	end
	local players = matchPlayers()
	TeamService.reshuffle(players)
	for _, p in players do
		stats[p] = newStats()
		publishStats(p)
		cancelRespawn(p)
		spawnPlayer(p)
	end
	matchEvent:FireAllClients(
		"Starting",
		{ mapId = mapId, mapName = MapService.Registry[mapId].displayName, countdown = M.StartingCountdown }
	)
end

local function participantsSnapshot()
	local participants = {}
	for _, p in matchPlayers() do
		local s = statsOf(p)
		participants[p] = { team = TeamService.teamOf(p), stats = table.clone(s), timePlayed = os.clock() - s.joinedAt }
	end
	return participants
end

local function pickMvp(): Player?
	local best, bestScore = nil, -math.huge
	for _, p in matchPlayers() do
		local s = statsOf(p)
		local value = s.score * 1000 + s.kills * 10 - s.deaths
		if value > bestScore then
			best, bestScore = p, value
		end
	end
	return best
end

local function onMatchEnded(winner: string?, reason: string)
	freezeAll(true)
	local mvp = pickMvp()
	local participants = participantsSnapshot()
	local board = {}
	for p, info in participants do
		table.insert(board, {
			userId = p.UserId,
			name = p.DisplayName,
			team = info.team,
			kills = info.stats.kills,
			deaths = info.stats.deaths,
			assists = info.stats.assists,
			headshots = info.stats.headshots,
			doublePumps = info.stats.doublePumps,
			damage = math.round(info.stats.damage),
			accuracy = if info.stats.pelletsFired > 0 then info.stats.pelletsHit / info.stats.pelletsFired else 0,
			score = info.stats.score,
		})
	end
	local result: MatchResult = {
		winner = winner,
		reason = reason,
		scores = table.clone(match.scores),
		mapId = MapService.currentId,
		mvp = mvp,
		participants = participants,
	}
	matchEvent:FireAllClients("Ended", {
		winner = winner,
		reason = reason,
		scores = result.scores,
		mvp = if mvp then { userId = mvp.UserId, name = mvp.DisplayName, team = TeamService.teamOf(mvp) } else nil,
		board = board,
		mapName = stateFolder:GetAttribute("MapName"),
	})
	MatchService.MatchEnded:Fire(result)
end

local function onEnterVoting()
	table.clear(votes)
	voteOptions = VoteTally.options(MapService.ArenaIds, 3, MapService.currentId, rng)
	local options = {}
	for _, id in voteOptions do
		local map = MapService.Registry[id]
		table.insert(options, { id = id, name = map.displayName, description = map.description or "" })
	end
	stateFolder:SetAttribute("VoteOptions", table.concat(voteOptions, ","))
	matchEvent:FireAllClients("Voting", { options = options, duration = M.VotingTime })
end

local function broadcastVotes()
	local counts = VoteTally.counts(votes, voteOptions)
	matchEvent:FireAllClients("VoteCounts", counts)
end

local function onVotingEnded()
	if #voteOptions > 0 then
		nextMapId = VoteTally.winner(votes, voteOptions, MapService.currentId, rng)
		matchEvent:FireAllClients(
			"VoteResult",
			{ mapId = nextMapId, name = MapService.Registry[nextMapId :: string].displayName }
		)
	end
	table.clear(votes)
end

local function onWaiting()
	-- Not enough players: everyone in Match mode goes back to the range
	for _, p in matchPlayers() do
		TeamService.clear(p)
		cancelRespawn(p)
		spawnPlayer(p)
	end
	MapService.useRangeLighting()
end

local function handle(events: { MatchRules.Event })
	for _, e in events do
		if e.kind == "State" then
			local to = (e :: any).to
			if to == "Starting" then
				onEnterStarting()
				freezeAll(true)
			elseif to == "Active" then
				freezeAll(false)
			elseif to == "Voting" then
				onEnterVoting()
			elseif to == "Waiting" and (e :: any).from ~= "Waiting" then
				onWaiting()
			end
			matchEvent:FireAllClients("State", to)
		elseif e.kind == "MatchStarted" then
			matchEvent:FireAllClients("Started", { target = match.target })
			MatchService.MatchStarted:Fire(MapService.currentId or "")
		elseif e.kind == "MatchEnded" then
			onMatchEnded((e :: any).winner, (e :: any).reason)
		elseif e.kind == "VotingEnded" then
			onVotingEnded()
		elseif e.kind == "Countdown" then
			matchEvent:FireAllClients("Countdown", (e :: any).seconds)
		end
	end
	publishState()
end

---------------------------------------------------------------------------------------
-- Players

function MatchService.setMode(player: Player, mode: Mode)
	local previous = modes[player]
	modes[player] = mode
	player:SetAttribute("Mode", mode)
	if mode == "Menu" then
		cancelRespawn(player)
		TeamService.clear(player)
		CharacterService.despawn(player)
	elseif mode == "Practice" then
		TeamService.clear(player)
		cancelRespawn(player)
		spawnPlayer(player)
	elseif mode == "Match" then
		if previous ~= "Match" then
			stats[player] = newStats()
			publishStats(player)
		end
		local state = match.state
		if state == "Active" or state == "Overtime" or state == "Starting" then
			-- Join the match in progress on the team that needs players
			if TeamService.assign(player, match.scores) then
				cancelRespawn(player)
				spawnPlayer(player)
				if state == "Starting" and player.Character then
					CharacterService.setFrozen(player.Character, true)
				end
			else
				-- Both teams full: wait in the range
				TeamService.clear(player)
				spawnPlayer(player)
			end
		else
			TeamService.clear(player)
			spawnPlayer(player)
		end
	end
	publishState()
end

function MatchService.modeOf(player: Player): Mode
	return modes[player] or "Menu"
end

function MatchService.inCombat(): boolean
	return inCombat()
end

function MatchService.state(): string
	return match.state
end

local function onPlayerAction(player: Player, action: any, value: any)
	if action == "Deploy" then
		if MatchService.modeOf(player) ~= "Match" then
			MatchService.setMode(player, "Match")
		end
	elseif action == "Practice" then
		MatchService.setMode(player, "Practice")
	elseif action == "Menu" then
		if MatchService.modeOf(player) ~= "Menu" then
			MatchService.setMode(player, "Menu")
		end
	elseif action == "Vote" then
		if match.state ~= "Voting" or typeof(value) ~= "string" or not table.find(voteOptions, value) then
			return
		end
		if not voteLimiter:allow(player, os.clock()) then
			return
		end
		votes[player] = value
		broadcastVotes()
	end
end

local function onEliminated(elimination: DamageService.Elimination)
	local victimPlayer = elimination.victimPlayer
	local killer = elimination.killer
	if victimPlayer then
		local s = statsOf(victimPlayer)
		s.deaths += 1
		publishStats(victimPlayer)
	end
	if not killer or Combatants.isDummy(elimination.victim) then
		return
	end
	local killerTeam = TeamService.teamOf(killer)
	if not killerTeam or not inCombat() then
		return
	end
	local s = statsOf(killer)
	s.kills += 1
	s.score += 100 + (if elimination.headshot then 25 else 0) + (if elimination.doublePump then 50 else 0)
	if elimination.headshot then
		s.headshots += 1
	end
	if elimination.doublePump then
		s.doublePumps += 1
	end
	publishStats(killer)
	for _, assister in elimination.assists do
		local a = statsOf(assister)
		a.assists += 1
		a.score += 50
		publishStats(assister)
	end
	MatchService.Scored:Fire(killer, victimPlayer, elimination)
	handle(MatchRules.addScore(match, killerTeam))
end

function MatchService.start()
	stateFolder = Instance.new("Folder")
	stateFolder.Name = "MatchState"
	stateFolder.Parent = ReplicatedStorage
	matchEvent = Net.event("MatchEvent")
	publishState()

	Net.event("PlayerAction").OnServerEvent:Connect(onPlayerAction)
	DamageService.Eliminated:Connect(onEliminated)
	DamageService.Damaged:Connect(function(attacker, _, dealt)
		if attacker and stats[attacker] then
			stats[attacker].damage += dealt
		end
	end)
	CombatService.ShotFired:Connect(function(player, _, pellets, hits)
		local s = stats[player]
		if s and modes[player] == "Match" and inCombat() then
			s.shots += 1
			s.pelletsFired += pellets
			s.pelletsHit += hits
		end
	end)
	CombatService.setCanFire(function(player)
		local character = player.Character
		if not character or character:GetAttribute("Frozen") == true then
			return false
		end
		local team = TeamService.teamOf(player)
		if team == nil then
			return true -- practice range
		end
		return inCombat()
	end)
	CombatService.setWorldRoots(MapService.worldRoots)

	CharacterService.Died:Connect(function(player, character)
		local delay = GameConfig.Player.RespawnDelay
		matchEvent:FireClient(player, "Respawning", { delay = delay })
		scheduleRespawn(player, delay)
		task.delay(delay + 2, function()
			if character.Parent and player.Character ~= character then
				character:Destroy()
			end
		end)
	end)

	Players.PlayerAdded:Connect(function(player)
		modes[player] = "Menu"
		player:SetAttribute("Mode", "Menu")
		publishStats(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		cancelRespawn(player)
		modes[player] = nil
		stats[player] = nil
		votes[player] = nil
		voteLimiter:forget(player)
		-- Defer so the player is really gone from GetPlayers when counting
		task.defer(publishState)
	end)

	-- One loop drives the whole match: no competing timers.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		local step = accumulator
		accumulator = 0
		local soloAllowed = GameConfig.Debug.AllowSoloMatchInStudio and RunService:IsStudio()
		local events = MatchRules.step(match, step, { players = #matchPlayers(), soloAllowed = soloAllowed })
		if #events > 0 then
			handle(events)
		end
	end)
	-- Falling off the map (Rooftops' drops, or out of the world) eliminates you
	local fallCheck = 0
	RunService.Heartbeat:Connect(function(dt)
		fallCheck += dt
		if fallCheck < 0.25 then
			return
		end
		fallCheck = 0
		local killY = MapService.killY()
		for _, p in Players:GetPlayers() do
			local character = p.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if character and root and root.Position.Y < killY and Combatants.isAlive(character) then
				DamageService.kill(character)
			end
		end
	end)
	-- Anyone who (re)spawns into the arena outside live play stays frozen until it starts
	CharacterService.Spawned:Connect(function(player, character)
		if TeamService.teamOf(player) and not inCombat() then
			CharacterService.setFrozen(character, true)
		end
	end)
end

MatchService._match = match

return MatchService
