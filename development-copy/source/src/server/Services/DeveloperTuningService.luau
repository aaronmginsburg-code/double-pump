--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.AimAssist.Config)
local ProfileStore = require(ReplicatedStorage.Shared.AimAssist.ProfileStore)
local Access = require(script.Parent.DeveloperAccess)
local Service = {}
local values = Config.defaults()
local revision = 0
local stateEvent: RemoteEvent
local store: any
local busy: { [Player]: boolean } = {}
local last: { [Player]: number } = {}
local loaded: { [Player]: { [string]: number } } = {}
local function snapshot(): any
	return { values = table.clone(values), revision = revision, schema = Config.Schema }
end
local function fail(message: string): any
	return { ok = false, message = message, state = snapshot() }
end
function Service.request(player: Player, action: any, payload: any): any
	-- Every call, including Get/Export, checks actual deployment identity.
	if not Access.environment(game.GameId, game.PlaceId) then
		return { ok = false, message = "Development only" }
	end
	if action == "Get" then
		return { ok = true, authorized = Access.allowed(player.UserId, game.GameId, game.PlaceId), state = snapshot() }
	end
	if not Access.allowed(player.UserId, game.GameId, game.PlaceId) then
		return fail("Not authorized")
	end
	if type(action) ~= "string" or type(payload) ~= "table" then
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
			return fail("Active config changed; refreshed current values")
		end
		local clean, err = Config.validate(if action == "Reset" then Config.defaults() else payload.values)
		if not clean then
			return fail(err or "Invalid values")
		end
		values = clean
		revision += 1
		stateEvent:FireAllClients(snapshot())
		return { ok = true, state = snapshot(), message = "Live server config updated (not saved)" }
	elseif action == "Export" then
		return {
			ok = true,
			json = HttpService:JSONEncode({ schema = Config.Schema, module = "aimAssist", values = values }),
			state = snapshot(),
		}
	elseif action == "Load" or action == "Save" then
		local slot = payload.slot
		if type(slot) ~= "string" or not table.find(Config.Slots, slot) then
			return fail("Unknown profile slot")
		end
		local key = "u_" .. player.UserId .. "_" .. slot
		loaded[player] = loaded[player] or {}
		if action == "Save" and (loaded[player][slot] == nil or payload.savedRevision ~= loaded[player][slot]) then
			return fail("Load this slot before saving")
		end
		busy[player] = true
		local record, err
		if action == "Load" then
			record, err = store:load(key)
		else
			record, err = store:save(key, loaded[player][slot], values)
		end
		busy[player] = nil
		if not record then
			return fail(err or "Storage unavailable")
		end
		if player.Parent ~= Players then
			return fail("Player left")
		end
		loaded[player][slot] = record.revision
		-- Explicit Load replaces active config only if no concurrent live edit occurred.
		if action == "Load" and record.values then
			if payload.revision ~= revision then
				return fail("Active config changed during load; retry")
			end
			values = record.values
			revision += 1
			stateEvent:FireAllClients(snapshot())
		end
		return {
			ok = true,
			state = snapshot(),
			slot = slot,
			savedRevision = record.revision,
			savedValues = record.values,
			message = if record.revision == 0 then "Empty slot; ready for first save" else action .. " complete",
		}
	end
	return fail("Unknown action")
end
function Service.start()
	if not Access.environment(game.GameId, game.PlaceId) then
		return
	end
	store = ProfileStore.new(DataStoreService:GetDataStore("DoublePump_DevTuning_v1", "u10772492892"))
	local folder = Instance.new("Folder")
	folder.Name = "DeveloperTuning"
	local request = Instance.new("RemoteFunction")
	request.Name = "Request"
	request.Parent = folder
	stateEvent = Instance.new("RemoteEvent")
	stateEvent.Name = "State"
	stateEvent.Parent = folder
	request.OnServerInvoke = Service.request
	folder.Parent = ReplicatedStorage
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		last[player] = nil
		loaded[player] = nil
	end)
	print("[DevTuning] private aim-assist service ready; explicit developer allowlist")
end
return Service
