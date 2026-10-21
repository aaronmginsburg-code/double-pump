--!strict
-- Player level, match rewards and shotgun mastery. Pure functions, shared so the
-- server computes rewards and the client can show the same numbers.
--
-- Anti-idle: completion and win rewards scale with how much of the match the player
-- was actually playing (moving, aiming, shooting). A player who stands still all match
-- gets nothing beyond what they earned with eliminations.

local Levels = {}

Levels.MaxLevel = 100

-- XP needed to go from `level` to `level + 1`.
function Levels.xpToNext(level: number): number
	return math.min(400 + 100 * (level - 1), 2000)
end

export type LevelInfo = { level: number, into: number, need: number, isMax: boolean }

function Levels.fromXp(totalXp: number): LevelInfo
	local level = 1
	local remaining = math.max(0, math.floor(totalXp))
	while level < Levels.MaxLevel do
		local need = Levels.xpToNext(level)
		if remaining < need then
			return { level = level, into = remaining, need = need, isMax = false }
		end
		remaining -= need
		level += 1
	end
	return { level = Levels.MaxLevel, into = 0, need = 0, isMax = true }
end

Levels.Rewards = {
	Kill = 50,
	Assist = 20,
	Headshot = 10, -- bonus on top of Kill
	DoublePump = 25, -- bonus on top of Kill
	Completion = 100, -- for playing a whole match, scaled by time and activity
	Win = 150,
	CoinsPerKill = 5,
	CoinsCompletion = 25,
	CoinsWin = 50,
	MinActiveFraction = 0.35, -- below this, no completion/win reward at all
}

export type MatchSummary = {
	kills: number,
	assists: number,
	headshotKills: number,
	doublePumps: number,
	won: boolean,
	timePlayed: number,
	matchLength: number,
	activeTime: number, -- seconds with real input (moved, turned, fired)
}

export type Reward = { xp: number, coins: number, breakdown: { { label: string, xp: number } }, idle: boolean }

function Levels.matchReward(s: MatchSummary): Reward
	local R = Levels.Rewards
	local breakdown = {}
	local xp, coins = 0, 0
	local function add(label: string, amount: number)
		if amount > 0 then
			xp += amount
			table.insert(breakdown, { label = label, xp = amount })
		end
	end
	add("Eliminations", s.kills * R.Kill)
	add("Assists", s.assists * R.Assist)
	add("Headshots", s.headshotKills * R.Headshot)
	add("Double pumps", s.doublePumps * R.DoublePump)
	coins += s.kills * R.CoinsPerKill

	local length = math.max(1, s.matchLength)
	local presence = math.clamp(s.timePlayed / length, 0, 1)
	local active = if s.timePlayed > 0 then math.clamp(s.activeTime / s.timePlayed, 0, 1) else 0
	local idle = active < R.MinActiveFraction
	if not idle then
		local factor = presence * math.min(1, active / 0.7)
		add("Match played", math.floor(R.Completion * factor))
		coins += math.floor(R.CoinsCompletion * factor)
		if s.won then
			add("Victory", math.floor(R.Win * presence))
			coins += math.floor(R.CoinsWin * presence)
		end
	end
	return { xp = xp, coins = coins, breakdown = breakdown, idle = idle }
end

-- Shotgun mastery: eliminations with the pump shotgun.
Levels.Mastery = {
	{ kills = 25, name = "Bronze", color = Color3.fromRGB(205, 127, 50) },
	{ kills = 100, name = "Silver", color = Color3.fromRGB(200, 205, 215) },
	{ kills = 250, name = "Gold", color = Color3.fromRGB(255, 205, 60) },
	{ kills = 500, name = "Diamond", color = Color3.fromRGB(110, 220, 255) },
	{ kills = 1000, name = "Pump Master", color = Color3.fromRGB(255, 120, 40) },
}

export type MasteryInfo = { tier: number, name: string, kills: number, nextAt: number? }

function Levels.mastery(kills: number): MasteryInfo
	local tier = 0
	for i, t in Levels.Mastery do
		if kills >= t.kills then
			tier = i
		end
	end
	local nextTier = Levels.Mastery[tier + 1]
	return {
		tier = tier,
		name = if tier > 0 then Levels.Mastery[tier].name else "Unranked",
		kills = kills,
		nextAt = if nextTier then nextTier.kills else nil,
	}
end

return Levels
