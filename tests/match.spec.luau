--!nocheck
local T = require("./runner/T")
local Loader = require("./runner/Loader")
local Shared = Loader.Shared
local GameConfig = Loader.require(Shared.Config.GameConfig)
local MatchRules = Loader.require(Shared.Match.MatchRules)
local TeamBalance = Loader.require(Shared.Match.TeamBalance)
local VoteTally = Loader.require(Shared.Match.VoteTally)
local describe, it, expect = T.describe, T.it, T.expect
local C = GameConfig.Match

local function run(m, seconds, players)
	local all = {}
	local t = 0
	while t < seconds do
		for _, e in MatchRules.step(m, 0.1, { players = players }) do
			table.insert(all, e)
		end
		t += 0.1
	end
	return all
end

local function has(events, kind, field, value)
	for _, e in events do
		if e.kind == kind and (field == nil or e[field] == value) then
			return true
		end
	end
	return false
end

local function toActive(players)
	local m = MatchRules.new(C)
	run(m, 0.2, players)
	run(m, C.IntermissionTime + 0.2, players)
	run(m, C.StartingCountdown + 0.2, players)
	return m
end

describe("MatchRules", function()
	it("waits with one player (practice) and starts with two", function()
		local m = MatchRules.new(C)
		run(m, 30, 1)
		expect(m.state).toBe("Waiting")
		run(m, 0.2, 2)
		expect(m.state).toBe("Intermission")
	end)

	it("goes Intermission -> Starting -> Active with a countdown", function()
		local m = MatchRules.new(C)
		run(m, 0.2, 2)
		local ev = run(m, C.IntermissionTime + 0.2, 2)
		expect(m.state).toBe("Starting")
		ev = run(m, C.StartingCountdown + 0.2, 2)
		expect(has(ev, "Countdown", "seconds", 3)).toBeTruthy()
		expect(has(ev, "MatchStarted")).toBeTruthy()
		expect(m.state).toBe("Active")
	end)

	it("returns to Waiting if a player leaves during intermission", function()
		local m = MatchRules.new(C)
		run(m, 0.2, 2)
		run(m, 1, 1)
		expect(m.state).toBe("Waiting")
	end)

	it("ends when a team reaches the target", function()
		local m = toActive(2)
		for _ = 1, m.target - 1 do
			MatchRules.addScore(m, "Red")
		end
		expect(m.state).toBe("Active")
		local ev = MatchRules.addScore(m, "Red")
		expect(has(ev, "MatchEnded", "winner", "Red")).toBeTruthy()
		expect(m.state).toBe("Results")
		-- further kills don't count
		MatchRules.addScore(m, "Blue")
		expect(m.scores.Blue).toBe(0)
	end)

	it("time expiry: higher score wins", function()
		local m = toActive(4)
		MatchRules.addScore(m, "Blue")
		local ev = run(m, C.Duration + 1, 4)
		expect(has(ev, "MatchEnded", "winner", "Blue")).toBeTruthy()
		expect(m.endReason).toBe("Time")
	end)

	it("tie at time goes to sudden-death overtime; first kill wins", function()
		local m = toActive(4)
		run(m, C.Duration + 0.5, 4)
		expect(m.state).toBe("Overtime")
		local ev = MatchRules.addScore(m, "Red")
		expect(has(ev, "MatchEnded", "winner", "Red")).toBeTruthy()
		expect(m.endReason).toBe("Overtime")
	end)

	it("tie after overtime is a draw", function()
		local m = toActive(4)
		run(m, C.Duration + 0.5, 4)
		local ev = run(m, C.OvertimeDuration + 0.5, 4)
		expect(has(ev, "MatchEnded", "reason", "Draw")).toBeTruthy()
		expect(m.winner).toBe(nil)
	end)

	it("Results -> Voting -> Starting next match", function()
		local m = toActive(2)
		for _ = 1, m.target do
			MatchRules.addScore(m, "Blue")
		end
		local ev = run(m, C.ResultsTime + 0.2, 2)
		expect(m.state).toBe("Voting")
		ev = run(m, C.VotingTime + 0.2, 2)
		expect(has(ev, "VotingEnded")).toBeTruthy()
		expect(m.state).toBe("Starting")
		run(m, C.StartingCountdown + 0.2, 2)
		expect(m.state).toBe("Active")
		expect(m.scores.Blue).toBe(0)
		expect(m.matchNumber).toBe(2)
	end)

	it("ends a match after players leave, without breaking", function()
		local m = toActive(2)
		MatchRules.addScore(m, "Red")
		run(m, 5, 1)
		expect(m.state).toBe("Active") -- grace period
		local ev = run(m, 6, 1)
		expect(has(ev, "MatchEnded", "reason", "NotEnoughPlayers")).toBeTruthy()
		expect(m.winner).toBe("Red")
		-- And then it parks in Waiting instead of starting another match
		run(m, C.ResultsTime + C.VotingTime + 1, 1)
		expect(m.state).toBe("Waiting")
	end)

	it("never emits two MatchStarted for one countdown", function()
		local m = MatchRules.new(C)
		local ev = run(m, C.IntermissionTime + C.StartingCountdown + 5, 6)
		local n = 0
		for _, e in ev do
			if e.kind == "MatchStarted" then
				n += 1
			end
		end
		expect(n).toBe(1)
	end)

	it("scales the kill target for small lobbies", function()
		expect(MatchRules.targetFor(C, 10)).toBe(40)
		expect(MatchRules.targetFor(C, 2)).toBe(C.ScoreToWinMin)
		expect(MatchRules.targetFor(C, 6)).toBe(25)
	end)
end)

