--!nocheck
local T = require("./runner/T")
local L = require("./runner/Loader")
L.reset()
local A = L.require(L.Shared.Audio.ActionCues)
local C = L.require(L.Shared.Audio.LobbyCues)
T.describe("Private batch-six context audio", function()
	T.it("lobby outsiders keep range air during every global match phase", function()
		for _, phase in { "Waiting", "Voting", "Starting", "Active", "Overtime", "Results" } do
			T.expect(A.ambience("Practice", false, phase, "AmbWarehouse")).toBe("RangeAir")
		end
	end)
	T.it("participants select only their actual arena bed", function()
		for _, name in { "AmbWarehouse", "AmbDustTown", "AmbRooftops" } do
			for _, phase in { "Starting", "Active", "Overtime", "Results" } do
				T.expect(A.ambience("Match", true, phase, name)).toBe(name)
			end
		end
	end)
	T.it("reserved voting menu and unrecognized arenas remain silent", function()
		for _, phase in { "Waiting", "Voting" } do
			T.expect(A.ambience("Match", true, phase, "AmbWarehouse")).toBe(nil)
		end
		T.expect(A.ambience("Match", false, "Active", "AmbWarehouse")).toBe(nil)
		T.expect(A.ambience("Menu", false, "Waiting", nil)).toBe(nil)
		T.expect(A.ambience("Match", true, "Active", "Injected")).toBe(nil)
	end)
	T.it("unlocks substitute ordinary reward without stacking milestones", function()
		T.expect(C.rewardCue({ unlocks = 2 })).toBe("Unlock")
		T.expect(C.rewardCue({ unlocks = 2, levelBefore = 1, levelAfter = 2 })).toBe("LevelUp")
		T.expect(C.rewardCue({ unlocks = 2, levelBefore = 1, levelAfter = 2, masteryBefore = 0, masteryAfter = 1 }))
			.toBe("MasteryMilestone")
	end)
	T.it("old and malformed reward payloads stay backward compatible", function()
		for _, r in { {}, { unlocks = 0 }, { unlocks = -1 }, { unlocks = "1" } } do
			T.expect(C.rewardCue(r)).toBe("Reward")
		end
	end)
	T.it("server assist uses ordered whitelist and rejects repeats", function()
		local serial, cue = C.accept(0, { serial = 1, cue = "Assist" })
		T.expect(cue).toBe("Assist")
		local _, again = C.accept(serial, { serial = 1, cue = "Assist" })
		T.expect(again).toBe(nil)
	end)
end)
L.reset()
