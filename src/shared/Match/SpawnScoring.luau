--!strict
-- Picks the safest team spawn: far from living enemies, not in an enemy's line of sight,
-- and not the spawn someone just used. Pure; the line-of-sight test is passed in.

local SpawnScoring = {}

export type Candidate = { position: Vector3, lastUsed: number }

function SpawnScoring.score(c: Candidate, enemies: { Vector3 }, now: number, radius: number, visible: (Vector3, Vector3) -> boolean): number
	local nearest = math.huge
	local seen = false
	for _, enemy in enemies do
		local d = (enemy - c.position).Magnitude
		nearest = math.min(nearest, d)
		if not seen and d < radius * 3 and visible(enemy, c.position) then
			seen = true
		end
	end
	local score = math.min(nearest, radius * 4)
	if nearest < radius then
		score -= 200 -- an enemy right next to it
	end
	if seen then
		score -= 120
	end
	-- Spread spawns out: penalise ones used in the last few seconds
	local since = now - c.lastUsed
	if since < 4 then
		score -= (4 - since) * 25
	end
	return score
end

-- Index of the best candidate (ties: the first).
function SpawnScoring.best(candidates: { Candidate }, enemies: { Vector3 }, now: number, radius: number, visible: (Vector3, Vector3) -> boolean): number?
	local bestIndex, bestScore = nil, -math.huge
	for i, c in candidates do
		local s = SpawnScoring.score(c, enemies, now, radius, visible)
		if s > bestScore then
			bestIndex, bestScore = i, s
		end
	end
	return bestIndex
end

return SpawnScoring
