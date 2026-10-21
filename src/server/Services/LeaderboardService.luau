--!strict
-- Global leaderboards on OrderedDataStores: eliminations, wins, double pumps, level XP.
-- Scores are written after each match (throttled) and the top 10 of each board is
-- cached and refreshed every two minutes, so menus never wait on DataStores.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Profile = require(Shared.Progression.Profile)

local Services = script.Parent
local DataService = require(Services.DataService)
local ProgressionService = require(Services.ProgressionService)

local LeaderboardService = {}

local BOARDS = {
	{
		key = "Kills",
		title = "ELIMINATIONS",
		value = function(d: Profile.Data)
			return d.stats.kills
		end,
	},
	{
		key = "Wins",
		title = "WINS",
		value = function(d: Profile.Data)
			return d.stats.wins
		end,
	},
	{
		key = "DoublePumps",
		title = "DOUBLE PUMPS",
		value = function(d: Profile.Data)
			return d.stats.doublePumps
		end,
	},
	{
		key = "Xp",
		title = "XP",
		value = function(d: Profile.Data)
			return d.xp
		end,
	},
}
local VERSION = "v1"
local REFRESH = 120
local WRITE_COOLDOWN = 60

local stores: { [string]: OrderedDataStore } = {}
local cache: any = nil
local lastWrite: { [Player]: number } = {}
local names: { [number]: string } = {}

local function resolveNames(ids: { number })
	local missing = {}
	for _, id in ids do
		if not names[id] then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and infos then
		for _, info in infos do
			names[info.Id] = info.DisplayName
		end
	end
	for _, id in missing do
		if not names[id] then
			local player = Players:GetPlayerByUserId(id)
			names[id] = if player then player.DisplayName else "Player " .. id
		end
	end
end

local function refresh()
	local boards = {}
	for _, board in BOARDS do
		local store = stores[board.key]
		local entries = {}
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, 10)
		end)
		if ok and pages then
			local ids = {}
			for rank, item in pages:GetCurrentPage() do
				local id = tonumber(string.match(item.key, "%d+"))
				if id then
					table.insert(entries, { rank = rank, userId = id, value = item.value })
					table.insert(ids, id)
				end
			end
			resolveNames(ids)
			for _, entry in entries do
				entry.name = names[entry.userId]
			end
		end
		table.insert(boards, { key = board.key, title = board.title, entries = entries })
	end
	cache = { boards = boards }
end

function LeaderboardService.submit(player: Player, data: Profile.Data, force: boolean?)
	if not DataService.available then
		return
	end
	local now = os.clock()
	if not force and lastWrite[player] and now - lastWrite[player] < WRITE_COOLDOWN then
		return
	end
	lastWrite[player] = now
	for _, board in BOARDS do
		local value = math.floor(board.value(data))
		if value > 0 then
			task.spawn(function()
				pcall(function()
					stores[board.key]:SetAsync("u_" .. player.UserId, value)
				end)
			end)
		end
	end
end

function LeaderboardService.start()
	Net.func("GetLeaderboards").OnServerInvoke = function()
		if not DataService.available then
			return {
				unavailable = true,
				note = "Leaderboards need a published place with DataStores enabled (" .. DataService.reason .. ").",
			}
		end
		return cache or { boards = {} }
	end
	if not DataService.available then
		return
	end
	for _, board in BOARDS do
		stores[board.key] = DataStoreService:GetOrderedDataStore("DoublePump_LB_" .. board.key .. "_" .. VERSION)
	end
	ProgressionService.ProfileChanged:Connect(function(player, data)
		LeaderboardService.submit(player, data)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local data = DataService.get(player)
		if data then
			LeaderboardService.submit(player, data, true)
		end
		lastWrite[player] = nil
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH)
		end
	end)
end

return LeaderboardService
