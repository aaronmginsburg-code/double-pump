--!strict
-- Server authority for the two shotguns.
--
-- Clients predict their own shots for instant feedback and send what they saw:
-- slot, origin, aim, and which pellet hit which body part where. The server:
--   1. type-checks and rate-limits the request,
--   2. runs the shot through the same WeaponState rules (ownership, equipped slot,
--      swap time, per-gun cooldown, global shot interval, ammo, alive),
--   3. recomputes every pellet direction itself (deterministic pattern),
--   4. checks each claimed hit against the pellet line, the target's lag-compensated
--      position, line of sight through the map, range, team and alive state,
--   5. computes damage itself and applies it through DamageService.
-- A rejected shot gets an authoritative state snapshot back so the client resyncs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Collision = require(Shared.Collision)
local Combatants = require(Shared.Combatants)
local Damage = require(Shared.Weapons.Damage)
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)
local PositionHistory = require(Shared.Weapons.PositionHistory)
local RateLimiter = require(Shared.Util.RateLimiter)
local ShotValidation = require(Shared.Weapons.ShotValidation)
local Signal = require(Shared.Util.Signal)
local Spread = require(Shared.Weapons.Spread)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponState = require(Shared.Weapons.WeaponState)

local CharacterService = require(script.Parent.CharacterService)
local DamageService = require(script.Parent.DamageService)
local CombatContext = require(script.Parent.CombatContext)

local Actors = require(script.Parent.Participants)
local CombatService = {}
local ConsoleConfig = require(Shared.DeveloperConsole.Config)
local ConsoleRuntime = require(Shared.DeveloperConsole.Runtime)
local DeveloperAccess = require(script.Parent.DeveloperAccess)
local weaponBaseline = ConsoleConfig.copy(WeaponConfig)
CombatService.tuningRevision = 0

-- (player, slot, pelletsFired, pelletsHit, headshot)
CombatService.ShotFired = Signal.new() :: Signal.Signal<Player, number, number, number, boolean>

local rules = WeaponState.rulesFromConfig(WeaponConfig)
local timing = WeaponConfig.Timing
local V = WeaponConfig.Validation

local states: { [Player]: WeaponState.State } = {}
local histories: { [Model]: PositionHistory.History } = {}
local airborneSince: { [Player]: number } = {}
local limiter = RateLimiter.new(GameConfig.Network.WeaponActionBurst, GameConfig.Network.WeaponActionRate)

local weaponEvent: RemoteEvent
local canFireCheck: ((Player) -> boolean)? = nil
local worldRootsProvider: (() -> { Instance })? = nil

-- Debug counters (visible in the F3 overlay / tests)
CombatService.stats = { accepted = 0, rejected = 0, hitsAccepted = 0, hitsRejected = 0 }

---------------------------------------------------------------------------------------

local function snapshot(state: WeaponState.State, now: number)
	local slots = {}
	for i, slot in state.slots do
		local view = WeaponState.view(state, i, now)
		slots[i] = {
			ammo = view.ammo,
			reloading = slot.reloading,
			cooldown = view.cooldownRemaining,
		}
	end
	return {
		equipped = state.equipped,
		slots = slots,
		shotCounter = state.shotCounter,
		readyIn = math.max(0, state.readyAt - now),
		shotIn = math.max(0, state.nextShotTime - now),
	}
end

local function sendSnapshot(player: Player, reason: string?)
	local state = states[player]
	if state then
		weaponEvent:FireClient(player, "Snapshot", snapshot(state, os.clock()), reason)
	end
end

function CombatService.getState(player: Player): WeaponState.State?
	return states[player]
end

function CombatService.resetPlayer(player: Player)
	local now = os.clock()
	local state = states[player]
	if state then
		WeaponState.reset(state, now)
	else
		states[player] = WeaponState.new(rules, now)
	end
end

-- MatchService decides when shooting is allowed (e.g. not during the countdown).
function CombatService.setCanFire(fn: (Player) -> boolean)
	canFireCheck = fn
end

function CombatService.setWorldRoots(fn: () -> { Instance })
	worldRootsProvider = fn
end

---------------------------------------------------------------------------------------
-- Lag compensation

local function recordHistories()
	local t = os.clock()
	for _, model in Combatants.all() do
		local history = histories[model]
		if not history then
			history = PositionHistory.new(V.MaxRewind + 0.5)
			histories[model] = history
			model.Destroying:Once(function()
				histories[model] = nil
			end)
		end
		local parts = {}
		for _, name in Combatants.HitParts do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				parts[name] = part.CFrame
			end
		end
		history:record(t, parts)
	end
