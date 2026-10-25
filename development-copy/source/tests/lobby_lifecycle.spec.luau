--!nocheck
-- Exercise the actual coordinator; replace only engine/network/service boundaries.
local T = require("./runner/T")
local Loader = require("./runner/Loader")
local R = Loader.roblox
local expect, it = T.expect, T.it

local function fixture(fn)
	local savedServices, savedTask, savedInstance = table.clone(Loader.services), Loader.task, Loader.Instance
	Loader.reset()
	local ok, err = xpcall(function()
		local Signal = Loader.require(Loader.Shared.Util.Signal)
		local now, players, events, delayed, spawns = 0, {}, {}, {}, {}
		local function object()
			local attrs = {}
			return {
				GetAttribute = function(_, k)
					return attrs[k]
				end,
				SetAttribute = function(_, k, v)
					attrs[k] = v
				end,
			}
		end
		Loader.Instance = {
			new = function()
				return object()
			end,
		}
		Loader.task = {
			spawn = function(f, ...)
				return f(...)
			end,
			defer = function(f, ...)
				return f(...)
			end,
			delay = function(_, f, ...)
				table.insert(delayed, { f = f, args = { ... } })
				return {}
			end,
			cancel = function() end,
		}
		local ps = {
			PlayerAdded = Signal.new(),
			PlayerRemoving = Signal.new(),
			GetPlayers = function()
				return table.clone(players)
			end,
			GetPlayerFromCharacter = function(_, c)
				for _, p in players do
					if p.Character == c then
						return p
					end
				end
				return nil
			end,
		}
		Loader.services.Players = ps
		Loader.services.CollectionService = {}
		Loader.services.ReplicatedStorage = { Shared = Loader.Shared }
		Loader.services.Workspace = {
			GetServerTimeNow = function()
				return now
			end,
			FindFirstChild = function()
				return {}
			end,
		}
		local heartbeat = Signal.new()
		Loader.services.RunService = { Heartbeat = heartbeat }
		local remotes = {}
		Loader.inject(Loader.Shared.Net, {
			event = function(name)
				if not remotes[name] then
					remotes[name] = {
						OnServerEvent = Signal.new(),
						FireClient = function(_, p, kind, data)
							table.insert(events, { p = p, kind = kind, data = data })
						end,
					}
				end
				return remotes[name]
			end,
		})
		local chars = {
			Spawned = Signal.new(),
			Died = Signal.new(),
			setFrozen = function(c, f)
				c:SetAttribute("Frozen", f)
			end,
		}
		function chars.spawn(p, cf)
			local c = object()
			c.Name = p.Name
			local h = { Health = 100 }
			local root = { Position = cf.Position + R.Vector3.new(0, 3, 0) }
			c.FindFirstChild = function(_, name)
				return if name == "HumanoidRootPart" then root else nil
			end
			c.FindFirstChildOfClass = function()
				return h
			end
			p.Character = c
			table.insert(spawns, { p = p, cf = cf })
			chars.Spawned:Fire(p, c)
		end
		Loader.inject(Loader.Server.Services.CharacterService, chars)
		chars.transfer = chars.spawn
		local damage =
			{ Damaged = Signal.new(), Eliminated = Signal.new(), forget = function() end, kill = function() end }
		Loader.inject(Loader.Server.Services.DamageService, damage)
		local combat = {
			ShotFired = Signal.new(),
			setCanFire = function(f)
				combatCanFire = f
			end,
			setWorldRoots = function() end,
		}
		Loader.inject(Loader.Server.Services.CombatService, combat)
		local teams = { Red = { Name = "Red" }, Blue = { Name = "Blue" } }
		Loader.inject(Loader.Server.Services.TeamService, {
			teamOf = function(p)
				return p.Team and p.Team.Name
			end,
			clear = function(p)
				p.Team = nil
			end,
			reshuffle = function(list)
				for i, p in list do
					p.Team = if i % 2 == 1 then teams.Red else teams.Blue
				end
			end,
			rebalance = function() end,
		})
		Loader.inject(Loader.Shared.Match.SpawnScoring, {
			best = function()
				return 1
			end,
		})
		local arena = false
		local map = {
			Registry = {
				Range = { origin = R.Vector3.new(-1200, 0, 0) },
				Warehouse = { displayName = "Warehouse" },
				DustTown = { displayName = "Dust Town" },
				Rooftops = { displayName = "Rooftops" },
			},
			ArenaIds = { "Warehouse", "DustTown", "Rooftops" },
			worldRoots = function()
				return {}
			end,
			useRangeLighting = function() end,
			rangeSpawns = function()
				return { { Position = R.Vector3.new(-1254, 0.5, 0), CFrame = R.CFrame.new(-1254, 0.5, 0) } }
			end,
			spawns = function(team)
				local x = if team == "Red" then -65 else 65
				return { { Position = R.Vector3.new(x, 0.5, 0), CFrame = R.CFrame.new(x, 0.5, 0) } }
			end,
			arena = function()
				return arena
			end,
			killY = function()
				return -40
			end,
		}
		function map.load(id)
			map.currentId = id
			arena = true
		end
		Loader.inject(Loader.Server.Services.MapService, map)
		Loader.inject(Loader.Server.Maps.QueueZone, {
			build = function()
				return function() end
			end,
		})
		local service = Loader.require(Loader.Server.Services.MatchService)
		local context = Loader.require(Loader.Server.Services.CombatContext)
		service.start()
		local f = {
			service = service,
			chars = chars,
			damage = damage,
			context = context,
			combat = combat,
			events = events,
			spawns = spawns,
		}
		function f.add(id)
			local p = object()
			p.Name = "Player" .. id
			p.DisplayName = p.Name
			p.UserId = id
			p.Parent = true
			table.insert(players, p)
			ps.PlayerAdded:Fire(p)
			return p
		end
		function f.remove(p)
			table.remove(players, table.find(players, p))
			p.Parent = nil
			ps.PlayerRemoving:Fire(p)
		end
		function f.move(p, inside)
			p.Character:FindFirstChild("HumanoidRootPart").Position = if inside
				then R.Vector3.new(-1252, 3.5, 37)
				else R.Vector3.new(-1254, 3.5, 0)
		end
		function f.tick(dt)
			now += dt
			heartbeat:Fire(dt)
		end
		function f.action(p, kind, value)
			remotes.PlayerAction.OnServerEvent:Fire(p, kind, value)
		end
		function f.admit(a, b)
			f.move(a, true)
			f.move(b, true)
			f.tick(0.1)
			f.tick(15)
		end
		function f.active(a, b)
			f.admit(a, b)
			f.tick(12)
			f.tick(5)
		end
		fn(f)
	end, debug.traceback)
	table.clear(Loader.services)
	for k, v in savedServices do
		Loader.services[k] = v
	end
	Loader.task, Loader.Instance = savedTask, savedInstance
	Loader.reset()
	assert(ok, err)
