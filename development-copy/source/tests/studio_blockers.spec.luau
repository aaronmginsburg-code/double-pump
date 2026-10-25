--!nocheck
-- Exercise the real lifecycle coordinators with engine/service boundaries mocked.
local T = require("./runner/T")
local Loader = require("./runner/Loader")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local R = Loader.roblox

local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			table.insert(listeners, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in listeners do
				fn(...)
			end
		end,
		Once = function() end,
	}
end

local function isolated(fn)
	local services, tasks = table.clone(Loader.services), Loader.task
	Loader.reset()
	Loader.inject(Loader.Shared.Collision, { ROOT = "RootParts" })
	local ok, err = xpcall(fn, debug.traceback)
	table.clear(Loader.services)
	for name, service in services do
		Loader.services[name] = service
	end
	Loader.task = tasks
	Loader.reset()
	assert(ok, err)
end

T.describe("Studio blocker regressions", function()
	T.it("combat and facing wait for server spawn data across menus, respawns and modes", function()
		isolated(function()
			local client = Loader.game.StarterPlayer.StarterPlayerScripts.Client
			local controllers, ui = client.Controllers, client.UI
			local mode, state, team = "Match", "Active", "Red"
			local humanoid = { Health = 100 }
			local spawnCFrame = nil
			Loader.services.Players = {
				LocalPlayer = {
					Character = {
						GetAttribute = function()
							return spawnCFrame
						end,
						FindFirstChildOfClass = function()
							return humanoid
						end,
						FindFirstChild = function()
							return nil
						end,
					},
				},
			}
			Loader.services.Workspace = {
				FindFirstChild = function()
					return nil
				end,
			}
			local noop = function() end
			local facing, facingChanges = nil, 0
			local camera = {
				mode = "Combat",
				setDead = noop,
				setScenic = noop,
				requestCursor = function()
					return noop
				end,
				lookAlong = function(cf)
					facing = cf
					facingChanges += 1
				end,
			}
			local input = { releaseAll = noop }
			local weapon = { active = false }
			local menu = { isOpen = false, open = noop }
			Loader.inject(controllers.CameraController, camera)
			Loader.inject(controllers.InputController, input)
			Loader.inject(controllers.WeaponController, weapon)
			Loader.inject(controllers.MatchClient, {
				mode = function()
					return mode
				end,
				state = function()
					return state
				end,
				myTeam = function()
					return team
				end,
			})
			Loader.inject(controllers.ViewmodelController, { setEnabled = noop })
			Loader.inject(controllers.AudioController, { setMusic = noop, setAmbience = noop })
			Loader.inject(controllers.MovementController, { setCrouch = noop })
			Loader.inject(ui.MainMenu, menu)
			Loader.inject(ui.Hud, { setVisible = noop })
			Loader.inject(ui.DeathScreen, { hide = noop })
			Loader.inject(ui.Scoreboard, {})
			Loader.inject(ui.Postgame, {})
			Loader.inject(ui.MobileControls, { setActive = noop })
			local flow = Loader.require(controllers.GameFlow)
			local function check(expected)
				flow.refresh()
				T.expect(input.combatEnabled).toBe(expected)
				T.expect(weapon.active).toBe(expected)
			end
			check(false) -- CharacterAdded can arrive before final server placement.
			spawnCFrame = R.CFrame.lookAt(R.Vector3.new(-65, 3.5, -36), R.Vector3.new(0, 3.5, -36))
			check(true)
			T.expect(facing).toBe(spawnCFrame)
			menu.isOpen = true
			check(false)
			menu.isOpen = false
			check(true)
			T.expect(facingChanges).toBe(1) -- Resuming must preserve the player's aim.
			humanoid.Health = 0
			check(false)
			humanoid.Health = 100
			Loader.services.Players.LocalPlayer.Character = table.clone(Loader.services.Players.LocalPlayer.Character)
			spawnCFrame = R.CFrame.lookAt(R.Vector3.new(65, 3.5, 36), R.Vector3.new(0, 3.5, 36))
			check(true)
			T.expect(facing).toBe(spawnCFrame)
			T.expect(facingChanges).toBe(2)
			state = "Results"
			check(false)
			state, mode, team = "Waiting", "Practice", nil
			check(true)
			mode, menu.isOpen = "Menu", true
			check(false)
		end)
	end)

	T.it("spawn placement and notification follow engine placement on every spawn", function()
		isolated(function()
			Loader.task = { defer = function() end }
			Loader.services.Workspace = {
				GetServerTimeNow = function()
					return 50
				end,
			}
			Loader.services.CollectionService = { AddTag = function() end }
			local player = { Name = "Player1", Parent = true, Team = { Name = "Red" }, CharacterAdded = signal() }
			Loader.services.Players = {
				PlayerAdded = signal(),
				PlayerRemoving = signal(),
				GetPlayers = function()
					return { player }
				end,
			}
			Loader.inject(Loader.Shared.Net, {
				event = function()
					return { OnServerEvent = signal() }
				end,
			})
			Loader.inject(Loader.Shared.Weapons.ShotgunModel, {})
			Loader.inject(Loader.Shared.Util.Signal, { new = signal })
			local finished, pivotAt, notifications = false, nil, 0
			local latestHumanoid
			local loadCount = 0
			function player:LoadCharacterAsync()
				loadCount += 1
				if latestHumanoid then
					latestHumanoid.Health = 0
					latestHumanoid.Died:Fire() -- engine retires the previous living character
				end
				finished = false
				local attributes = { Dead = true, Frozen = true, Crouching = true }
				local humanoid = { SetStateEnabled = function() end, Died = signal() }
				latestHumanoid = humanoid
				local root = {}
				local character = {
					FindFirstChild = function(_, name)
						return if name == "HumanoidRootPart" then root else nil
					end,
					FindFirstChildOfClass = function()
						return humanoid
					end,
					WaitForChild = function(_, name)
						return if name == "Humanoid" then humanoid else {}
					end,
					GetDescendants = function()
						T.expect(humanoid.RequiresNeck).toBe(false)
						return {}
					end,
					DescendantAdded = signal(),
					SetAttribute = function(_, name, value)
						attributes[name] = value
					end,
					GetAttribute = function(_, name)
						return attributes[name]
					end,
					PivotTo = function(_, cf)
						pivotAt = cf
					end,
				}
				self.Character = character
				self.CharacterAdded:Fire(character)
				-- Roblox's final spawn positioning happens after CharacterAdded.
				pivotAt = R.CFrame.new(0, 30, 0)
				finished = true
			end
			local service = Loader.require(Loader.Server.Services.CharacterService)
			service.start()
			local deaths = 0
			service.Died:Connect(function()
				deaths += 1
			end)
			service.Spawned:Connect(function(_, character)
				T.expect(finished).toBe(true)
				T.expect(character).toBe(player.Character)
				T.expect(character:GetAttribute("SpawnCFrame")).toBe(pivotAt)
				T.expect(character:GetAttribute("Dead")).toBe(false)
				T.expect(character:GetAttribute("Frozen")).toBe(false)
				T.expect(character:GetAttribute("Crouching")).toBe(false)
				notifications += 1
			end)
			for _, spawn in { R.CFrame.new(-60, 4, 20), R.CFrame.new(60, 4, -20) } do
				service.spawn(player, spawn)
				T.expect(pivotAt).toBe(spawn + R.Vector3.new(0, 3, 0))
			end
			T.expect(notifications).toBe(2)
			T.expect(deaths).toBe(0) -- forced transfers never schedule another respawn
			local living = player.Character
			latestHumanoid.Health = 20
			living:SetAttribute("Frozen", true)
			living:SetAttribute("Crouching", true)
			service.transfer(player, R.CFrame.new(-1254, 0.5, 0))
			T.expect(player.Character).toBe(living)
			T.expect(loadCount).toBe(2) -- healthy transfers never reload/kill the avatar
			T.expect(latestHumanoid.Health).toBe(100)
			T.expect(living:GetAttribute("SpawnRevision")).toBe(2)
			T.expect(living:GetAttribute("Frozen")).toBe(false)
			T.expect(living:GetAttribute("Crouching")).toBe(false)
			T.expect(pivotAt).toBe(R.CFrame.new(-1254, 3.5, 0))
			-- A queued engine Died event after health restoration must neither mark
			-- the living spawn dead nor consume its later real death listener.
			latestHumanoid.Died:Fire()
			T.expect(player.Character:GetAttribute("Dead")).toBe(false)
			latestHumanoid.Health = 0
			latestHumanoid.Died:Fire()
			T.expect(player.Character:GetAttribute("Dead")).toBe(true)
			T.expect(deaths).toBe(1)
			latestHumanoid.Died:Fire()
			T.expect(deaths).toBe(1)
		end)
	end)

	T.it("range startup works when scripts cannot set the world destroy height", function()
		isolated(function()
			Loader.services.Workspace = setmetatable({}, {
				__newindex = function(_, key)
					assert(key ~= "FallenPartsDestroyHeight", "protected Workspace property")
				end,
			})
			-- Use a model stand-in so the Workspace proxy can reject protected writes.
			local built = false
			local maps = Loader.Server.Maps
			for _, name in { "Range", "Warehouse", "DustTown", "Rooftops" } do
				Loader.inject(maps[name], {
					id = name,
					build = function()
						built = true
						return {
							GetDescendants = function()
								return {}
							end,
						}
					end,
				})
			end
			Loader.services.CollectionService = {}
			local lighting = R.Instance.new("Folder")
			Loader.services.Lighting = setmetatable({}, {
				__index = function(_, key)
					if key == "FindFirstChild" then
						return function(_, name)
							local effect = lighting:FindFirstChild(name)
							if not effect then
								local classes = {
									MapAtmosphere = "Atmosphere",
									MapGrade = "ColorCorrectionEffect",
									MapBloom = "BloomEffect",
									MapSunRays = "SunRaysEffect",
								}
								effect = R.Instance.new(classes[name])
								effect.Name, effect.Parent = name, lighting
							end
							return effect
						end
					end
				end,
			})
			local service = Loader.require(Loader.Server.Services.MapService)
			service.start()
			T.expect(built).toBe(true)
			T.expect(#service.ArenaIds).toBe(3)
			local project = serde.decode("json", fs.readFile("default.project.json"))
			T.expect(project.tree.Workspace["$properties"].FallenPartsDestroyHeight).toBe(-120)
		end)
	end)
end)
