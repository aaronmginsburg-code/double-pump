--!strict
-- Team assignment and balancing as pure functions over team member lists.

local TeamBalance = {}

export type Teams = { [string]: { any } }

-- Team a newcomer should join: the smaller team; on a tie, the one with the lower
-- score (helps the losing side); on a further tie, Red.
function TeamBalance.pick(teams: Teams, scores: { [string]: number }?, maxSize: number): string?
	local red, blue = #teams.Red, #teams.Blue
	if red >= maxSize and blue >= maxSize then
		return nil
	end
	if red < blue then
		return "Red"
	elseif blue < red then
		return "Blue"
	end
	if scores and scores.Blue < scores.Red then
		return "Blue"
	end
	return "Red"
end

-- If the teams differ by `gap` or more, returns (fromTeam, toTeam) for one move.
function TeamBalance.needsMove(teams: Teams, gap: number): (string?, string?)
	local red, blue = #teams.Red, #teams.Blue
	if red - blue >= gap then
		return "Red", "Blue"
	elseif blue - red >= gap then
		return "Blue", "Red"
	end
	return nil, nil
end

-- Splits a list of players into two teams of equal size (± 1), keeping input order.
function TeamBalance.split(list: { any }): Teams
	local teams: Teams = { Red = {}, Blue = {} }
	for i, p in list do
		table.insert(if i % 2 == 1 then teams.Red else teams.Blue, p)
	end
	return teams
end

return TeamBalance