end

---------------------------------------------------------------------------------------
-- Shot validation

type ClaimedHit = { i: number, part: BasePart, pos: Vector3 }

local function parseHits(raw: any): { ClaimedHit }?
	if typeof(raw) ~= "table" or #raw > V.MaxHitsPerShot then
		return nil
	end
	local out = {}
	local seen = {}
	for _, hit in raw do
		if typeof(hit) ~= "table" then
			return nil
		end
		local i, part, pos = hit.i, hit.part, hit.pos
		if typeof(i) ~= "number" or i ~= math.floor(i) or i < 1 or i > WeaponConfig.Damage.PelletCount or seen[i] then
			return nil
		end
		if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
			continue -- part may have been destroyed in transit; ignore that pellet
		end
		if not ShotValidation.isFiniteVector(pos, 1e5) then
			return nil
		end
		seen[i] = true
		table.insert(out, { i = i, part = part, pos = pos })
	end
	return out
end

local function isAirborne(humanoid: Humanoid): boolean
	return humanoid.FloorMaterial == Enum.Material.Air
end

local function checkClaimedHit(
	shooter: Model,
	origin: Vector3,
	direction: Vector3,
	hit: ClaimedHit,
	ping: number,
	worldParams: RaycastParams
): (Model?, Damage.Zone?, number?)
	local target, humanoid = Combatants.fromPart(hit.part)
	if not target or not humanoid or humanoid.Health <= 0 or target:GetAttribute("Dead") == true then
		return nil
	end
	local shooterPlayer = Combatants.player(shooter)
	if not shooterPlayer or CombatContext.resolve(shooterPlayer, target) == "Blocked" then
		return nil
	end
	local zone: Damage.Zone? = Damage.zoneForPart(hit.part.Name)
	if not zone or hit.part.Name == "HumanoidRootPart" then
		return nil
	end

	local rayTol = V.RayTolerance
	local boxTol = ShotValidation.scaled(V.HitboxTolerance, V.HitboxTolerancePerSecondPing, V.HitboxToleranceCap, ping)
	local maxRange = WeaponConfig.Damage.MaxRange

	-- Test the claim against where the target was over the plausible latency window.
	local history = histories[target]
	local now = os.clock()
	local window = math.min(ping * 2 + 0.12, V.MaxRewind)
	local ok, along = false, 0
	local samples = 5
	for s = 0, samples do
		local t = now - window * s / samples
		local cf = if history then history:sample(hit.part.Name, t) else nil
		local partCFrame = cf or hit.part.CFrame
		local good, _, distance = ShotValidation.checkHit({
			origin = origin,
			direction = direction,
			hitPosition = hit.pos,
			partCFrame = partCFrame,
			partSize = hit.part.Size,
			maxRange = maxRange,
			rayTolerance = rayTol,
			hitboxTolerance = boxTol,
		})
		if good then
			ok, along = true, distance
			break
		end
	end
	if not ok then
		return nil
	end

	-- Nothing solid between the muzzle line and the hit point.
	local toHit = hit.pos - origin
	local length = toHit.Magnitude
	if length > 0.6 then
		local blocked = workspace:Raycast(origin, toHit.Unit * (length - 0.5), worldParams)
		if blocked then
			return nil
		end
	end
	return target, zone, along
end

