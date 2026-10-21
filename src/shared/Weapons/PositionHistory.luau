--!strict
-- Ring buffer of body-part CFrames per character for lag compensation: the server
-- checks a claimed hit against where the target was when the shooter saw it.

local PositionHistory = {}
PositionHistory.__index = PositionHistory

export type Snapshot = { t: number, parts: { [string]: CFrame } }
export type History = typeof(setmetatable({} :: { snapshots: { Snapshot }, maxAge: number }, PositionHistory))

function PositionHistory.new(maxAge: number): History
	return setmetatable({ snapshots = {}, maxAge = maxAge }, PositionHistory)
end

function PositionHistory.record(self: History, t: number, parts: { [string]: CFrame })
	table.insert(self.snapshots, { t = t, parts = parts })
	-- Drop old ones (keep at least one older than maxAge so interpolation has a bracket)
	while #self.snapshots > 2 and self.snapshots[2].t < t - self.maxAge do
		table.remove(self.snapshots, 1)
	end
end

-- CFrame of a part at time t (linear interpolation between snapshots; clamps to ends).
function PositionHistory.sample(self: History, partName: string, t: number): CFrame?
	local snaps = self.snapshots
	local n = #snaps
	if n == 0 then
		return nil
	end
	if t >= snaps[n].t then
		return snaps[n].parts[partName]
	end
	if t <= snaps[1].t then
		return snaps[1].parts[partName]
	end
	for i = n - 1, 1, -1 do
		local a = snaps[i]
		if a.t <= t then
			local b = snaps[i + 1]
			local ca, cb = a.parts[partName], b.parts[partName]
			if not ca or not cb then
				return ca or cb
			end
			local alpha = (t - a.t) / math.max(b.t - a.t, 1e-6)
			return ca:Lerp(cb, alpha)
		end
	end
	return snaps[1].parts[partName]
end

function PositionHistory.clear(self: History)
	table.clear(self.snapshots)
end

return PositionHistory
