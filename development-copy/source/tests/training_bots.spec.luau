--!nocheck
local T = require("./runner/T")
local L = require("./runner/Loader")
local expect, it = T.expect, T.it
local function fixture(fn)
	local old = table.clone(L.services)
	L.reset()
	local ok, err = xpcall(function()
		local Signal = L.require(L.Shared.Util.Signal)
		local players = {}
		local owners = {}
		local ps = {
			PlayerRemoving = Signal.new(),
			GetPlayers = function()
				return table.clone(players)
			end,
			GetPlayerFromCharacter = function(_, m)
				return owners[m]
			end,
		}
		L.services.Players = ps
		L.services.ReplicatedStorage = { Shared = L.Shared }
		L.services.CollectionService = {}
		L.services.GameId = 10772492892
		L.services.PlaceId = 139437092998076
		L.services.Workspace = {
			GetServerTimeNow = function()
				return 1000
			end,
		}
		local function model(name)
			local attrs = {}
			local h = { Health = 100 }
			return {
				Name = name,
				SetAttribute = function(_, k, v)
					attrs[k] = v
				end,
				GetAttribute = function(_, k)
					return attrs[k]
				end,
				FindFirstChildOfClass = function()
					return h
				end,
			},
				h
		end
		local function human(id)
			local c, h = model("Human" .. id)
			local p = {
				UserId = id,
				Name = "Human" .. id,
				DisplayName = "Human" .. id,
				Character = c,
				Parent = ps,
				Team = {
					Name = "Red",
				},
			}
			owners[c] = p
			table.insert(players, p)
			return p, h
		end
		local owner, health = human(11808586604)
		local other, otherHealth = human(4)
		local A = L.require(L.Server.Services.Participants)
		local bots = { A.register(owner, 1), A.register(owner, 2) }
		local hp = {}
		for i, b in bots do
			local m, h = model(b.name)
			A.bind(b, m)
			hp[i] = h
		end
		local Context = L.require(L.Server.Services.CombatContext)
		local events = {}
		L.inject(L.Shared.Net, {
			event = function()
				return {
					FireClient = function(_, p, ...)
						assert(not A.isBot(p))
						table.insert(events, { ... })
					end,
					FireAllClients = function(_, ...)
						table.insert(events, { ... })
					end,
				}
			end,
		})
		L.inject(L.Server.Services.CharacterService, {
			isProtected = function()
				return false
			end,
			endProtection = function() end,
			Died = Signal.new(),
		})
		local Damage = L.require(L.Server.Services.DamageService)
		Damage.start()
		for _, p in { owner, other, bots[1], bots[2] } do
			Context.set(p, "Lobby")
		end
		local info = { slot = 1, headshot = false, distance = 8, origin = L.roblox.Vector3.zero, pellets = 8 }
		fn({
			A = A,
			C = Context,
			D = Damage,
			owner = owner,
			other = other,
			health = health,
			otherHealth = otherHealth,
			bots = bots,
			hp = hp,
			info = info,
			events = events,
		})
	end, debug.traceback)
	table.clear(L.services)
	for k, v in old do
		L.services[k] = v
	end
	L.reset()
	assert(ok, err)
