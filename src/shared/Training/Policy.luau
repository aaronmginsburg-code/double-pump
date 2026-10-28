--!strict
local P = {}
-- End a range duel without changing the NPC's health, inventory or weapon rules.
function P.resetRangeCombat(bot: any)
	for _, key in
		{
			"target",
			"lastSeen",
			"seenAt",
			"seesTarget",
			"movingTarget",
			"alertUntil",
			"reactAt",
			"swapAt",
			"error",
			"nextError",
			"nextMove",
			"moveGoal",
			"patrolGoal",
			"nextPatrol",
			"nextFire",
			"nextPerception",
			"nextDecision",
		}
	do
		bot[key] = nil
	end
	bot.returning = false
end
function P.teams(list: { any }, owner: any, bots: { any }, capacity: number): any
	if
		not table.find(list, owner)
		or #bots ~= 2
		or not table.find(list, bots[1])
		or not table.find(list, bots[2])
		or #list > capacity * 2
	then
		return nil
	end
	local result = { [owner] = "Red", [bots[1]] = "Blue", [bots[2]] = "Blue" }
	local counts = { Red = 1, Blue = 2 }
	for _, p in list do
		if result[p] == nil then
			local side = if counts.Red <= counts.Blue then "Red" else "Blue"
			if counts[side] >= capacity then
				side = if side == "Red" then "Blue" else "Red"
			end
			if counts[side] >= capacity then
				return nil
			end
			result[p] = side
			counts[side] += 1
		end
	end
	return result
end
-- Preserve FIFO. A developer+pair is atomic, never admitted via a synthetic roster.
function P.selection(order: { any }, owner: any, bots: { any }, cap: number): { any }
	local out = {}
	for i = 1, math.min(cap, #order) do
		table.insert(out, order[i])
	end
	local hasOwner = table.find(out, owner) ~= nil
	local botCount = 0
	for _, b in bots do
		if table.find(out, b) then
			botCount += 1
		end
	end
	if not hasOwner and botCount == 0 then
		return out
	end
	if hasOwner and botCount == 2 then
		return out
	end
	local first = #out + 1
	for i, p in out do
		if p == owner or table.find(bots, p) then
			first = math.min(first, i)
		end
	end
	while #out >= first do
		table.remove(out)
	end
	return if #out >= 2 then out else {}
end
function P.lobbyAllowed(shooter: any, target: any, owner: any, bots: { any }, active: boolean): boolean
	return (shooter == owner and table.find(bots, target) ~= nil)
		or (active and table.find(bots, shooter) ~= nil and target == owner)
end
function P.canPerceive(distance: number, visible: boolean, alive: boolean, enemy: boolean, range: number): boolean
	return alive and enemy and visible and distance > 0 and distance <= range
end
function P.state(
	mode: string,
	alive: boolean,
	queued: boolean,
	ownerQueued: boolean,
	alert: boolean,
	combat: boolean
): string
	if not alive then
		return "Eliminated"
	end
	if mode == "Match" then
		return if combat then "MatchCombat" else "MatchPreparation"
	end
	if ownerQueued then
		return if queued then "Queued" else "QueueFollowing"
	end
	return if alert then "Engaging" else "Passive"
end
function P.reached(delta: Vector3, radius: number): boolean
	return math.abs(delta.Y) <= 6 and (delta * Vector3.new(1, 0, 1)).Magnitude < radius
end
return P
