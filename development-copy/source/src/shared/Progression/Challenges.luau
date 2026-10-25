--!strict
-- Daily and weekly challenges. Each period picks a fixed set from the pool using the
-- period number as a seed, so every server shows the same challenges on the same day
-- without any shared storage. Progress is stored per player with the period it
-- belongs to; a new period starts fresh.

local Challenges = {}

export type Stat = "kills" | "headshots" | "doublePumps" | "assists" | "wins" | "matches" | "damage"

export type Def = {
	id: string,
	text: string,
	stat: Stat,
	goal: number,
	xp: number,
	coins: number,
}

Challenges.Daily = {
	{ id = "d_kills10", text = "Get 10 eliminations", stat = "kills", goal = 10, xp = 300, coins = 40 },
	{ id = "d_kills20", text = "Get 20 eliminations", stat = "kills", goal = 20, xp = 450, coins = 60 },
	{ id = "d_head5", text = "Get 5 headshot eliminations", stat = "headshots", goal = 5, xp = 350, coins = 45 },
	{ id = "d_dp2", text = "Land 2 double pumps", stat = "doublePumps", goal = 2, xp = 400, coins = 50 },
	{ id = "d_assist5", text = "Get 5 assists", stat = "assists", goal = 5, xp = 250, coins = 35 },
	{ id = "d_win1", text = "Win a match", stat = "wins", goal = 1, xp = 350, coins = 45 },
	{ id = "d_play3", text = "Play 3 matches", stat = "matches", goal = 3, xp = 300, coins = 40 },
	{ id = "d_dmg1500", text = "Deal 1,500 damage", stat = "damage", goal = 1500, xp = 300, coins = 40 },
} :: { Def }

Challenges.Weekly = {
	{ id = "w_kills100", text = "Get 100 eliminations", stat = "kills", goal = 100, xp = 1500, coins = 200 },
	{ id = "w_head30", text = "Get 30 headshot eliminations", stat = "headshots", goal = 30, xp = 1400, coins = 180 },
	{ id = "w_dp15", text = "Land 15 double pumps", stat = "doublePumps", goal = 15, xp = 1600, coins = 220 },
	{ id = "w_win8", text = "Win 8 matches", stat = "wins", goal = 8, xp = 1500, coins = 200 },
	{ id = "w_play15", text = "Play 15 matches", stat = "matches", goal = 15, xp = 1200, coins = 160 },
	{ id = "w_dmg12k", text = "Deal 12,000 damage", stat = "damage", goal = 12000, xp = 1300, coins = 170 },
} :: { Def }

Challenges.PerPeriod = { daily = 3, weekly = 3 }

local DAY = 86400
-- Weeks start Monday 00:00 UTC (1970-01-01 was a Thursday).
local WEEK_OFFSET = 3 * DAY

function Challenges.dayNumber(unix: number): number
	return unix // DAY
end

function Challenges.weekNumber(unix: number): number
	return (unix + WEEK_OFFSET) // (7 * DAY)
end

function Challenges.secondsLeft(kind: "daily" | "weekly", unix: number): number
	if kind == "daily" then
		return (Challenges.dayNumber(unix) + 1) * DAY - unix
	end
	return (Challenges.weekNumber(unix) + 1) * 7 * DAY - WEEK_OFFSET - unix
end

-- Deterministic pick of `count` distinct challenges for a period.
function Challenges.pick(pool: { Def }, period: number, count: number): { Def }
	local rng = Random.new(period * 7919 + #pool)
	local indices = {}
	for i = 1, #pool do
		indices[i] = i
	end
	for i = #indices, 2, -1 do
		local j = rng:NextInteger(1, i)
		indices[i], indices[j] = indices[j], indices[i]
	end
	local out = {}
	for i = 1, math.min(count, #pool) do
		table.insert(out, pool[indices[i]])
	end
	return out
end

function Challenges.find(id: string): Def?
	for _, pool in { Challenges.Daily, Challenges.Weekly } do
		for _, def in pool do
			if def.id == id then
				return def
			end
		end
	end
	return nil
end

export type Entry = { id: string, progress: number, done: boolean }
export type Set = { period: number, entries: { Entry } }

-- Returns the set for the current period, rolling over to new challenges if the stored
-- set is from an older period.
function Challenges.current(kind: "daily" | "weekly", stored: Set?, unix: number): Set
	local period = if kind == "daily" then Challenges.dayNumber(unix) else Challenges.weekNumber(unix)
	if stored and stored.period == period then
		return stored
	end
	local pool = if kind == "daily" then Challenges.Daily else Challenges.Weekly
	local entries = {}
	for _, def in Challenges.pick(pool, period, Challenges.PerPeriod[kind]) do
		table.insert(entries, { id = def.id, progress = 0, done = false })
	end
	return { period = period, entries = entries }
end

-- Adds match stats to a set. Returns the defs completed by this call (reward once).
function Challenges.progress(set: Set, delta: { [string]: number }): { Def }
	local completed = {}
	for _, entry in set.entries do
		local def = Challenges.find(entry.id)
		if def and not entry.done then
			local amount = delta[def.stat] or 0
			if amount > 0 then
				entry.progress = math.min(def.goal, entry.progress + amount)
				if entry.progress >= def.goal then
					entry.done = true
					table.insert(completed, def)
				end
			end
		end
	end
	return completed
end

return Challenges