end
T.describe("Private server NPC integration", function()
	it("creates exactly two distinct registered NPC records without fake Player interfaces", function()
		fixture(function(f)
			expect(#f.A.list()).toBe(2)
			expect(#f.A.all()).toBe(4)
			for _, b in f.bots do
				expect(b.Character).toBe(nil)
				expect(b.UserId).toBe(nil)
				expect(b.FireServer).toBe(nil)
				expect(f.A.isBot(b)).toBe(true)
			end
		end)
	end)
	it("rejects duplicate and third NPC registration", function()
		fixture(function(f)
			expect(pcall(f.A.register, f.owner, 1)).toBe(false)
			expect(pcall(f.A.register, f.owner, 3)).toBe(false)
		end)
	end)
	it("rejects ordinary players even inside development", function()
		fixture(function(f)
			expect(pcall(f.A.register, f.other, 1)).toBe(false)
		end)
	end)
	it("fails closed in production", function()
		fixture(function(f)
			L.services.GameId = 10772275012
			L.services.PlaceId = 82505574993280
			expect(pcall(f.A.register, f.owner, 1)).toBe(false)
		end)
	end)
	it("binds actual models without using client identity hints", function()
		fixture(function(f)
			f.other.Character:SetAttribute("TrainingBot", true)
			expect(f.A.fromModel(f.other.Character)).toBe(f.other)
			expect(f.A.isBot(f.other)).toBe(false)
		end)
	end)
	it("starts passive: neither bot may damage its owner", function()
		fixture(function(f)
			for _, b in f.bots do
				expect(f.C.resolve(b, f.owner.Character)).toBe("Blocked")
				expect(f.D.apply(b, f.owner.Character, 90, f.info)).toBe(0)
			end
			expect(f.health.Health).toBe(100)
		end)
	end)
	it("range reset removes target, pursuit and pending fire decisions without changing inventory", function()
		local policy = L.require(L.Shared.Training.Policy)
		local gun = { ammo = 3 }
		local bot = {
			target = {},
			lastSeen = L.roblox.Vector3.one,
			swapAt = 99,
			moveGoal = L.roblox.Vector3.one,
			patrolGoal = L.roblox.Vector3.one,
			alertUntil = 99,
			reactAt = 99,
			seesTarget = true,
			returning = true,
			gun = gun,
		}
		policy.resetRangeCombat(bot)
		for _, key in
			{ "target", "lastSeen", "swapAt", "moveGoal", "patrolGoal", "alertUntil", "reactAt", "seesTarget" }
		do
			expect(bot[key]).toBe(nil)
		end
		expect(bot.returning).toBe(false)
		expect(bot.gun).toBe(gun)
		expect(gun.ammo).toBe(3)
	end)
	it("a reset range duel stays nonhostile after respawn until another legitimate hit", function()
		fixture(function(f)
			f.D.apply(f.owner, f.bots[1].model, 9, f.info)
			f.D.apply(f.bots[1], f.owner.Character, 100, f.info)
			f.C.stopTraining(f.owner)
			f.health.Health = 100 -- isolated respawn stand-in; Studio verifies the real death callback
			for _, bot in f.bots do
				expect(f.C.resolve(bot, f.owner.Character)).toBe("Blocked")
				expect(f.D.apply(bot, f.owner.Character, 20, f.info)).toBe(0)
			end
			f.D.apply(f.owner, f.bots[2].model, 9, f.info)
			for _, bot in f.bots do
				expect(f.C.resolve(bot, f.owner.Character)).toBe("Training")
			end
		end)
	end)
	it("one real owner hit enables retaliation for both bots", function()
		fixture(function(f)
			expect(f.D.apply(f.owner, f.bots[1].model, 9, f.info)).toBe(9)
			expect(f.hp[1].Health).toBe(91)
			for _, b in f.bots do
				expect(f.C.resolve(b, f.owner.Character)).toBe("Training")
			end
		end)
	end)
	it("isolates lethal training from uninvolved players and other bots", function()
		fixture(function(f)
			f.D.apply(f.owner, f.bots[1].model, 9, f.info)
			expect(f.D.apply(f.bots[1], f.other.Character, 200, f.info)).toBe(0)
			expect(f.D.apply(f.other, f.bots[1].model, 200, f.info)).toBe(0)
			expect(f.D.apply(f.bots[1], f.bots[2].model, 200, f.info)).toBe(0)
			expect(f.otherHealth.Health).toBe(100)
			expect(f.hp[2].Health).toBe(100)
		end)
	end)
	it("keeps human versus human lobby feedback nonlethal", function()
		fixture(function(f)
			expect(f.D.apply(f.owner, f.other.Character, 157.5, f.info)).toBe(157.5)
			expect(f.otherHealth.Health).toBe(100)
			expect(#f.events).toBe(0)
		end)
	end)
	it("allows normal training damage/elimination and BOT attribution", function()
		fixture(function(f)
			f.D.apply(f.owner, f.bots[1].model, 9, f.info)
			local elimination
			f.D.Eliminated:Connect(function(e)
				elimination = e
			end)
			f.D.apply(f.bots[2], f.owner.Character, 100, f.info)
			expect(f.health.Health).toBe(0)
			expect(elimination.killer).toBe(f.bots[2])
			expect(elimination.victimPlayer).toBe(f.owner)
		end)
	end)
	it("stopping training immediately blocks returning bot fire", function()
		fixture(function(f)
			f.D.apply(f.owner, f.bots[1].model, 9, f.info)
			f.C.stopTraining(f.owner)
			expect(f.D.apply(f.bots[1], f.owner.Character, 90, f.info)).toBe(0)
			expect(f.health.Health).toBe(100)
		end)
	end)
	it("rejects cross-context and wrong-match NPC shots", function()
		fixture(function(f)
			f.C.set(f.bots[1], "Match", 1)
			f.C.activate(1)
			f.bots[1].team = "Blue"
			expect(f.C.resolve(f.bots[1], f.owner.Character)).toBe("Blocked")
			f.C.set(f.owner, "Match", 2)
			expect(f.C.resolve(f.bots[1], f.owner.Character)).toBe("Blocked")
			f.C.set(f.owner, "Match", 1)
			expect(f.C.resolve(f.bots[1], f.owner.Character)).toBe("Match")
			f.bots[1].team = "Red"
			expect(f.C.resolve(f.bots[1], f.owner.Character)).toBe("Blocked")
		end)
	end)
	it("forgets bot model registration on removal", function()
		fixture(function(f)
			local b = f.bots[1]
			local m = b.model
			f.A.remove(b)
			expect(#f.A.list()).toBe(1)
			expect(f.A.fromModel(m)).toBe(nil)
		end)
	end)
end)
local P = L.require(L.Shared.Training.Policy)
local Q = L.require(L.Shared.Match.LobbyQueue)
local owner, b1, b2 = "owner", "b1", "b2"
local bots = { b1, b2 }
T.describe("Physical FIFO training admission", function()
	it("never admits bots without their developer", function()
		expect(#P.selection({ b1, b2 }, owner, bots, 10)).toBe(0)
	end)
	it("rejects an incomplete pair even with two participants", function()
		expect(#P.selection({ owner, b1 }, owner, bots, 10)).toBe(0)
	end)
	it("admits all three only after ordinary queue countdown", function()
		local q = Q.new({ Minimum = 2, Capacity = 10, Countdown = 15 })
		local a = Q.step(q, { owner, b1, b2 }, 0, true)
		expect(#a).toBe(0)
		a = Q.step(q, { owner, b1, b2 }, 14.9, true)
		expect(#a).toBe(0)
		a = Q.step(q, { owner, b1, b2 }, 15, true)
		expect(#P.selection(a, owner, bots, 10)).toBe(3)
	end)
	it("cancels when physical occupancy removes the developer and pair", function()
		local q = Q.new({ Minimum = 2, Capacity = 10, Countdown = 15 })
		Q.step(q, { owner, b1, b2 }, 0, true)
		local a = Q.step(q, {}, 14.99, true)
		expect(#a).toBe(0)
		expect(q.deadline).toBe(nil)
	end)
	it("respects full queue capacity and FIFO instead of injecting the pair", function()
		local order = { "h1", "h2", "h3", "h4", "h5", "h6", "h7", "h8", owner, b1, b2 }
		local a = P.selection(order, owner, bots, 10)
		expect(#a).toBe(8)
		expect(a[1]).toBe("h1")
		expect(a[8]).toBe("h8")
	end)
	it("preserves human-only FIFO prefix when bots are not selected", function()
		local a = P.selection({ "a", "b", owner, b1, b2 }, owner, bots, 2)
		expect(#a).toBe(2)
		expect(a[2]).toBe("b")
	end)
	it("does not start overlapping matches", function()
		local q = Q.new({ Minimum = 2, Capacity = 10, Countdown = 15 })
		local a, state = Q.step(q, { owner, b1, b2 }, 30, false)
		expect(#a).toBe(0)
		expect(state).toBe("Pending")
		expect(q.deadline).toBe(nil)
	end)
	it("keeps deterministic 1v2 teams opposite the owner", function()
		local teams = P.teams({ owner, b1, b2 }, owner, bots, 5)
		expect(teams[owner]).toBe("Red")
		expect(teams[b1]).toBe("Blue")
		expect(teams[b2]).toBe("Blue")
	end)
	it("fills additional humans deterministically without exceeding five per team", function()
		local roster = { owner, b1, b2, "a", "b", "c", "d", "e", "f", "g" }
		local teams = P.teams(roster, owner, bots, 5)
		local r, b = 0, 0
		for _, team in teams do
			if team == "Red" then
				r += 1
			else
				b += 1
			end
		end
		expect(r).toBe(5)
		expect(b).toBe(5)
		expect(P.teams({ owner, b1, b2, "a", "b", "c", "d", "e", "f", "g", "h" }, owner, bots, 5)).toBe(nil)
	end)
	it("requires alive visible enemies inside perception range", function()
		expect(P.canPerceive(30, true, true, true, 110)).toBe(true)
		expect(P.canPerceive(30, false, true, true, 110)).toBe(false)
		expect(P.canPerceive(30, true, false, true, 110)).toBe(false)
		expect(P.canPerceive(30, true, true, false, 110)).toBe(false)
		expect(P.canPerceive(111, true, true, true, 110)).toBe(false)
	end)
	it("prioritizes queue following and match preparation over lobby hostility", function()
		expect(P.state("Practice", true, false, true, true, false)).toBe("QueueFollowing")
		expect(P.state("Practice", true, true, true, true, false)).toBe("Queued")
		expect(P.state("Match", true, false, false, true, false)).toBe("MatchPreparation")
		expect(P.state("Match", true, false, false, true, true)).toBe("MatchCombat")
		expect(P.state("Practice", false, false, false, true, false)).toBe("Eliminated")
	end)
end)

it("training results never touch persistent profiles or reward notifications", function()
	local old = table.clone(L.services)
	L.reset()
	local ok, err = xpcall(function()
		local Signal = L.require(L.Shared.Util.Signal)
		local ended = Signal.new()
		local touched = 0
		local pushed = 0
		L.services.Players = { PlayerRemoving = Signal.new() }
		L.services.RunService = { Heartbeat = Signal.new() }
		L.services.ReplicatedStorage = { Shared = L.Shared }
		L.inject(L.Server.Services.DataService, {
			Loaded = Signal.new(),
			get = function()
				touched += 1
				error("No profile access allowed")
			end,
			update = function()
				touched += 1
				error("No profile writes allowed")
			end,
		})
		L.inject(L.Server.Services.MatchService, { MatchStarted = Signal.new(), MatchEnded = ended })
		L.inject(L.Server.Services.CombatService, { ShotFired = Signal.new() })
		L.inject(L.Server.Services.TeamService, {})
		L.inject(L.Shared.Net, {
			event = function()
				return {
					FireClient = function()
						pushed += 1
					end,
					OnServerEvent = Signal.new(),
				}
			end,
			func = function()
				return {}
			end,
		})
		local progression = L.require(L.Server.Services.ProgressionService)
		progression.start()
		ended:Fire({
			training = true,
			participants = { owner = { stats = { kills = 999 }, timePlayed = 300 } },
			winner = "Red",
		})
		expect(touched).toBe(0)
		expect(pushed).toBe(0)
	end, debug.traceback)
	table.clear(L.services)
	for k, v in old do
		L.services[k] = v
	end
	L.reset()
	assert(ok, err)
end)

it("ground-level path waypoints accept elevated roots but not another storey", function()
	local V = L.roblox.Vector3
	expect(P.reached(V.new(0, 3.1, 0), 2)).toBe(true)
	expect(P.reached(V.new(3, 3.1, 0), 2)).toBe(false)
	expect(P.reached(V.new(0, 9, 0), 2)).toBe(false)
end)