describe("TeamBalance", function()
	it("puts newcomers on the smaller team", function()
		expect(TeamBalance.pick({ Red = { 1, 2 }, Blue = { 3 } }, nil, 5)).toBe("Blue")
		expect(TeamBalance.pick({ Red = {}, Blue = { 3 } }, nil, 5)).toBe("Red")
	end)
	it("breaks ties toward the losing team", function()
		expect(TeamBalance.pick({ Red = { 1 }, Blue = { 2 } }, { Red = 10, Blue = 3 }, 5)).toBe("Blue")
	end)
	it("refuses when both teams are full", function()
		expect(TeamBalance.pick({ Red = { 1, 2, 3, 4, 5 }, Blue = { 1, 2, 3, 4, 5 } }, nil, 5)).toBe(nil)
	end)
	it("asks for a move only at the gap", function()
		local from, to = TeamBalance.needsMove({ Red = { 1, 2, 3 }, Blue = { 4 } }, 2)
		expect(from).toBe("Red")
		expect(to).toBe("Blue")
		expect((TeamBalance.needsMove({ Red = { 1, 2 }, Blue = { 4 } }, 2))).toBe(nil)
	end)
	it("splits evenly", function()
		local t = TeamBalance.split({ 1, 2, 3, 4, 5 })
		expect(#t.Red).toBe(3)
		expect(#t.Blue).toBe(2)
	end)
end)

describe("VoteTally", function()
	local rng = Loader.Random.new(7)
	it("picks the most voted map", function()
		local w = VoteTally.winner({ a = "Warehouse", b = "Rooftops", c = "Rooftops" }, { "Warehouse", "DustTown", "Rooftops" }, nil, rng)
		expect(w).toBe("Rooftops")
	end)
	it("ignores votes for maps not on offer", function()
		local counts = VoteTally.counts({ a = "Nope", b = "Warehouse" }, { "Warehouse" })
		expect(counts.Warehouse).toBe(1)
		expect(counts.Nope).toBe(nil)
	end)
	it("breaks ties fairly between the tied maps only", function()
		local seen = {}
		for i = 1, 200 do
			local r = Loader.Random.new(i)
			local w = VoteTally.winner({ a = "Warehouse", b = "DustTown" }, { "Warehouse", "DustTown", "Rooftops" }, nil, r)
			seen[w] = (seen[w] or 0) + 1
		end
		expect(seen.Rooftops).toBe(nil)
		expect(seen.Warehouse).toBeGreaterThan(50)
		expect(seen.DustTown).toBeGreaterThan(50)
	end)
	it("with no votes avoids repeating the previous map", function()
		for i = 1, 50 do
			local w = VoteTally.winner({}, { "Warehouse", "DustTown", "Rooftops" }, "Warehouse", Loader.Random.new(i))
			expect(w ~= "Warehouse").toBeTruthy()
		end
	end)
	it("offers three distinct options", function()
		local o = VoteTally.options({ "Warehouse", "DustTown", "Rooftops" }, 3, "Warehouse", rng)
		expect(#o).toBe(3)
		expect(o[1] ~= o[2] and o[2] ~= o[3] and o[1] ~= o[3]).toBeTruthy()
	end)
end)
