--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Shared = RS.Shared
local Config = require(Shared.DeveloperConsole.Config)
local Runtime = require(Shared.DeveloperConsole.Runtime)
local ProfileStore = require(Shared.DeveloperConsole.ProfileStore)
local AimConfig = require(Shared.AimAssist.Config)
local LegacyStore = require(Shared.AimAssist.ProfileStore)
local GameConfig = require(Shared.Config.GameConfig)
local Access = require(script.Parent.DeveloperAccess)
local Service = {}
local values = Config.defaults()
local revision = 0
local stateEvent: RemoteEvent
local store: any
local legacy: any
local busy: { [Player]: boolean } = {}
local last: { [Player]: number } = {}
local loaded: { [Player]: { [string]: number } } = {}
local function snapshot(): any
	local aim = {}
	for _, f in AimConfig.Fields do
		aim[f.key] = values.aiming[f.key]
	end
	return {
		schema = 1,
		values = aim,
		revision = revision,
		consoleSchema = 2,
		console = Config.copy(values),
		weaponRevision = Service.weaponRevision or 0,
		weaponValues = Config.copy(Service.weaponValues or values.weapons),
	}
end
local function fail(message: string): any
	return { ok = false, message = message, state = snapshot() }
end
local function movement()
	Runtime.movement(values.movement, GameConfig)
	local Actors = require(script.Parent.Participants)
	for _, p in Actors.all() do
		local char = Actors.character(p)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and char:GetAttribute("Frozen") ~= true then
			hum.WalkSpeed = if char:GetAttribute("Crouching")
				then GameConfig.Movement.CrouchSpeed
				else GameConfig.Movement.WalkSpeed
			hum.UseJumpPower = false
			hum.JumpHeight = GameConfig.Movement.JumpHeight
		end
	end
end
local function broadcast()
	stateEvent:FireAllClients(snapshot())
end
local function apply(clean: any)
	values = clean
	revision += 1
	movement()
	broadcast()
end
function Service.request(player: Player, action: any, payload: any): any
	if not Access.environment(game.GameId, game.PlaceId) then
		return { ok = false, message = "Development only" }
	end
	if action == "Get" then
		return { ok = true, authorized = Access.allowed(player.UserId, game.GameId, game.PlaceId), state = snapshot() }
	end
	if not Access.allowed(player.UserId, game.GameId, game.PlaceId) then
		return fail("Not authorized")
	end
	if type(action) ~= "string" or type(payload) ~= "table" or getmetatable(payload) ~= nil then
		return fail("Invalid request")
	end
	local now = os.clock()
	if now - (last[player] or -math.huge) < 0.08 then
		return fail("Please wait")
	end
	last[player] = now
	if busy[player] then
		return fail("Storage request in progress")
	end
	if action == "Apply" or action == "Reset" then
		if payload.revision ~= revision then
			return fail("Active config changed; refreshed values")
		end
		local proposed = payload.values
		if action == "Reset" then
			if not Config.scope(payload.scope) then
				return fail("Unknown scope")
			end
			proposed = Config.merge(values, Config.defaults(), payload.scope)
		end
		local clean, err = Config.validate(proposed)
		if not clean then
			return fail(err or "Invalid values")
		end
		apply(clean)
		return { ok = true, state = snapshot(), message = "Live development session updated; not saved" }
	elseif action == "Export" then
		local name = if Config.name(payload.name) then payload.name else "untitled"
		return {
			ok = true,
			state = snapshot(),
			json = Http:JSONEncode({
				schemaVersion = 2,
				game = "DoublePump",
				name = name,
				createdAt = DateTime.now():ToIsoDate(),
				environment = { universe = game.GameId, place = game.PlaceId },
				categories = values,
			}),
			message = "JSON ready; no production promotion",
		}
	elseif action == "LegacyLoad" then
		if not table.find(AimConfig.Slots, payload.slot) then
			return fail("Unknown legacy slot")
		end
		busy[player] = true
		local record, err = legacy:load("u_" .. player.UserId .. "_" .. payload.slot)
		busy[player] = nil
		if not record or not record.values then
			return fail(err or "Legacy aim slot is empty")
		end
		if player.Parent ~= Players or payload.revision ~= revision then
			return fail("Active config changed during load")
		end
		local migrated = Config.legacy(record.values)
		local merged = Config.merge(values, migrated, "aiming")
		apply(merged)
		return {
			ok = true,
			state = snapshot(),
			message = "Legacy aim profile loaded; old store unchanged. Save a new console preset explicitly.",
		}
	elseif action == "Load" or action == "Save" then
		local name, scope = payload.name, payload.scope
		if not Config.name(name) or not Config.scope(scope) then
			return fail("Preset name: 1-24 letters, numbers, underscore or hyphen; valid scope required")
		end
		if payload.revision ~= revision then
			return fail("Active config changed; retry")
		end
		local slot = scope .. ":" .. name
		local key = "u" .. player.UserId .. "_" .. scope .. "_" .. name
		loaded[player] = loaded[player] or {}
		if action == "Save" and (loaded[player][slot] == nil or payload.savedRevision ~= loaded[player][slot]) then
			return fail("Load this preset and scope before saving; existing values will not be silently overwritten")
		end
		local captured = Config.copy(values)
		busy[player] = true
		local record, err
		if action == "Load" then
			record, err = store:load(key)
		else
			record, err = store:save(key, loaded[player][slot], captured, scope, name)
		end
		busy[player] = nil
		if not record then
			return fail(err or "Storage unavailable")
		end
		if player.Parent ~= Players then
			return fail("Player left")
		end
		loaded[player][slot] = record.revision
		if action == "Load" and record.values then
			if payload.revision ~= revision then
				return fail("Active configuration changed during load; retry")
			end
			local clean, why = Config.merge(values, record.values, scope)
			if not clean then
				return fail(why or "Preset conflicts with other categories")
			end
			apply(clean)
		end
		return {
			ok = true,
			state = snapshot(),
			savedRevision = record.revision,
			savedValues = record.values,
			message = if record.revision == 0 then "Empty preset; ready for first save" else action .. " complete",
		}
	end
	return fail("Unknown action")
end
function Service.start()
	if not Access.environment(game.GameId, game.PlaceId) then
		return
	end
	Service.weaponValues = Config.copy(values.weapons)
	Service.weaponRevision = 0
	store = ProfileStore.new(DataStoreService:GetDataStore("DoublePump_DevConsole_v2", "u10772492892"))
	legacy = LegacyStore.new(DataStoreService:GetDataStore("DoublePump_DevTuning_v1", "u10772492892"))
	local folder = Instance.new("Folder")
	folder.Name = "DeveloperTuning"
	local request = Instance.new("RemoteFunction")
	request.Name = "Request"
	request.Parent = folder
	stateEvent = Instance.new("RemoteEvent")
	stateEvent.Name = "State"
	stateEvent.Parent = folder
	request.OnServerInvoke = Service.request
	folder.Parent = RS
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		last[player] = nil
		loaded[player] = nil
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		if not Config.equal({ weapons = values.weapons }, { weapons = Service.weaponValues }, "weapons") then
			local combat = require(script.Parent.CombatService)
			if combat.applyTuning(values.weapons) then
				Service.weaponValues = Config.copy(values.weapons)
				Service.weaponRevision = combat.tuningRevision
				broadcast()
			end
		end
	end)
	print("[DevTuning] five-category console ready; exact development IDs and developer allowlist")
end
return Service