end

T.describe("Lobby lifecycle coordinator", function()
	it("joins armed in range without server population matchmaking", function()
		fixture(function(f)
			local a, b = f.add(1), f.add(2)
			f.tick(100)
			for _, p in { a, b } do
				expect(f.service.modeOf(p)).toBe("Practice")
				expect(p.Team).toBe(nil)
				expect(p.Character:FindFirstChild("HumanoidRootPart").Position.X).toBe(-1254)
			end
			expect(f.service.state()).toBe("Waiting")
		end)
	end)
	it("legacy Deploy remotes cannot admit players", function()
		fixture(function(f)
			local a, b = f.add(1), f.add(2)
			f.action(a, "Deploy")
			f.action(b, "Deploy")
			f.service.setMode(a, "Match")
			f.tick(100)
			expect(f.service.modeOf(a)).toBe("Practice")
			expect(f.service.state()).toBe("Waiting")
		end)
	end)
	it("requires both players physically present before countdown", function()
		fixture(function(f)
			local a, b = f.add(1), f.add(2)
			f.move(a, true)
			f.tick(100)
			expect(a:GetAttribute("Queued")).toBe(true)
			expect(b:GetAttribute("Queued")).toBe(false)
			expect(f.service.state()).toBe("Waiting")
			f.move(b, true)
			f.tick(0.1)
			f.tick(14.9)
			expect(f.service.state()).toBe("Waiting")
			f.tick(0.2)
			expect(f.service.state()).toBe("Voting")
		end)
	end)
	it("only selected roster receives voting, arena spawn and starting messages", function()
		fixture(function(f)
			local a, b, c = f.add(1), f.add(2), f.add(3)
			f.active(a, b)
			expect(f.service.state()).toBe("Active")
			expect(f.service.modeOf(c)).toBe("Practice")
			expect(c.Team).toBe(nil)
			expect(math.abs(a.Character:FindFirstChild("HumanoidRootPart").Position.X)).toBe(65)
			for _, e in f.events do
				if e.kind == "Voting" or e.kind == "Starting" or e.kind == "Started" then
					expect(e.p == c).toBe(false)
				end
			end
		end)
	end)
	it("leaving at deadline cancels admission", function()
		fixture(function(f)
			local a, b = f.add(1), f.add(2)
			f.move(a, true)
			f.move(b, true)
			f.tick(0.1)
			f.move(b, false)
			f.tick(15)
			expect(f.service.state()).toBe("Waiting")
			expect(f.service.modeOf(a)).toBe("Practice")
		end)
	end)
	it("disconnect at countdown completion removes membership", function()
		fixture(function(f)
			local a, b = f.add(1), f.add(2)
			f.move(a, true)
			f.move(b, true)
			f.tick(0.1)
			f.remove(b)
			f.tick(15)
			expect(f.service.state()).toBe("Waiting")
			expect(a:GetAttribute("Queued")).toBe(true)
		end)
	end)
	it("reset characters lose queue eligibility until a valid spawn completes", function()
		fixture(function(f)
			local a, b = f.add(1), f.add(2)
			f.move(a, true)
			f.move(b, true)
			f.tick(0.1)
			b.Character:FindFirstChildOfClass("Humanoid").Health = 0
			f.tick(15)
			expect(f.service.state()).toBe("Waiting")
			expect(b:GetAttribute("Queued")).toBe(false)
		end)
	end)
	it("late joiners and waiting queue cannot enter the ongoing match", function()
		fixture(function(f)
			local a, b = f.add(1), f.add(2)
			f.active(a, b)
			local c, d = f.add(3), f.add(4)
			f.move(c, true)
			f.move(d, true)
			f.tick(20)
			expect(f.service.state()).toBe("Active")
			expect(f.service.modeOf(c)).toBe("Practice")
			expect(c:GetAttribute("Queued")).toBe(true)
		end)
	end)
	it("results finish before return, replenishment and no automatic requeue", function()
		fixture(function(f)
			local a, b = f.add(1), f.add(2)
			f.active(a, b)
			f.service._match.state = "Results"
			f.service._match.timeLeft = 9
			a.Character:FindFirstChildOfClass("Humanoid").Health = 20
			f.tick(8)
			expect(f.service.modeOf(a)).toBe("Match")
			f.tick(1)
			expect(f.service.state()).toBe("Waiting")
			expect(f.service.modeOf(a)).toBe("Practice")
			expect(a.Team).toBe(nil)
			expect(a.Character:FindFirstChildOfClass("Humanoid").Health).toBe(100)
			expect(a.Character:FindFirstChild("HumanoidRootPart").Position.X).toBe(-1254)
			f.tick(100)
			expect(a:GetAttribute("Queued")).toBe(false)
			expect(f.service.state()).toBe("Waiting")
		end)
	end)
	it("waiting next roster gets a fresh countdown only after arena releases", function()
		fixture(function(f)
			local a, b = f.add(1), f.add(2)
			f.active(a, b)
			local c, d = f.add(3), f.add(4)
			f.move(c, true)
			f.move(d, true)
			f.tick(1)
			f.service._match.state = "Results"
			f.service._match.timeLeft = 0
			f.tick(0.1)
			f.tick(0.1)
			expect(f.service.state()).toBe("Waiting")
			f.tick(15)
			expect(f.service.state()).toBe("Voting")
			expect(f.service.modeOf(c)).toBe("Match")
			expect(f.service.modeOf(a)).toBe("Practice")
		end)
	end)
	it("only roster players can vote", function()
		fixture(function(f)
			local a, b, c = f.add(1), f.add(2), f.add(3)
			f.admit(a, b)
			local before = #f.events
			f.action(c, "Vote", "Warehouse")
			expect(#f.events).toBe(before)
		end)
	end)
	it("lobby eliminations cannot contribute deaths or scoring", function()
		fixture(function(f)
			local a, b = f.add(1), f.add(2)
			local scores = 0
			f.service.Scored:Connect(function()
				scores += 1
			end)
			f.damage.Eliminated:Fire({
				victim = b.Character,
				victimPlayer = b,
				killer = a,
				assists = {},
				headshot = true,
				doublePump = true,
			})
			expect(a:GetAttribute("Kills")).toBe(0)
			expect(b:GetAttribute("Deaths")).toBe(0)
			expect(scores).toBe(0)
		end)
	end)
end)

T.describe("Actual coordinator lobby audio", function()
	local function cues(f, player)
		local list = {}
		for _, e in f.events do
			if e.p == player and e.kind == "LobbyAudio" then
				table.insert(list, e.data.cue)
			end
		end
		return list
	end
	it("only admitted participants receive admission, with no false leave", function()
		fixture(function(f)
			local a, b, c = f.add(1), f.add(2), f.add(3)
			f.admit(a, b)
			expect(cues(f, a)).toEqual({ "QueueJoin", "Admitted" })
			expect(cues(f, b)).toEqual({ "QueueJoin", "Admitted" })
			expect(cues(f, c)).toEqual({})
		end)
	end)
	it("canceled countdown separates remaining player's cancel from leaver's exit", function()
		fixture(function(f)
			local a, b = f.add(1), f.add(2)
			f.move(a, true)
			f.move(b, true)
			f.tick(0.1)
			f.tick(1.1)
			f.move(b, false)
			f.tick(0.1)
			f.tick(0.1)
			expect(cues(f, a)).toEqual({ "QueueJoin", "QueueCountdown", "QueueCancel" })
			expect(cues(f, b)).toEqual({ "QueueJoin", "QueueCountdown", "QueueLeave" })
		end)
	end)
end)
T.describe("Actual coordinator assist audio", function()
	it("only confirmed in-match assisters receive one cue", function()
		fixture(function(f)
			local a, b, c, d = f.add(1), f.add(2), f.add(3), f.add(4)
			f.move(c, true)
			f.active(a, b)
			f.damage.Eliminated:Fire({
				victim = b.Character,
				victimPlayer = b,
				killer = a,
				assists = { c, d },
				headshot = false,
				doublePump = false,
			})
			local recipients = {}
			for _, e in f.events do
				if e.kind == "LobbyAudio" and e.data.cue == "Assist" then
					table.insert(recipients, e.p)
				end
			end
			expect(recipients).toEqual({ c })
			expect(c:GetAttribute("Assists")).toBe(1)
			expect(d:GetAttribute("Assists")).toBe(0)
		end)
	end)
end)
