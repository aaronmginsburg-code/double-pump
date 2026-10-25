--!nocheck
local T = require("./runner/T")
local Loader = require("./runner/Loader")
local expect, it = T.expect, T.it

local function isolated(fn)
	local services, tasks = table.clone(Loader.services), Loader.task
	Loader.reset()
	local ok, err = xpcall(fn, debug.traceback)
	table.clear(Loader.services)
	for k, v in services do
		Loader.services[k] = v
	end
	Loader.task = tasks
	Loader.reset()
	assert(ok, err)
end

local function fixture(fn)
	isolated(function()
		local owners, events = {}, {}
		Loader.services.Players = {
			PlayerRemoving = { Connect = function() end },
			GetPlayerFromCharacter = function(_, model)
				return owners[model]
			end,
		}
		Loader.services.CollectionService = {}
		local function character()
			local attrs = {}
			local hum = { Health = 100 }
			return {
				GetAttribute = function(_, k)
					return attrs[k]
				end,
				SetAttribute = function(_, k, v)
					attrs[k] = v
				end,
				FindFirstChildOfClass = function()
					return hum
				end,
				Name = "TestCharacter",
			},
				hum
		end
		local function player(name)
			local c, h = character()
			local p = { Name = name, DisplayName = name, UserId = 1, Parent = true, Character = c }
			owners[c] = p
			return p, h
		end
		local a, ah = player("Shooter")
		local b, bh = player("Target")
		local protected = false
		Loader.inject(Loader.Shared.Net, {
			event = function()
				return {
					FireClient = function(_, ...)
						table.insert(events, { ... })
					end,
					FireAllClients = function(_, ...)
						table.insert(events, { ... })
					end,
				}
			end,
		})
		Loader.inject(Loader.Server.Services.CharacterService, {
			isProtected = function()
				return protected
			end,
			Died = { Connect = function() end },
		})
		local context = Loader.require(Loader.Server.Services.CombatContext)
		local damage = Loader.require(Loader.Server.Services.DamageService)
		damage.start()
		local counts = { damaged = 0, eliminated = 0 }
		damage.Damaged:Connect(function()
			counts.damaged += 1
		end)
		damage.Eliminated:Connect(function()
			counts.eliminated += 1
		end)
		local info = { slot = 1, headshot = false, distance = 5, origin = Loader.roblox.Vector3.zero, pellets = 8 }
		fn({
			a = a,
			b = b,
			ah = ah,
			bh = bh,
			context = context,
			damage = damage,
			events = events,
			counts = counts,
			info = info,
			character = character,
			protected = function(v)
				protected = v
			end,
		})
	end)
end

