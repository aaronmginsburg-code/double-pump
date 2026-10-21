--!strict
-- Robux coin packs (cosmetic currency only). OFF by default: nothing is sold until the
-- owner fills in real Developer Product IDs and sets Products.Enabled (see
-- docs/PUBLISHING.md).
--
-- Receipts are processed idempotently: each PurchaseId is recorded in the buyer's
-- profile in the same save that grants the coins, and PurchaseGranted is only returned
-- once that save has landed. A repeated receipt is acknowledged without granting again.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Products = require(Shared.Config.Products)

local Receipts = require(script.Parent.Parent.Data.Receipts)
local Services = script.Parent
local DataService = require(Services.DataService)
local ProgressionService = require(Services.ProgressionService)
local CosmeticService = require(Services.CosmeticService)

local MonetizationService = {}

local notify: RemoteEvent

function MonetizationService.prompt(player: Player, key: string)
	local pack = Products.byKey(key)
	if not pack or not Products.available(pack) then
		notify:FireClient(player, "Coin packs aren't on sale yet.", "info")
		return
	end
	MarketplaceService:PromptProductPurchase(player, pack.productId :: number)
end

function MonetizationService.start()
	notify = Net.event("Notify")
	CosmeticService.promptPack = MonetizationService.prompt
	if not Products.Enabled then
		return -- no ProcessReceipt handler: nothing can be bought
	end
	MarketplaceService.ProcessReceipt = function(receipt: any)
		return Receipts.process(receipt, {
			getPlayer = function(userId)
				return Players:GetPlayerByUserId(userId)
			end,
			getProfile = DataService.get,
			save = function(player)
				return DataService.saveNow(player, false)
			end,
			onGranted = function(player, coins)
				notify:FireClient(player, `+{coins} coins. Thanks for supporting Double Pump!`, "reward")
				ProgressionService.push(player)
			end,
		})
	end
end

return MonetizationService
