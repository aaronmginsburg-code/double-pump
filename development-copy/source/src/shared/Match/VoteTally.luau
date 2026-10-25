--!strict
-- Map vote counting. Ties are broken by a seeded random pick among the tied maps, so
-- every tied map has an equal chance; with no votes at all, a random option other
-- than the map just played (when possible).

local VoteTally = {}

-- votes: voter -> option id. options: the ids on offer.
function VoteTally.counts(votes: { [any]: string }, options: { string }): { [string]: number }
	local counts = {}
	for _, id in options do
		counts[id] = 0
	end
	for _, id in votes do
		if counts[id] ~= nil then
			counts[id] += 1
		end
	end
	return counts
end

function VoteTally.winner(votes: { [any]: string }, options: { string }, previous: string?, rng: Random): string
	local counts = VoteTally.counts(votes, options)
	local best = -1
	local tied: { string } = {}
	for _, id in options do
		local n = counts[id]
		if n > best then
			best = n
			tied = { id }
		elseif n == best then
			table.insert(tied, id)
		end
	end
	if best == 0 and previous and #tied > 1 then
		local filtered = {}
		for _, id in tied do
			if id ~= previous then
				table.insert(filtered, id)
			end
		end
		if #filtered > 0 then
			tied = filtered
		end
	end
	return tied[rng:NextInteger(1, #tied)]
end

-- Up to `count` options from all maps. With more maps than slots the previous map is
-- left out; with exactly `count` maps all are offered.
function VoteTally.options(all: { string }, count: number, previous: string?, rng: Random): { string }
	local pool = table.clone(all)
	if #pool > count and previous then
		local i = table.find(pool, previous)
		if i then
			table.remove(pool, i)
		end
	end
	-- Fisher-Yates
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local out = {}
	for i = 1, math.min(count, #pool) do
		out[i] = pool[i]
	end
	return out
end

return VoteTally