T.describe("Server-owned lobby combat", function()
	it("unknown participants cannot cause damage", function()
		fixture(function(f)
			expect(f.context.resolve(f.a, f.b.Character)).toBe("Blocked")
			expect(f.damage.apply(f.a, f.b.Character, 90, f.info)).toBe(0)
			expect(f.bh.Health).toBe(100)
		end)
	end)
	it("lobby blasts report full hypothetical damage with no health mutation or damage events", function()
		fixture(function(f)
			f.context.set(f.a, "Lobby")
			f.context.set(f.b, "Lobby")
			local amount, killed, double = f.damage.apply(f.a, f.b.Character, 72, f.info)
			expect(amount).toBe(72)
			expect(killed).toBe(false)
			expect(double).toBe(false)
			expect(f.bh.Health).toBe(100)
			expect(f.counts.damaged).toBe(0)
			expect(f.counts.eliminated).toBe(0)
			expect(#f.events).toBe(0)
		end)
	end)
	it("would-be lethal headshots never kill or cap hypothetical damage at current health", function()
		fixture(function(f)
			f.context.set(f.a, "Lobby")
			f.context.set(f.b, "Lobby")
			f.info.headshot = true
			f.bh.Health = 35
			local damage = Loader.require(Loader.Shared.Weapons.Damage)
			local config = Loader.require(Loader.Shared.Config.WeaponConfig).Damage
			local pellets = {}
			for i = 1, 10 do
				table.insert(pellets, { zone = "Head", distance = 5 })
			end
			local amount, head = damage.total(config, pellets)
			expect(amount).toBeNear(157.5)
			expect(head).toBe(true)
			for _ = 1, 20 do
				expect(f.damage.apply(f.a, f.b.Character, amount, f.info)).toBeNear(amount)
			end
			expect(f.bh.Health).toBe(35)
			expect(f.counts.eliminated).toBe(0)
			expect(f.counts.damaged).toBe(0)
		end)
	end)
	it("feedback uses shared partial-pellet zone multipliers and falloff", function()
		fixture(function(f)
			f.context.set(f.a, "Lobby")
			f.context.set(f.b, "Lobby")
			local damage = Loader.require(Loader.Shared.Weapons.Damage)
			local config = Loader.require(Loader.Shared.Config.WeaponConfig).Damage
			local pellets = {
				{ zone = "Head", distance = 5 },
				{ zone = "Torso", distance = 20 },
				{ zone = "Arm", distance = 40 },
				{
					zone = "Leg",
					distance = 5,
				},
			}
			local total, head = damage.total(config, pellets)
			expect(head).toBe(true)
			expect(f.damage.apply(f.a, f.b.Character, total, f.info)).toBeNear(total)
			expect(f.bh.Health).toBe(100)
		end)
	end)
	it("spawn protection does not hide nonlethal practice hit feedback", function()
		fixture(function(f)
			f.context.set(f.a, "Lobby")
			f.context.set(f.b, "Lobby")
			f.protected(true)
			expect(f.damage.apply(f.a, f.b.Character, 72, f.info)).toBe(72)
		end)
	end)
	it("lobby and match participants cannot hit each other in either direction", function()
		fixture(function(f)
			f.context.set(f.a, "Lobby")
			f.context.set(f.b, "Match", 1)
			f.context.activate(1)
			expect(f.context.resolve(f.a, f.b.Character)).toBe("Blocked")
			expect(f.context.resolve(f.b, f.a.Character)).toBe("Blocked")
			expect(f.damage.apply(f.a, f.b.Character, 100, f.info)).toBe(0)
		end)
	end)
	it("reserved voters cannot fire damaging or practice hits", function()
		fixture(function(f)
			f.context.set(f.a, "Reserved")
			f.context.set(f.b, "Lobby")
			expect(f.context.resolve(f.a, f.b.Character)).toBe("Blocked")
			expect(f.context.resolve(f.b, f.a.Character)).toBe("Blocked")
		end)
	end)
	it("same active match enables normal health damage and events", function()
		fixture(function(f)
			f.a.Team = { Name = "Red" }
			f.b.Team = { Name = "Blue" }
			f.context.set(f.a, "Match", 1)
			f.context.set(f.b, "Match", 1)
			f.context.activate(1)
			expect(f.context.resolve(f.a, f.b.Character)).toBe("Match")
			expect(f.damage.apply(f.a, f.b.Character, 72, f.info)).toBe(72)
			expect(f.bh.Health).toBe(28)
			expect(f.counts.damaged).toBe(1)
			local _, killed = f.damage.apply(f.a, f.b.Character, 72, f.info)
			expect(killed).toBe(true)
			expect(f.bh.Health).toBe(0)
			expect(f.counts.eliminated).toBe(1)
		end)
	end)
	it("match spawn protection remains effective", function()
		fixture(function(f)
			f.a.Team = { Name = "Red" }
			f.b.Team = { Name = "Blue" }
			f.context.set(f.a, "Match", 1)
			f.context.set(f.b, "Match", 1)
			f.context.activate(1)
			f.protected(true)
			expect(f.damage.apply(f.a, f.b.Character, 72, f.info)).toBe(0)
			expect(f.bh.Health).toBe(100)
		end)
	end)
	it("friendly fire, old match ids and inactive matches remain blocked", function()
		fixture(function(f)
			local team = { Name = "Red" }
			f.a.Team = team
			f.b.Team = team
			f.context.set(f.a, "Match", 1)
			f.context.set(f.b, "Match", 1)
			f.context.activate(1)
			expect(f.context.resolve(f.a, f.b.Character)).toBe("Blocked")
			f.b.Team = { Name = "Blue" }
			f.context.set(f.b, "Match", 2)
			expect(f.context.resolve(f.a, f.b.Character)).toBe("Blocked")
			f.context.set(f.b, "Match", 1)
			f.context.activate(nil)
			expect(f.context.resolve(f.a, f.b.Character)).toBe("Blocked")
		end)
	end)
	it("replicated attribute spoofing cannot override server membership", function()
		fixture(function(f)
			f.context.set(f.a, "Match", 1)
			f.context.set(f.b, "Lobby")
			f.a.Character:SetAttribute("CombatContext", "Lobby")
			expect(f.context.resolve(f.a, f.b.Character)).toBe("Blocked")
		end)
	end)
	it("respawn refresh republishes membership on the new character", function()
		fixture(function(f)
			f.context.set(f.a, "Lobby")
			f.a.Character = f.character()
			f.context.refresh(f.a)
			expect(f.a.Character:GetAttribute("CombatContext")).toBe("Lobby")
		end)
	end)
	it("disconnect removes eligibility", function()
		fixture(function(f)
			f.context.set(f.a, "Lobby")
			f.context.set(f.b, "Lobby")
			f.context.forget(f.b)
			expect(f.context.resolve(f.a, f.b.Character)).toBe("Blocked")
		end)
	end)
	it("practice targets remain shootable only from the range", function()
		fixture(function(f)
			local dummy = f.character()
			dummy:SetAttribute("Dummy", true)
			f.context.set(f.a, "Lobby")
			expect(f.context.resolve(f.a, dummy)).toBe("Dummy")
			expect(f.damage.apply(f.a, dummy, 72, f.info)).toBe(72)
			expect(dummy:FindFirstChildOfClass("Humanoid").Health).toBe(28)
			f.context.set(f.a, "Match", 1)
			f.context.activate(1)
			expect(f.context.resolve(f.a, dummy)).toBe("Blocked")
		end)
	end)
end)
