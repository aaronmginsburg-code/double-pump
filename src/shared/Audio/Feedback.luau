--!strict
-- Presentation decisions only. Damage and eligibility remain server-authoritative.
local Feedback = {}

function Feedback.pumpCue(event: string): string?
	return if event == "PumpBack" or event == "PumpForward" then event else nil
end

function Feedback.hit(results: { any })
	local hits = {}
	local headshot, killed, playerKill, doublePump = false, false, false, false
	for _, result in results do
		if result.protected or typeof(result.damage) ~= "number" or result.damage <= 0 then
			continue
		end
		table.insert(hits, result)
		headshot = headshot or result.headshot == true
		killed = killed or result.killed == true
		playerKill = playerKill or (result.killed == true and result.dummy ~= true)
		doublePump = doublePump or (result.killed == true and result.dummy ~= true and result.doublePump == true)
	end
	local cue = if #hits == 0
		then nil
		elseif playerKill then (if doublePump then "DoublePumpElim" else "Elimination")
		elseif headshot then "HitHead"
		else "HitBody"
	return { hits = hits, headshot = headshot, killed = killed, cue = cue }
end

return Feedback
