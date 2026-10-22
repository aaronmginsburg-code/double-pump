--!strict
-- Pure FIFO queue. Occupancy is supplied by the server on every step, including
-- the final step at the countdown deadline. No client can enqueue itself.
local LobbyQueue = {}

export type Queue = {
	config: { Minimum: number, Capacity: number, Countdown: number },
	order: { any },
	deadline: number?,
}

function LobbyQueue.new(config: { Minimum: number, Capacity: number, Countdown: number }): Queue
	return { config = config, order = {}, deadline = nil }
end

function LobbyQueue.contains(cframe: CFrame, size: Vector3, point: Vector3): boolean
	local p = cframe:PointToObjectSpace(point)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

function LobbyQueue.step(q: Queue, occupants: { any }, now: number, available: boolean): ({ any }, string)
	local present, seen = {}, {}
	for _, key in occupants do
		present[key] = true
	end
	local order = {}
	for _, key in q.order do
		if present[key] then
			seen[key] = true
			table.insert(order, key)
		end
	end
	for _, key in occupants do
		if not seen[key] then
			seen[key] = true
			table.insert(order, key)
		end
	end
	q.order = order
	if not available or #order < q.config.Minimum then
		q.deadline = nil
		return {}, if available then "Waiting" else "Pending"
	end
	if not q.deadline then
		q.deadline = now + q.config.Countdown
	end
	if now < (q.deadline :: number) then
		return {}, "Countdown"
	end
	local selected = {}
	for _ = 1, math.min(q.config.Capacity, #order) do
		table.insert(selected, table.remove(order, 1))
	end
	q.deadline = nil
	return selected, "Admitting"
end

return LobbyQueue
