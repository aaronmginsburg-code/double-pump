--!strict
-- The match state machine as pure logic (no Roblox APIs), driven by a single step()
-- with a time delta, so there is exactly one timer and transitions can't overlap.
--
--   Waiting -> Intermission -> Starting -> Active [-> Overtime] -> Results -> Voting -> Starting ...
--
-- step() returns a list of events for MatchService to act on (spawn players, load a
-- map, award wins). Score changes go through addScore(), which can end the match.

export type State = "Waiting" | "Intermission" | "Starting" | "Active" | "Overtime" | "Results" | "Voting"

export type Event =
	{ kind: "State", from: State, to: State }
	| { kind: "MatchStarted" }
	| { kind: "MatchEnded", winner: string?, reason: string }
	| { kind: "VotingEnded" }
	| { kind: "Countdown", seconds: number }

export type Match = {
	config: any,
	state: State,
	timeLeft: number,
	scores: { [string]: number },
	target: number,
	winner: string?,
	endReason: string?,
	lowPlayerTime: number,
	matchNumber: number,
	lastCountdown: number,
}

local MatchRules = {}

MatchRules.TEAMS = { "Red", "Blue" }

function MatchRules.new(config: any): Match
	return {
		config = config,
		state = "Waiting",
		timeLeft = 0,
		scores = { Red = 0, Blue = 0 },
		target = config.ScoreToWin,
		winner = nil,
		endReason = nil,
		lowPlayerTime = 0,
		matchNumber = 0,
		lastCountdown = -1,
	}
end

-- Kill target for the number of players in the match.
function MatchRules.targetFor(config: any, players: number): number
	if not config.ScaleScoreWithPlayers then
		return config.ScoreToWin
	end
	local scaled = math.ceil(config.ScoreToWin * math.clamp(players, 1, config.MaxPlayers) / config.MaxPlayers)
	scaled = math.ceil(scaled / 5) * 5
	return math.clamp(scaled, config.ScoreToWinMin, config.ScoreToWin)
end

local function enter(m: Match, to: State, duration: number, events: { Event })
	local from = m.state
	m.state = to
	m.timeLeft = duration
	m.lastCountdown = -1
	table.insert(events, { kind = "State", from = from, to = to } :: any)
end

local function leader(m: Match): string?
	local r, b = m.scores.Red, m.scores.Blue
	if r > b then
		return "Red"
	elseif b > r then
		return "Blue"
	end
	return nil
end

local function finish(m: Match, winner: string?, reason: string, events: { Event })
	m.winner = winner
	m.endReason = reason
	table.insert(events, { kind = "MatchEnded", winner = winner, reason = reason })
	enter(m, "Results", m.config.ResultsTime, events)
end

local function startMatch(m: Match, players: number, events: { Event })
	m.scores.Red = 0
	m.scores.Blue = 0
	m.winner = nil
	m.endReason = nil
	m.target = MatchRules.targetFor(m.config, players)
	m.matchNumber += 1
	m.lowPlayerTime = 0
	enter(m, "Active", m.config.Duration, events)
	table.insert(events, { kind = "MatchStarted" })
end

export type Context = {
	players: number, -- players taking part (deployed)
	teamCounts: { [string]: number }?,
	soloAllowed: boolean?,
}

local function enough(m: Match, ctx: Context): boolean
	local need = if ctx.soloAllowed then 1 else m.config.MinPlayersToStart
	return ctx.players >= need
end

function MatchRules.step(m: Match, dt: number, ctx: Context): { Event }
	local events: { Event } = {}
	local c = m.config
	local s = m.state
	m.timeLeft = math.max(0, m.timeLeft - dt)

	if s == "Waiting" then
		if enough(m, ctx) then
			enter(m, "Intermission", c.IntermissionTime, events)
		end
	elseif s == "Intermission" then
		if not enough(m, ctx) then
			enter(m, "Waiting", 0, events)
		elseif m.timeLeft <= 0 then
			enter(m, "Starting", c.StartingCountdown, events)
		end
	elseif s == "Starting" then
		if not enough(m, ctx) then
			enter(m, "Waiting", 0, events)
		else
			local whole = math.ceil(m.timeLeft)
			if whole ~= m.lastCountdown and whole > 0 then
				m.lastCountdown = whole
				table.insert(events, { kind = "Countdown", seconds = whole })
			end
			if m.timeLeft <= 0 then
				startMatch(m, ctx.players, events)
			end
		end
	elseif s == "Active" or s == "Overtime" then
		-- Too few players for a while (people left): end the match on the current score.
		if not enough(m, ctx) then
			m.lowPlayerTime += dt
			if m.lowPlayerTime >= 10 then
				finish(m, leader(m), "NotEnoughPlayers", events)
				return events
			end
		else
			m.lowPlayerTime = 0
		end
		if m.timeLeft <= 0 then
			local winner = leader(m)
			if winner then
				finish(m, winner, if s == "Overtime" then "Overtime" else "Time", events)
			elseif s == "Active" and c.OvertimeEnabled then
				enter(m, "Overtime", c.OvertimeDuration, events)
			else
				finish(m, nil, "Draw", events)
			end
		end
	elseif s == "Results" then
		if m.timeLeft <= 0 then
			enter(m, "Voting", c.VotingTime, events)
		end
	elseif s == "Voting" then
		if m.timeLeft <= 0 then
			table.insert(events, { kind = "VotingEnded" })
			if enough(m, ctx) then
				enter(m, "Starting", c.StartingCountdown, events)
			else
				enter(m, "Waiting", 0, events)
			end
		end
	end
	return events
end

-- Records an elimination for `team`. Returns events (may end the match).
function MatchRules.addScore(m: Match, team: string, amount: number?): { Event }
	local events: { Event } = {}
	if m.state ~= "Active" and m.state ~= "Overtime" then
		return events
	end
	if m.scores[team] == nil then
		return events
	end
	m.scores[team] += amount or 1
	if m.scores[team] >= m.target then
		finish(m, team, "Score", events)
	elseif m.state == "Overtime" then
		-- Sudden death: the first elimination in overtime wins it
		finish(m, team, "Overtime", events)
	end
	return events
end

function MatchRules.inCombat(m: Match): boolean
	return m.state == "Active" or m.state == "Overtime"
end

return MatchRules
