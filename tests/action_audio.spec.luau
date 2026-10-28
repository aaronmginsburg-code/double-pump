--!nocheck
local T = require("./runner/T")
local L = require("./runner/Loader")
L.reset()
local C = L.require(L.Shared.Audio.ActionCues)
local R = L.roblox
T.describe("Private batch-five audio decisions", function()
	T.it("maps steel and wood material families", function()
		for _, n in { "Metal", "DiamondPlate", "CorrodedMetal", "Foil" } do
			T.expect(C.impactCue(n, false)).toBe("ImpactMetal")
		end
		for _, n in { "Wood", "WoodPlanks" } do
			T.expect(C.impactCue(n, false)).toBe("ImpactWood")
		end
		T.expect(C.impactCue("Concrete", false)).toBe("ImpactHard")
	end)
	T.it("never creates world-impact cues for characters or soft surfaces", function()
		T.expect(C.impactCue("Metal", true)).toBe(nil)
		for _, n in { "Water", "Air", "Grass", "Sand", "Fabric" } do
			T.expect(C.impactCue(n, false)).toBe(nil)
		end
	end)
	local function hit(material, character)
		return {
			instance = {},
			material = R.Enum.Material[material],
			position = R.Vector3.zero,
			isCharacter = character,
		}
	end
	T.it("aggregates a ten-pellet wall contact to one cue", function()
		local hits = {}
		for _ = 1, 10 do
			table.insert(hits, hit("Concrete", false))
		end
		T.expect(#C.impacts(hits)).toBe(1)
	end)
	T.it("caps mixed world materials at two distinct cues per blast", function()
		local cues = C.impacts({
			hit("Concrete", true),
			hit("Concrete", false),
			hit("Concrete", false),
			hit("Metal", false),
			hit("Wood", false),
		})
		T.expect(#cues).toBe(2)
		T.expect(cues[1].cue).toBe("ImpactHard")
		T.expect(cues[2].cue).toBe("ImpactMetal")
	end)
	T.it("ignores misses and never modifies hit data", function()
		local h = hit("Wood", false)
		local list = { h, { position = R.Vector3.zero } }
		T.expect(#C.impacts(list)).toBe(1)
		T.expect(h.isCharacter).toBe(false)
		T.expect(#list).toBe(2)
	end)
	T.it("warns once on the authoritative thirty-second crossing", function()
		local s = C.newClock()
		T.expect(C.clock(s, 1, "Active", 300)).toBe(nil)
		T.expect(C.clock(s, 1, "Active", 30.1)).toBe(nil)
		T.expect(C.clock(s, 1, "Active", 29.9)).toBe("TimeWarning")
		T.expect(C.clock(s, 1, "Active", 29)).toBe(nil)
		C.clock(s, 1, "Active", 45)
		T.expect(C.clock(s, 1, "Active", 20)).toBe(nil)
	end)
	T.it("overtime is distinct and emits only on phase entry", function()
		local s = C.newClock()
		C.clock(s, 1, "Active", 1)
		T.expect(C.clock(s, 1, "Overtime", 60)).toBe("Overtime")
		T.expect(C.clock(s, 1, "Overtime", 59)).toBe(nil)
		T.expect(C.clock(s, 1, "Results", 0)).toBe(nil)
	end)
	T.it("resets time-warning eligibility for a new match", function()
		local s = C.newClock()
		C.clock(s, 1, "Active", 31)
		C.clock(s, 1, "Active", 30)
		C.clock(s, 2, "Active", 300)
		T.expect(C.clock(s, 2, "Active", 30)).toBe("TimeWarning")
	end)
	T.it("does not announce waiting voting zero-time or initial low snapshot", function()
		local s = C.newClock()
		T.expect(C.clock(s, 1, "Active", 20)).toBe(nil)
		T.expect(C.clock(s, 1, "Waiting", 0)).toBe(nil)
		T.expect(C.clock(s, 1, "Voting", 20)).toBe(nil)
		C.clock(s, 2, "Active", 31)
		T.expect(C.clock(s, 2, "Active", 0)).toBe(nil)
	end)
	T.it("initial unchanged and malformed profiles do not confirm an equip", function()
		local skin, changed = C.skinChanged(nil, { equipped = { skin = "default" } })
		T.expect(skin).toBe("default")
		T.expect(changed).toBe(false)
		local _, same = C.skinChanged(skin, { equipped = { skin = "default" } })
		T.expect(same).toBe(false)
		local old, invalid = C.skinChanged(skin, {})
		T.expect(old).toBe("default")
		T.expect(invalid).toBe(false)
	end)
	T.it("a changed server profile confirms the new skin", function()
		local skin, changed = C.skinChanged("default", { equipped = { skin = "gold" } })
		T.expect(skin).toBe("gold")
		T.expect(changed).toBe(true)
	end)
	T.it("uses the existing unmodified reload completion marker", function()
		local Anim = L.require(L.Shared.Weapons.AnimPlayer)
		local p = Anim.new("FirstPerson")
		T.expect(p:eventTime("ReloadEnd", "ReloadDone")).toBe(0.3)
		local count = 0
		p:play("ReloadEnd", {
			onEvent = function(e)
				if e == "ReloadDone" then
					count += 1
				end
			end,
		})
		p:update(0.29)
		T.expect(count).toBe(0)
		p:update(0.02)
		p:update(1)
		T.expect(count).toBe(1)
	end)
end)
L.reset()
