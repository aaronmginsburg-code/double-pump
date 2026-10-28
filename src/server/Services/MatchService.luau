--!strict
-- Runs the game: who is playing, practice vs match, the team-deathmatch state machine
-- (MatchRules), spawning/respawning, scoring, map voting and map loading.
--
-- Player modes:
--   "Menu"     in the main menu, no character
--   "Match"    selected by the physical queue: reserved/voting, or in the arena
--   "Practice" permanent default lobby; only queue occupancy can request a match
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
local LobbyQueue = require(Shared.Match.LobbyQueue)
local LobbyCues = require(Shared.Audio.LobbyCues)
local ActionCues = require(Shared.Audio.ActionCues)
local audioClock = ActionCues.newClock()
local Net = require(Shared.Net)
local RateLimiter = require(Shared.Util.RateLimiter)
local Signal = require(Shared.Util.Signal)
local SpawnScoring = require(Shared.Match.SpawnScoring)
local VoteTally = require(Shared.Match.VoteTally)

local CharacterService = require(script.Parent.CharacterService)
local CombatContext = require(script.Parent.CombatContext)
local QueueZone = require(script.Parent.Parent.Maps.QueueZone)
local CombatService = require(script.Parent.CombatService)
local DamageService = require(script.Parent.DamageService)
local MapService = require(script.Parent.MapService)
local TeamService = require(script.Parent.TeamService)

local Actors = require(script.Parent.Participants)
local TrainingPolicy = require(Shared.Training.Policy)
local trainingRound = false
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
	training: boolean?,
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
local queue = LobbyQueue.new(GameConfig.LobbyQueue)
local lobbyReady: { [Player]: boolean } = {}
local lastNotification: { [Player]: number } = {}
local queueState = "Waiting"
local cueStates: { [Player]: LobbyCues.State } = {}
local cueSerials: { [Player]: number } = {}
local returningCharacters: { [Player]: Model } = {}
local function lobbyCue(player: Player, cue: string)
	if Actors.isBot(player) or not Actors.exists(player) then
		return
	end
	local serial = (cueSerials[player] or 0) + 1
	cueSerials[player] = serial
	matchEvent:FireClient(player, "LobbyAudio", { cue = cue, serial = serial })
end
local drawQueue: (string, number, number, number, number) -> ()

local function sendParticipants(kind: string, data: any)
	for player, mode in modes do
		if mode == "Match" and not Actors.isBot(player) and Actors.exists(player) then
			matchEvent:FireClient(player, kind, data)
		end
	end
end

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
	Actors.attribute(player, "Kills", s.kills)
	Actors.attribute(player, "Deaths", s.deaths)
	Actors.attribute(player, "Assists", s.assists)
	Actors.attribute(player, "Score", s.score)
	Actors.attribute(player, "DoublePumps", s.doublePumps)
end

local function inCombat(): boolean
	return MatchRules.inCombat(match)
end

local function matchPlayers(): { Player }
	local list = {}
	for _, p in Actors.all() do
		if modes[p] == "Match" then
			table.insert(list, p)
		end
	end
	return list
end

local function publishState()
	stateFolder:SetAttribute("TrainingMatch", trainingRound)
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
	for _, p in Actors.all() do
		local character = Actors.character(p)
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if
			modes[p] == "Match"
			and root
			and character
			and Combatants.isAlive(character)
			and TeamService.teamOf(p) ~= team
		then
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
	if Actors.isBot(player) and modes[player] ~= "Match" then
		local pos = MapService.Registry.Range.origin + Vector3.new(-49, 0.5, if player.index == 1 then -9 else 9)
		return CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0))
	end
	local team = TeamService.teamOf(player)
	local arenaPhase = match.state == "Starting"
		or match.state == "Active"
		or match.state == "Overtime"
		or match.state == "Results"
	local markers: { BasePart } = if modes[player] == "Match"
			and team
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