local function onFire(player: Player, payload: any)
	local state = states[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not state or not character or not humanoid or not head or humanoid.Health <= 0 then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end
	if
		DeveloperAccess.environment(game.GameId, game.PlaceId)
		and payload.tuningRevision ~= CombatService.tuningRevision
	then
		sendSnapshot(player, "TuningRevision")
		return
	end
	local slot, origin, aim = payload.slot, payload.origin, payload.aim
	if typeof(slot) ~= "number" or not state.slots[slot] then
		return
	end
	if
		not ShotValidation.isFiniteVector(origin, 1e5)
		or not ShotValidation.isFiniteVector(aim, 2)
		or aim.Magnitude < 0.5
	then
		sendSnapshot(player, "BadPayload")
		return
	end
	aim = aim.Unit
	local hits = parseHits(payload.hits)
	if not hits then
		CombatService.stats.rejected += 1
		sendSnapshot(player, "BadPayload")
		return
	end
	if canFireCheck and not canFireCheck(player) then
		sendSnapshot(player, "NotAllowed")
		return
	end

	local now = os.clock()
	local ok, reason, shotNumber = WeaponState.fire(state, slot, now, timing.ServerTolerance)
	if not ok then
		CombatService.stats.rejected += 1
		sendSnapshot(player, reason)
		return
	end
	CombatService.stats.accepted += 1

	-- Firing ends spawn protection.
	CharacterService.endProtection(character)

	-- Origin must be near the server's view of the shooter's head (allowing for ping).
	local ping = math.clamp(player:GetNetworkPing(), 0, 1)
	local maxOffset =
		ShotValidation.scaled(V.MaxOriginOffset, V.MaxOriginOffsetPerSecondPing, V.MaxOriginOffsetCap, ping)
	local originValid = (origin - head.Position).Magnitude <= maxOffset

	-- Spread multiplier: crouch comes from the server's attribute. Airborne is believed
	-- unless the server saw the player on the ground for a while (airborne is wider, so
	-- claiming it is never an advantage; claiming "grounded" is checked).
	local crouching = character:GetAttribute("Crouching") == true
	local claimedAirborne = payload.air == true
	local serverAirborne = isAirborne(humanoid)
	local airborne = claimedAirborne
	if not claimedAirborne and serverAirborne then
		local since = airborneSince[player]
		if since and now - since > 0.35 + ping then
			airborne = true
		end
	end
	local multiplier = Spread.stateMultiplier(WeaponConfig.Spread, crouching, airborne)
	local directions = Spread.directions(WeaponConfig.Spread, aim, shotNumber, multiplier)

	-- Tell everyone else to show the shot.
	for _, other in Players:GetPlayers() do
		if other ~= player then
			weaponEvent:FireClient(other, "Shot", character, {
				origin = origin,
				aim = aim,
				shot = shotNumber,
				mult = multiplier,
				slot = slot,
			})
		end
	end

	if not originValid then
		CombatService.stats.hitsRejected += #hits
		CombatService.ShotFired:Fire(player, slot, #directions, 0, false)
		sendSnapshot(player, "Origin")
		return
	end

	local roots = if worldRootsProvider then worldRootsProvider() else { workspace }
	local worldParams = Collision.worldParams(roots)
	local perTarget: { [Model]: { { zone: Damage.Zone, distance: number } } } = {}
	local hitCount = 0
	for _, hit in hits do
		local target, zone, distance = checkClaimedHit(character, origin, directions[hit.i], hit, ping, worldParams)
		if target and zone and distance then
			local list = perTarget[target]
			if not list then
				list = {}
				perTarget[target] = list
			end
			table.insert(list, { zone = zone :: Damage.Zone, distance = distance })
			hitCount += 1
			CombatService.stats.hitsAccepted += 1
		else
			CombatService.stats.hitsRejected += 1
		end
	end

	local results = {}
	local anyHead = false
	for target, list in perTarget do
		local amount, headshot = Damage.total(WeaponConfig.Damage, list)
		local nearest = math.huge
		for _, h in list do
			nearest = math.min(nearest, h.distance)
		end
		local dealt, killed, doublePump = DamageService.apply(player, target, amount, {
			slot = slot,
			headshot = headshot,
			distance = nearest,
			origin = origin,
			pellets = #list,
		})
		anyHead = anyHead or headshot
		local targetHead = target:FindFirstChild("Head") :: BasePart?
		table.insert(results, {
			distance = nearest,
			falloff = Damage.falloff(WeaponConfig.Damage, nearest),
			position = if targetHead then targetHead.Position else origin + aim * nearest,
			damage = math.round(dealt),
			pellets = #list,
			headshot = headshot,
			killed = killed,
			dummy = Combatants.isDummy(target), -- presentation metadata only
			doublePump = doublePump,
			protected = dealt == 0 and not killed,
		})
	end
	if #results > 0 then
		weaponEvent:FireClient(player, "Hit", results)
	end
	CombatService.ShotFired:Fire(player, slot, #directions, hitCount, anyHead)
end

local function onWeaponAction(player: Player, action: any, arg: any)
	if not limiter:allow(player, os.clock()) then
		return
	end
	local state = states[player]
	local character = player.Character
	if not state or not character then
		return
	end
	if action == "Fire" then
		onFire(player, arg)
	elseif action == "Equip" then
		if typeof(arg) ~= "number" or not state.slots[arg] then
			return
		end
		if WeaponState.equip(state, arg, os.clock()) then
			character:SetAttribute("EquippedSlot", arg)
		end
	elseif action == "Reload" then
		if WeaponState.startReload(state, os.clock()) then
			character:SetAttribute("ReloadingAt", workspace:GetServerTimeNow())
		end
	elseif action == "CancelReload" then
		WeaponState.cancelReload(state, os.clock())
	elseif action == "Sync" then
		sendSnapshot(player, nil)
	end
end

function CombatService.start()
	weaponEvent = Net.event("WeaponEvent")
	Net.event("WeaponAction").OnServerEvent:Connect(onWeaponAction)

	CharacterService.Spawned:Connect(function(player)
		CombatService.resetPlayer(player)
		if not Actors.isBot(player) then
			weaponEvent:FireClient(player, "Reset")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		airborneSince[player] = nil
		limiter:forget(player)
	end)

	local accumulator = 0
	local interval = 1 / V.HistoryRate
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= interval then
			accumulator = 0
			recordHistories()
		end
		-- Track how long each player has been airborne (for spread checks)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and isAirborne(humanoid) then
				if not airborneSince[player] then
					airborneSince[player] = now
				end
			else
				airborneSince[player] = nil
			end
		end
	end)
end

-- Only server-registered NPC participants can enter this path. No client remote routes here.
function CombatService.npcAction(bot: any, action: string, arg: any): boolean
	if not Actors.isBot(bot) or not Actors.exists(bot) then
		return false
	end
	local character = Actors.character(bot)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if
		not character
		or not humanoid
		or not head
		or humanoid.Health <= 0
		or character:GetAttribute("Dead")
		or character:GetAttribute("Frozen")
	then
		return false
	end
	local state = states[bot]
	if not state then
		return false
	end
	local now = os.clock()
	if action == "Equip" then
		if WeaponState.equip(state, arg, now) then
			character:SetAttribute("EquippedSlot", arg)
			return true
		end
	elseif action == "Reload" then
		if WeaponState.startReload(state, now) then
			character:SetAttribute("ReloadingAt", workspace:GetServerTimeNow())
			return true
		end
	elseif action == "Fire" then
		if
			not canFireCheck
			or not canFireCheck(bot)
			or not ShotValidation.isFiniteVector(arg, 2)
			or arg.Magnitude < 0.5
		then
			return false
		end
		local ok, _, number = WeaponState.fire(state, state.equipped, now, 0)
		if not ok then
			return false
		end
		local origin = head.Position
		local aim = arg.Unit
		CharacterService.endProtection(character)
		local mult = Spread.stateMultiplier(
			WeaponConfig.Spread,
			character:GetAttribute("Crouching") == true,
			isAirborne(humanoid)
		)
		local directions = Spread.directions(WeaponConfig.Spread, aim, number, mult)
		local params = Collision.shotParams({ character })
		local perTarget = {}
		local hits = 0
		for _, direction in directions do
			local hit = workspace:Raycast(origin, direction * WeaponConfig.Damage.MaxRange, params)
			if hit then
				local target = Combatants.fromPart(hit.Instance)
				local zone = Damage.zoneForPart(hit.Instance.Name)
				if
					target
					and zone
					and hit.Instance.Name ~= "HumanoidRootPart"
					and CombatContext.resolve(bot, target) ~= "Blocked"
				then
					perTarget[target] = perTarget[target] or {}
					table.insert(perTarget[target], { zone = zone, distance = (hit.Position - origin).Magnitude })
					hits += 1
				end
			end
		end
		weaponEvent:FireAllClients(
			"Shot",
			character,
			{ origin = origin, aim = aim, shot = number, mult = mult, slot = state.equipped }
		)
		for target, list in perTarget do
			local amount, critical = Damage.total(WeaponConfig.Damage, list)
			local nearest = math.huge
			for _, hit in list do
				nearest = math.min(nearest, hit.distance)
			end
			DamageService.apply(
				bot,
				target,
				amount,
				{ slot = state.equipped, headshot = critical, distance = nearest, origin = origin, pellets = #list }
			)
		end
		CombatService.ShotFired:Fire(bot, state.equipped, #directions, hits, false)
		return true
	end
	return false
end
function CombatService.applyTuning(values: any): boolean
	if not DeveloperAccess.environment(game.GameId, game.PlaceId) then
		return false
	end
	if not ConsoleRuntime.safe(states, os.clock(), WeaponState) then
		return false
	end
	ConsoleRuntime.weapons(values, WeaponConfig, weaponBaseline)
	for _, state in states do
		ConsoleRuntime.state(state, values.capacity)
	end
	rules.magazineSize = values.capacity
	CombatService.tuningRevision += 1
	return true
end
function CombatService.forgetParticipant(bot: any)
	states[bot] = nil
	airborneSince[bot] = nil
end
return CombatService
