--!strict
-- The Locker: buying skins with coins and equipping them. Cosmetic only: a skin changes
-- the shotgun's colours and nothing else.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RateLimiter = require(Shared.Util.RateLimiter)
local Cosmetics = require(Shared.Progression.Cosmetics)

local Services = script.Parent
local DataService = require(Services.DataService)
local ProgressionService = require(Services.ProgressionService)
local CharacterService = require(Services.CharacterService)

local CosmeticService = {}

local limiter = RateLimiter.new(6, 2)
local notify: RemoteEvent

-- Set by MonetizationService (prompts a Robux coin pack).
CosmeticService.promptPack = nil :: ((Player, string) -> ())?

function CosmeticService.skinFor(player: Player): Cosmetics.Skin
	local data = DataService.get(player)
	return Cosmetics.skin(data and data.equipped.skin)
end

local function buy(player: Player, id: any)
	if not Cosmetics.exists(id) then
		return
	end
	local skin = Cosmetics.skin(id)
	local price = Cosmetics.price(skin)
	local data = DataService.get(player)
	if not data or not price then
		return
	end
	if data.owned[skin.id] then
		return
	end
	if data.coins < price then
		notify:FireClient(player, `Not enough coins for {skin.name}`, "error")
		return
	end
	DataService.update(player, function(d)
		d.coins -= price
		d.owned[skin.id] = true
		d.equipped.skin = skin.id
	end)
	notify:FireClient(player, `Bought {skin.name}`, "good")
	ProgressionService.push(player)
	CharacterService.refreshSkin(player)
end

local function equip(player: Player, category: any, id: any)
	if category ~= "skin" or not Cosmetics.exists(id) then
		return
	end
	local data = DataService.get(player)
	if not data or not data.owned[id] then
		return
	end
	DataService.update(player, function(d)
		d.equipped.skin = id
	end)
	ProgressionService.push(player)
	CharacterService.refreshSkin(player)
end

function CosmeticService.start()
	notify = Net.event("Notify")
	CharacterService.setSkinProvider(CosmeticService.skinFor)
	Net.event("ShopAction").OnServerEvent:Connect(function(player: Player, action: any, a: any, b: any)
		if not limiter:allow(player, os.clock()) then
			return
		end
		if action == "Buy" then
			buy(player, a)
		elseif action == "Equip" then
			equip(player, a, b)
		elseif action == "BuyRobux" then
			if typeof(a) == "string" and CosmeticService.promptPack then
				CosmeticService.promptPack(player, a)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return CosmeticService