local function spawnPlayer(player: Player, transfer: boolean?)
	if not Actors.exists(player) or modes[player] == "Menu" or modes[player] == nil then
		return
	end
	local cf = pickSpawn(player)
	if cf then
		if transfer then
			CharacterService.transfer(player, cf)
		else
			CharacterService.spawn(player, cf)
		end
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
		local character = Actors.character(p)
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
		CombatContext.set(p, "Reserved")
		task.spawn(spawnPlayer, p, true)
	end
	sendParticipants(
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
			userId = Actors.id(p),
			botId = if Actors.isBot(p) then p.id else nil,
			name = Actors.name(p),
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
		training = trainingRound,
		winner = winner,
		reason = reason,
		scores = table.clone(match.scores),
		mapId = MapService.currentId,
		mvp = mvp,
		participants = participants,
	}
	sendParticipants("Ended", {
		training = trainingRound,
		winner = winner,
		reason = reason,
		scores = result.scores,
		mvp = if mvp
			then {
				userId = Actors.id(mvp),
				botId = if Actors.isBot(mvp) then mvp.id else nil,
				name = Actors.name(mvp),
				team = TeamService.teamOf(mvp),
			}
			else nil,
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
	sendParticipants("Voting", { options = options, duration = M.VotingTime })
end

local function broadcastVotes()
	local counts = VoteTally.counts(votes, voteOptions)
	sendParticipants("VoteCounts", counts)
end

local function onVotingEnded()
	if #voteOptions > 0 then
		nextMapId = VoteTally.winner(votes, voteOptions, MapService.currentId, rng)
		sendParticipants(
			"VoteResult",
			{ mapId = nextMapId, name = MapService.Registry[nextMapId :: string].displayName }
		)
	end
	table.clear(votes)
end

local function onWaiting()
	for _, p in matchPlayers() do
		-- Living transfers get a return cue; replacement characters use the existing Spawn cue.
		returningCharacters[p] = Actors.character(p)
		cancelRespawn(p)
		lobbyReady[p] = false
		if Actors.character(p) then
			DamageService.forget(Actors.character(p))
		end
		modes[p] = "Practice"
		TeamService.clear(p)
		CombatContext.set(p, "Lobby")
		Actors.attribute(p, "Mode", "Practice")
		Actors.attribute(p, "Queued", false)
		stats[p] = newStats()
		publishStats(p)
		-- Character loading yields: never block the single match/queue clock.
		task.spawn(spawnPlayer, p, true)
	end
	local owner = Actors.owner()
	if owner then
		CombatContext.stopTraining(owner)
	end
	trainingRound = false
	MapService.useRangeLighting()
end

local function handle(events: { MatchRules.Event })
	for _, e in events do
		if e.kind == "State" then
			local to = (e :: any).to
			CombatContext.activate(if to == "Active" or to == "Overtime" then match.matchNumber else nil)
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
			sendParticipants("State", to)
		elseif e.kind == "MatchStarted" then
			sendParticipants("Started", { target = match.target })
			MatchService.MatchStarted:Fire(MapService.currentId or "")
		elseif e.kind == "MatchEnded" then
			onMatchEnded((e :: any).winner, (e :: any).reason)
		elseif e.kind == "VotingEnded" then
			onVotingEnded()
		elseif e.kind == "Countdown" then
			sendParticipants("Countdown", (e :: any).seconds)
		end
	end
	publishState()
end

---------------------------------------------------------------------------------------
-- Players

function MatchService.setMode(player: Player, mode: Mode)
	if mode == "Match" then
		return -- queue admission is the only way to reserve a match slot
	end
	cancelRespawn(player)
	lobbyReady[player] = false
	if Actors.character(player) then
		DamageService.forget(Actors.character(player))
	end
	modes[player] = "Practice"
	TeamService.clear(player)
	CombatContext.set(player, "Lobby")
	Actors.attribute(player, "Mode", "Practice")
	Actors.attribute(player, "Queued", false)
	task.spawn(spawnPlayer, player, true)
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
		-- Legacy menu button explains the physical queue; it cannot admit anyone.
		Net.event("Notify"):FireClient(player, "Enter the Match Queue Zone in the firing range.")
	elseif action == "Practice" or action == "Menu" then
		if modes[player] == "Match" then
			MatchService.setMode(player, "Practice")
		end
	elseif action == "Vote" then
		if
			modes[player] ~= "Match"
			or match.state ~= "Voting"
			or typeof(value) ~= "string"
			or not table.find(voteOptions, value)
		then
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
	if victimPlayer and modes[victimPlayer] == "Match" and inCombat() then
		local s = statsOf(victimPlayer)
		s.deaths += 1
		publishStats(victimPlayer)
	end
	if not killer or Combatants.isDummy(elimination.victim) then
		return
	end
	local killerTeam = TeamService.teamOf(killer)
	if
		not killerTeam
		or modes[killer] ~= "Match"
		or not victimPlayer
		or modes[victimPlayer] ~= "Match"
		or not inCombat()
	then
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
		if modes[assister] ~= "Match" then
			continue
		end
		local a = statsOf(assister)
		a.assists += 1
		a.score += 50
		publishStats(assister)
		lobbyCue(assister, "Assist")
	end
	MatchService.Scored:Fire(killer, victimPlayer, elimination)
	handle(MatchRules.addScore(match, killerTeam))
end

function MatchService.botQueueEligible(p: any, cf: CFrame): boolean
	if not Actors.isBot(p) then
		return true
	end
	local owner = p.owner
	local c = Actors.character(owner)
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if
		modes[owner] ~= "Practice"
		or not lobbyReady[owner]
		or not c
		or not root
		or not Combatants.isAlive(c)
		or not LobbyQueue.contains(cf, GameConfig.LobbyQueue.Size, root.Position)
	then
		return false
	end
	for _, bot in Actors.list() do
		local model = bot.model
		local r = model and model:FindFirstChild("HumanoidRootPart")
		if not model or not r or not Combatants.isAlive(model) or modes[bot] ~= "Practice" then
			return false
		end
	end
	return true
end
function MatchService.registerBot(bot: any)
	assert(Actors.isBot(bot))
	publishStats(bot)
	MatchService.setMode(bot, "Practice")
end
function MatchService.removeBot(bot: any)
	cancelRespawn(bot)
	modes[bot] = nil
	lobbyReady[bot] = nil
	stats[bot] = nil
	votes[bot] = nil
	cueStates[bot] = nil
	cueSerials[bot] = nil
	lastNotification[bot] = nil
	returningCharacters[bot] = nil
	CombatContext.forget(bot)
	CombatService.forgetParticipant(bot)
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
		if attacker and modes[attacker] == "Match" and inCombat() and stats[attacker] then
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
		local character = Actors.character(player)
		if not character or character:GetAttribute("Frozen") == true then
			return false
		end
		return modes[player] == "Practice" or (modes[player] == "Match" and inCombat())
	end)
	CombatService.setWorldRoots(MapService.worldRoots)

	CharacterService.Died:Connect(function(player, character)
		local delay = GameConfig.Player.RespawnDelay
		if not Actors.isBot(player) then
			matchEvent:FireClient(player, "Respawning", { delay = delay })
		end
		scheduleRespawn(player, delay)
		task.delay(delay + 2, function()
			if character.Parent and Actors.character(player) ~= character then
				character:Destroy()
			end
		end)
	end)

	local function onPlayerAdded(player: Player)
		publishStats(player)
		MatchService.setMode(player, "Practice")
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Actors.all() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		cancelRespawn(player)
		modes[player] = nil
		lobbyReady[player] = nil
		lastNotification[player] = nil
		cueStates[player] = nil
		cueSerials[player] = nil
		returningCharacters[player] = nil
		CombatContext.forget(player)
		stats[player] = nil
		votes[player] = nil
		voteLimiter:forget(player)
		-- Defer so the player is really gone from GetPlayers when counting
		task.defer(publishState)
	end)

	local range = workspace:FindFirstChild("Range") :: Model
	local rangeOrigin = MapService.Registry.Range.origin or Vector3.new(-1200, 0, 0)
	local zoneCFrame = CFrame.new(rangeOrigin + GameConfig.LobbyQueue.Offset)
	drawQueue = QueueZone.build(range, zoneCFrame, GameConfig.LobbyQueue.Size)
	local function stepQueue(): boolean
		local occupants = {}
		local candidates = Actors.all()
		table.sort(candidates, function(a, b)
			return Actors.sortKey(a) < Actors.sortKey(b)
		end)
		for _, p in candidates do
			local character = Actors.character(p)
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if
				modes[p] == "Practice"
				and lobbyReady[p]
				and character
				and root
				and Combatants.isAlive(character)
				and LobbyQueue.contains(zoneCFrame, GameConfig.LobbyQueue.Size, root.Position)
				and MatchService.botQueueEligible(p, zoneCFrame)
			then
				table.insert(occupants, p)
			end
		end
		local previous = queueState

		local selected, state =
			LobbyQueue.step(queue, occupants, workspace:GetServerTimeNow(), match.state == "Waiting")
		if #selected > 0 and #Actors.list() > 0 then
			local complete = {}
			for _, p in selected do
				table.insert(complete, p)
			end
			for _, p in queue.order do
				table.insert(complete, p)
			end
			local safe =
				TrainingPolicy.selection(complete, Actors.owner(), Actors.list(), GameConfig.LobbyQueue.Capacity)
			if #safe ~= #selected then
				selected = safe
				queue.order = {}
				for i = #safe + 1, #complete do
					table.insert(queue.order, complete[i])
				end
				queue.deadline = nil
				state = if #safe > 0 then "Admitting" else "Waiting"
				local owner = Actors.owner()
				if owner and os.clock() - (lastNotification[owner] or -math.huge) > 3 then
					Net.event("Notify")
						:FireClient(owner, "Training pair must be alive and physically queued; waiting for capacity.")
					lastNotification[owner] = os.clock()
				end
			end
		end
		queueState = state
		for _, p in candidates do
			local queued = table.find(queue.order, p) ~= nil
			local audioState = cueStates[p] or LobbyCues.new()
			cueStates[p] = audioState
			local cue = LobbyCues.step(
				audioState,
				queued,
				state,
				if queue.deadline then math.max(0, math.ceil(queue.deadline - workspace:GetServerTimeNow())) else 0,
				workspace:GetServerTimeNow(),
				table.find(selected, p) ~= nil
			)
			if cue then
				lobbyCue(p, cue)
			end
			if Actors.getAttribute(p, "Queued") ~= queued then
				Actors.attribute(p, "Queued", queued)
				local now = os.clock()
				if
					not Actors.isBot(p)
					and not table.find(selected, p)
					and now - (lastNotification[p] or -math.huge) >= 1
				then
					Net.event("Notify"):FireClient(p, if queued then "Joined Match Queue" else "Left Match Queue")
					lastNotification[p] = now
				end
			end
			if
				not Actors.isBot(p)
				and queued
				and previous ~= state
				and (state == "Countdown" or state == "Waiting")
			then
				Net.event("Notify"):FireClient(
					p,
					if state == "Countdown"
						then `Match starting in {GameConfig.LobbyQueue.Countdown} seconds`
						else "Waiting for more players"
				)
			end
		end
		stateFolder:SetAttribute("QueueState", state)
		stateFolder:SetAttribute("QueueCount", #queue.order)
		stateFolder:SetAttribute("QueueEndsAt", queue.deadline or 0)
		drawQueue(
			state,
			#queue.order,
			GameConfig.LobbyQueue.Capacity,
			GameConfig.LobbyQueue.Minimum,
			if queue.deadline then math.max(0, math.ceil(queue.deadline - workspace:GetServerTimeNow())) else 0
		)
		if #selected == 0 then
			return false
		end
		-- This entire selection/admission path is non-yielding. Only roots validated
		-- in this exact sample are admitted; spawn loads happen asynchronously later.
		for _, p in selected do
			modes[p] = "Match"
			lobbyReady[p] = false
			CombatContext.set(p, "Reserved")
			lobbyCue(p, "Admitted")
			Actors.attribute(p, "Mode", "Match")
			Actors.attribute(p, "Queued", false)
			cancelRespawn(p)
		end
		trainingRound = false
		for _, p in selected do
			if Actors.isBot(p) then
				trainingRound = true
			end
		end
		TeamService.reshuffle(selected)
		freezeAll(true)
		return true
	end

	-- One loop drives the whole match: no competing timers.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < GameConfig.LobbyQueue.PollInterval then
			return
		end
		local step = accumulator
		accumulator = 0
		local admitted = stepQueue()
		local events =
			MatchRules.step(match, step, { players = #matchPlayers(), voluntary = true, admitted = admitted })
		if #events > 0 then
			handle(events)
		end
		local cue = ActionCues.clock(audioClock, match.matchNumber, match.state, match.timeLeft)
		if cue then
			for _, p in matchPlayers() do
				lobbyCue(p, cue)
			end
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
		for _, p in Actors.all() do
			local character = Actors.character(p)
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local killY = if modes[p] == "Match" then MapService.killY() else -40
			if character and root and root.Position.Y < killY and Combatants.isAlive(character) then
				DamageService.kill(character)
			end
		end
	end)
	-- Anyone who (re)spawns into the arena outside live play stays frozen until it starts
	CharacterService.Spawned:Connect(function(player, character)
		if modes[player] == "Match" and (match.state == "Starting" or inCombat() or match.state == "Results") then
			CombatContext.set(player, "Match", match.matchNumber + (if match.state == "Starting" then 1 else 0))
		else
			CombatContext.refresh(player)
		end
		lobbyReady[player] = modes[player] == "Practice"
		if Actors.isBot(player) then
			publishStats(player)
		end
		local returned = returningCharacters[player]
		returningCharacters[player] = nil
		if returned == character and lobbyReady[player] then
			lobbyCue(player, "ReturnToRange")
		end
		if TeamService.teamOf(player) and not inCombat() then
			CharacterService.setFrozen(character, true)
		end
	end)
end

MatchService._match = match

return MatchService
