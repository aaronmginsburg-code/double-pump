--!nocheck
-- Private audio presentation only; actual shared feedback and baked animation player.
local T = require("./runner/T")
local L = require("./runner/Loader")
L.reset()
local F = L.require(L.Shared.Audio.Feedback)
local Anim = L.require(L.Shared.Weapons.AnimPlayer)
local ids = L.require(L.Shared.Config.AssetIds)
T.describe("Private approved audio pilot", function()
	T.it("never confirms empty, zero or protected results", function()
		for _, results in { {}, { { damage = 0 } }, { { damage = 90, protected = true, headshot = true } } } do
			local hit = F.hit(results)
			T.expect(hit.cue).toBe(nil)
			T.expect(#hit.hits).toBe(0)
		end
	end)
	T.it("filters protected targets from mixed feedback without changing damage", function()
		local normal = { damage = 27, headshot = false }
		local hit = F.hit({ normal, { damage = 80, protected = true, headshot = true } })
		T.expect(hit.cue).toBe("HitBody")
		T.expect(hit.headshot).toBe(false)
		T.expect(hit.hits[1]).toBe(normal)
		T.expect(normal.damage).toBe(27)
	end)
	T.it("selects one head cue for a multi-target blast", function()
		local hit = F.hit({ { damage = 20 }, { damage = 45, headshot = true } })
		T.expect(hit.cue).toBe("HitHead")
		T.expect(#hit.hits).toBe(2)
	end)
	T.it("retains elimination priority and double pump identity", function()
		T.expect(F.hit({ { damage = 20, killed = true } }).cue).toBe("Elimination")
		T.expect(F.hit({ { damage = 20, killed = true, doublePump = true } }).cue).toBe("DoublePumpElim")
	end)
	T.it("does not treat a nonlethal double-pump flag as an elimination", function()
		T.expect(F.hit({ { damage = 20, doublePump = true } }).cue).toBe("HitBody")
	end)
	T.it("dummy clears use ordinary hit confirmation", function()
		T.expect(F.hit({ { damage = 100, killed = true, dummy = true, doublePump = true } }).cue).toBe("HitBody")
		T.expect(F.hit({ { damage = 100, headshot = true, killed = true, dummy = true } }).cue).toBe("HitHead")
	end)
	T.it("mixed dummy and player kills keep only player prestige", function()
		T.expect(F.hit({
			{ damage = 100, killed = true, dummy = true, doublePump = true },
			{ damage = 50, killed = true, dummy = false },
		}).cue).toBe("Elimination")
	end)
	T.it("maps only the two existing pump markers", function()
		T.expect(F.pumpCue("PumpBack")).toBe("PumpBack")
		T.expect(F.pumpCue("PumpForward")).toBe("PumpForward")
		for _, event in { "Fire", "ShellEject", "Pump", "RecoverEnd" } do
			T.expect(F.pumpCue(event)).toBe(nil)
		end
	end)
	for _, pair in { { "FirstPerson", "Pump", "SwapIn" }, { "ThirdPerson", "TP_Pump", "TP_Pump" } } do
		T.it(pair[1] .. " emits each stroke once at unchanged marker times", function()
			local anim, cues = Anim.new(pair[1]), {}
			local back, forward = anim:eventTime(pair[2], "PumpBack"), anim:eventTime(pair[2], "PumpForward")
			T.expect(back).toBe(0.1833)
			T.expect(forward).toBe(0.4333)
			anim:play(pair[2], {
				onEvent = function(event)
					local cue = F.pumpCue(event)
					if cue then
						table.insert(cues, cue)
					end
				end,
			})
			anim:update(back - 0.001)
			T.expect(#cues).toBe(0)
			for _ = 1, 120 do
				anim:update(1 / 120)
			end
			T.expect(cues).toEqual({ "PumpBack", "PumpForward" })
		end)
		T.it(pair[1] .. " action replacement suppresses obsolete pump markers", function()
			local anim, cues = Anim.new(pair[1]), {}
			anim:play(pair[2], {
				onEvent = function(event)
					local cue = F.pumpCue(event)
					if cue then
						table.insert(cues, cue)
					end
				end,
			})
			anim:update(0.2)
			anim:play(pair[3])
			anim:update(0.5)
			T.expect(cues).toEqual({ "PumpBack" })
		end)
	end
	T.it("uses exactly the fifty-one uploaded owner-selected identifiers", function()
		local expected = {
			StepConcrete = "127480360069744",
			StepMetal = "87968940009629",
			StepSand = "96114396174087",
			StepWood = "118025107093825",
			Landing = "119227276951004",

			Fire = "76270373964419",
			PumpBack = "110029776273911",
			PumpForward = "82334124029040",
			Swap = "120708988258180",
			EmptyClick = "129023358510589",
			HitBody = "122067256034974",
			HitHead = "105275885463350",
			DamageTaken = "103016997503788",
			Equip = "76066705752904",
			ReloadStart = "95926422694750",
			ShellInsert = "102336135537532",
			ShellBounce = "85310208341495",
			Elimination = "93718579667184",
			DoublePumpElim = "83664872569347",
			Death = "105465906827933",
			Spawn = "81574290995171",
			CountdownTick = "95699893390042",
			MatchStart = "100823336379034",
			MatchEnd = "128914040219922",
			Victory = "128338264574038",
			Defeat = "74379053980430",
			UIClick = "97692260400881",
			Reward = "90581179107431",
			Vote = "83424934876088",
			QueueJoin = "109535765491493",
			QueueLeave = "124530677310844",
			QueueCountdown = "136743664945691",
			QueueCancel = "90412393185987",
			Admitted = "73939245280780",
			ReturnToRange = "111267390132943",
			LevelUp = "130023511315158",
			MasteryMilestone = "85511675749835",
			Unlock = "132043275280472",
			Assist = "72366323452361",
			RangeAir = "107314588536789",
			AmbWarehouse = "95360702770922",
			AmbDustTown = "130680677216207",
			AmbRooftops = "127043544223367",

			ReloadEnd = "91588700050239",
			ImpactHard = "128202319714882",
			ImpactMetal = "82455709298224",
			ImpactWood = "125794832817300",
			Overtime = "131993078530333",
			TimeWarning = "107321103973404",
			Error = "133238281799902",
			Confirm = "119959350292311",
		}
		local count = 0
		for cue, id in ids.Sounds do
			if id ~= "" then
				count += 1
				T.expect(id).toBe(expected[cue])
			end
		end
		T.expect(count).toBe(51)
	end)
end)
L.reset()

-- Exercise the real client router with fake Roblox services. This proves typed
-- preloading/routing only, never network availability or audible quality.
local savedInstance, savedTask = L.Instance, L.task
local savedServices = table.clone(L.services)
local made, preloaded = {}, {}
L.Instance = {
	new = function(class)
		local i = { ClassName = class, Volume = 1, Ended = { Once = function() end } }
		function i:Destroy()
			self.destroyed = true
		end
		function i:Play()
			self.played = true
		end
		table.insert(made, i)
		return i
	end,
}
L.task = table.clone(savedTask)
L.task.delay = function() end
L.services.SoundService = {}
L.services.Debris = { AddItem = function() end }
L.services.TweenService = {}
L.services.ContentProvider = {
	PreloadAsync = function(_, items, callback)
		for _, item in items do
			assert(item.ClassName == "Sound", "Raw asset strings are ambiguous image requests")
			table.insert(preloaded, item)
			callback(item.SoundId, L.roblox.Enum.AssetFetchStatus.Success)
		end
	end,
}
local controllers = L.game:GetService("StarterPlayer").StarterPlayerScripts.Client.Controllers
L.inject(
	controllers.Settings,
	{ values = { masterVolume = 0.8, musicVolume = 0.5, effectsVolume = 1 }, Changed = { Connect = function() end } }
)
local lobbyListener
local networkListeners = {}
L.inject(L.Shared.Net, {
	event = function(name)
		return {
			OnClientEvent = {
				Connect = function(_, fn)
					networkListeners[name] = fn
					if name == "MatchEvent" then
						lobbyListener = fn
					end
				end,
			},
		}
	end,
})
local audio = L.require(controllers.AudioController)
T.describe("Actual private AudioController routing (offline mocks)", function()
	T.it("preloads forty-six typed sound instances and cleans the temporary objects", function()
		audio.start()
		T.expect(#preloaded).toBe(51)
		for _, item in preloaded do
			T.expect(item.SoundId:match("^rbxassetid://%d+$") ~= nil).toBe(true)
			T.expect(item.destroyed).toBe(true)
		end
	end)
	T.it("only dispatches one sound for a valid ordered lobby event", function()
		local before = #made
		lobbyListener("LobbyAudio", { serial = 1, cue = "QueueJoin" })
		T.expect(#made).toBe(before + 1)
		T.expect(made[#made].SoundId).toBe("rbxassetid://109535765491493")
		lobbyListener("LobbyAudio", { serial = 1, cue = "QueueJoin" })
		lobbyListener("LobbyAudio", { serial = 2, cue = "Fire" })
		lobbyListener("Started", { serial = 2, cue = "QueueJoin" })
		T.expect(#made).toBe(before + 1)
		lobbyListener("LobbyAudio", { serial = 2, cue = "QueueCancel" })
		T.expect(#made).toBe(before + 2)
	end)
	T.it("routes the selected fire sound through the existing Effects group and gain", function()
		local sound = audio.play("Fire")
		T.expect(sound.SoundId).toBe("rbxassetid://76270373964419")
		T.expect(sound.Volume).toBe(0.9)
		T.expect(sound.SoundGroup.Name).toBe("Effects")
		T.expect(sound.Parent).toBe(L.services.SoundService)
		T.expect(sound.played).toBe(true)
	end)
	T.it("routes the approved UI click through UI at the existing gain", function()
		local sound = audio.play("UIClick")
		T.expect(sound.SoundId).toBe("rbxassetid://97692260400881")
		T.expect(sound.SoundGroup.Name).toBe("UI")
		T.expect(sound.Volume).toBe(0.45)
	end)
	T.it("keeps result and reward cues in the existing Effects mix", function()
		for name, gain in
			{
				CountdownTick = 0.6,
				MatchStart = 0.7,
				MatchEnd = 0.7,
				Victory = 0.75,
				Defeat = 0.7,
				Vote = 0.5,
				Reward = 0.55,
			}
		do
			local sound = audio.play(name)
			T.expect(sound.SoundGroup.Name).toBe("Effects")
			T.expect(sound.Volume).toBe(gain)
		end
	end)
	T.it("distinguishes real configured cues from blank future cues", function()
		T.expect(audio.configured("HitHead")).toBe(true)
		T.expect(audio.configured("MusicMenu")).toBe(false)
	end)
end)
T.describe("Actual batch-five confirmed UI audio routing", function()
	T.it("keeps first/repeated snapshots silent and confirms changed equipped skin once", function()
		local before = #made
		networkListeners.ProfileEvent("Profile", { equipped = { skin = "default" } })
		networkListeners.ProfileEvent("Profile", { equipped = { skin = "default" } })
		T.expect(#made).toBe(before)
		networkListeners.ProfileEvent("Profile", { equipped = { skin = "gold" } })
		T.expect(#made).toBe(before + 1)
		T.expect(made[#made].Name).toBe("Confirm")
		T.expect(made[#made].SoundGroup.Name).toBe("UI")
		networkListeners.Notify("Bought skin", "good")
		T.expect(#made).toBe(before + 1)
	end)
	T.it("debounces confirmed error notices without parsing their text", function()
		local before = #made
		networkListeners.Notify("arbitrary normal notification", nil)
		T.expect(#made).toBe(before)
		networkListeners.Notify("server rejected", "error")
		T.expect(#made).toBe(before + 1)
		T.expect(made[#made].Name).toBe("Error")
		networkListeners.Notify("repeat", "error")
		T.expect(#made).toBe(before + 1)
	end)
end)
-- Lune does not provide Roblox TweenInfo; supply only this engine value boundary.
getfenv(audio.setAmbience).TweenInfo = {
	new = function(time)
		return { Time = time }
	end,
}
T.describe("Actual contextual ambience lifecycle", function()
	local previous
	L.services.TweenService.Create = function(_, sound, ti, values)
		return {
			Play = function()
				for k, v in values do
					sound[k] = v
				end
			end,
		}
	end
	T.it("creates one quiet loop and does not restart it on repeated refresh", function()
		audio.setAmbience("RangeAir")
		previous = made[#made]
		T.expect(previous.Name).toBe("RangeAir")
		T.expect(previous.Looped).toBe(true)
		T.expect(previous.Volume).toBe(0.025)
		local n = #made
		audio.setAmbience("RangeAir")
		T.expect(#made).toBe(n)
	end)
	T.it("destroys outgoing bed before starting the next", function()
		audio.setAmbience("AmbWarehouse")
		T.expect(previous.destroyed).toBe(true)
		previous = made[#made]
		T.expect(previous.Name).toBe("AmbWarehouse")
	end)
	T.it("coalesces rapid map changes and stops on exit", function()
		local wait = L.task.wait
		local changed = false
		L.task.wait = function()
			if not changed then
				changed = true
				audio.setAmbience("AmbRooftops")
			end
			return 0
		end
		local n = #made
		audio.setAmbience("AmbDustTown")
		T.expect(previous.destroyed).toBe(true)
		T.expect(#made).toBe(n + 1)
		previous = made[#made]
		T.expect(previous.Name).toBe("AmbRooftops")
		L.task.wait = wait
		audio.setAmbience(nil)
		T.expect(previous.destroyed).toBe(true)
	end)
end)
L.Instance, L.task = savedInstance, savedTask
L.services = savedServices
L.reset()
