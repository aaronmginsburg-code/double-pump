--!strict
-- Presentation only: called with server-validated occupancy, never client intent.
local LobbyCues = {}
export type State = { queued: boolean, phase: string, second: number?, boundaryAt: number }
function LobbyCues.new(): State
	return { queued = false, phase = "Waiting", second = nil, boundaryAt = -math.huge }
end
function LobbyCues.step(
	s: State,
	queued: boolean,
	phase: string,
	second: number,
	now: number,
	selected: boolean
): string?
	local previousQueued, previousPhase, previousSecond = s.queued, s.phase, s.second
	s.queued, s.phase = queued, phase
	s.second = if queued and phase == "Countdown" then second else nil
	if selected then
		return nil
	end -- Admission gets its own cue only after reservation.
	if previousQueued ~= queued then
		if now - s.boundaryAt < 1 then
			return nil
		end
		s.boundaryAt = now
		return if queued then "QueueJoin" else "QueueLeave"
	end
	if queued and previousPhase == "Countdown" and phase == "Waiting" then
		return "QueueCancel"
	end
	if queued and phase == "Countdown" and second > 0 and (previousPhase ~= phase or previousSecond ~= second) then
		return "QueueCountdown"
	end
	return nil
end
local allowed = {
	Assist = true,
	Overtime = true,
	TimeWarning = true,
	QueueJoin = true,
	QueueLeave = true,
	QueueCountdown = true,
	QueueCancel = true,
	Admitted = true,
	ReturnToRange = true,
}
function LobbyCues.accept(last: number, payload: any): (number, string?)
	if
		typeof(payload) ~= "table"
		or typeof(payload.serial) ~= "number"
		or payload.serial ~= payload.serial
		or payload.serial == math.huge
		or payload.serial % 1 ~= 0
		or payload.serial <= last
		or typeof(payload.cue) ~= "string"
		or not allowed[payload.cue]
	then
		return last, nil
	end
	return payload.serial, payload.cue
end
function LobbyCues.rewardCue(reward: any): string
	if
		typeof(reward.masteryBefore) == "number"
		and typeof(reward.masteryAfter) == "number"
		and reward.masteryAfter > reward.masteryBefore
	then
		return "MasteryMilestone"
	end
	if
		typeof(reward.levelBefore) == "number"
		and typeof(reward.levelAfter) == "number"
		and reward.levelAfter > reward.levelBefore
	then
		return "LevelUp"
	end
	if typeof(reward.unlocks) == "number" and reward.unlocks > 0 then
		return "Unlock"
	end
	return "Reward"
end
return LobbyCues
