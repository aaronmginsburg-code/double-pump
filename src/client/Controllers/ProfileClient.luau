--!strict
-- Caches the local player's profile snapshot (level, coins, stats, cosmetics,
-- challenges) sent by the server, and wraps shop/equip requests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Cosmetics = require(Shared.Progression.Cosmetics)

local ProfileClient = {}

ProfileClient.data = nil :: any
ProfileClient.Changed = Signal.new() :: Signal.Signal<any>
ProfileClient.Reward = Signal.new() :: Signal.Signal<any>
ProfileClient.Unlocked = Signal.new() :: Signal.Signal<any>

local skinListeners: { (any) -> () } = {}

local function setData(snapshot: any)
	if typeof(snapshot) ~= "table" then
		return
	end
	local previousSkin = ProfileClient.data and ProfileClient.data.equipped and ProfileClient.data.equipped.skin
	ProfileClient.data = snapshot
	ProfileClient.Changed:Fire(snapshot)
	local skin = snapshot.equipped and snapshot.equipped.skin
	if skin ~= previousSkin then
		for _, fn in skinListeners do
			fn(Cosmetics.skin(skin))
		end
	end
end

function ProfileClient.get(): any
	return ProfileClient.data
end

function ProfileClient.loaded(): boolean
	return ProfileClient.data ~= nil
end

function ProfileClient.owns(id: string): boolean
	local d = ProfileClient.data
	return d ~= nil and d.owned ~= nil and d.owned[id] == true
end

function ProfileClient.onSkin(fn: (any) -> ())
	table.insert(skinListeners, fn)
	local d = ProfileClient.data
	fn(Cosmetics.skin(d and d.equipped and d.equipped.skin))
end

function ProfileClient.buy(id: string)
	Net.event("ShopAction"):FireServer("Buy", id)
end

function ProfileClient.equip(id: string)
	Net.event("ShopAction"):FireServer("Equip", "skin", id)
end

function ProfileClient.buyPack(key: string)
	Net.event("ShopAction"):FireServer("BuyRobux", key)
end

function ProfileClient.leaderboards(): any
	local ok, result = pcall(function()
		return Net.func("GetLeaderboards"):InvokeServer()
	end)
	return if ok then result else nil
end

function ProfileClient.start()
	Net.event("ProfileEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Profile" then
			setData(data)
		elseif kind == "Reward" then
			ProfileClient.Reward:Fire(data)
		elseif kind == "Unlock" then
			ProfileClient.Unlocked:Fire(data)
		end
	end)
	task.spawn(function()
		-- The server pushes the profile once loaded; ask too in case we missed it.
		for _ = 1, 10 do
			if ProfileClient.data then
				return
			end
			local ok, result = pcall(function()
				return Net.func("GetProfile"):InvokeServer()
			end)
			if ok and result then
				setData(result)
				return
			end
			task.wait(2)
		end
	end)
end

return ProfileClient
