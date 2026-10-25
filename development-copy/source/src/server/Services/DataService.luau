--!strict
-- Loads, autosaves and releases each player's profile (see Data/ProfileStore for the
-- session locking). If DataStores aren't reachable (an unpublished place, or Studio
-- without "Enable Studio Access to API Services"), profiles live in memory for the
-- session and players are told their progress won't save.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Profile = require(Shared.Progression.Profile)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)

local DataService = {}

local STORE_NAME = "DoublePump_Profiles_v1"
local AUTOSAVE_INTERVAL = 90

DataService.Loaded = Signal.new() :: Signal.Signal<Player, Profile.Data>
DataService.available = false
DataService.reason = "" :: string

local profiles: { [Player]: Profile.Data } = {}
local dirty: { [Player]: boolean } = {}
local lost: { [Player]: boolean } = {}
local store: ProfileStore.ProfileStoreT? = nil

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function probe(): (boolean, string)
	if game.PlaceId == 0 then
		return false, "this place isn't published yet"
	end
	local ok, err = pcall(function()
		DataStoreService:GetDataStore(STORE_NAME):GetAsync("__probe")
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, ""
end

function DataService.get(player: Player): Profile.Data?
	return profiles[player]
end

function DataService.isReady(player: Player): boolean
	return profiles[player] ~= nil
end

-- Changes a profile through a function and marks it for the next autosave.
function DataService.update(player: Player, fn: (Profile.Data) -> ())
	local data = profiles[player]
	if data then
		fn(data)
		dirty[player] = true
	end
end

-- Saves right away (used after purchases). Returns true when the save landed.
function DataService.saveNow(player: Player, release: boolean?): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	if not store or not DataService.available then
		return not release -- in-memory sessions can't persist
	end
	if lost[player] then
		return false
	end
	local ok, reason = (store :: ProfileStore.ProfileStoreT):save(keyFor(player), data, release == true)
	if ok then
		dirty[player] = false
	elseif reason == "lost" then
		lost[player] = true
		warn(`[DataService] {player.Name}'s profile is open on another server; this server stopped saving it`)
	else
		warn(`[DataService] save failed for {player.Name}: {reason}`)
	end
	return ok
end

local function onPlayerAdded(player: Player)
	local data: Profile.Data? = nil
	if store and DataService.available then
		local loaded, err = (store :: ProfileStore.ProfileStoreT):load(keyFor(player))
		if not loaded then
			warn(`[DataService] couldn't load {player.Name}: {err}`)
			if player.Parent then
				player:Kick("Your profile couldn't be loaded (Roblox data service busy). Please rejoin in a minute.")
			end
			return
		end
		data = loaded
	else
		data = Profile.new(os.time())
	end
	if not player.Parent then
		-- Left while loading: release the lock we just took
		if store and DataService.available and data then
			(store :: ProfileStore.ProfileStoreT):save(keyFor(player), data, true)
		end
		return
	end
	profiles[player] = data :: Profile.Data
	DataService.Loaded:Fire(player, data :: Profile.Data)
	if not DataService.available then
		Net.event("Notify"):FireClient(player, "Progress won't save in this session: " .. DataService.reason, "warn")
	end
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		DataService.saveNow(player, true)
	end
	profiles[player] = nil
	dirty[player] = nil
	lost[player] = nil
end

function DataService.start()
	local ok, reason = probe()
	DataService.available = ok
	DataService.reason = reason
	if ok then
		store = ProfileStore.new(DataStoreService:GetDataStore(STORE_NAME) :: any, {
			jobId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false),
			clock = os.time,
			sleep = function(seconds: number)
				task.wait(seconds)
			end,
		})
	else
		warn(`[DataService] DataStores unavailable ({reason}); profiles are kept in memory only`)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				-- Saving also refreshes the session lock, so save even when nothing changed
				task.spawn(DataService.saveNow, player, false)
			end
		end
	end)

	game:BindToClose(function()
		if not DataService.available or RunService:IsStudio() and next(profiles) == nil then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.saveNow(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
