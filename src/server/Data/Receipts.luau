--!strict
-- Developer Product receipt decisions, with the player/profile/save lookups injected so
-- the logic is unit tested (tests/monetization.spec.luau). Used by MonetizationService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Profile = require(ReplicatedStorage.Shared.Progression.Profile)

local Receipts = {}

export type Receipt = {
	PlayerId: number,
	ProductId: number,
	PurchaseId: string,
	CurrencySpent: number?,
	PlaceIdWherePurchased: number?,
}

function Receipts.process(
	receipt: Receipt,
	deps: {
		getPlayer: (number) -> Player?,
		getProfile: (Player) -> Profile.Data?,
		save: (Player) -> boolean,
		onGranted: (Player, number) -> (),
	}
): Enum.ProductPurchaseDecision
	local pack = Products.byProductId(receipt.ProductId)
	if not pack or not Products.available(pack) then
		warn(`[Monetization] receipt for unknown or disabled product {receipt.ProductId}; leaving it pending`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = deps.getPlayer(receipt.PlayerId)
	local data = player and deps.getProfile(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries when they're back
	end
	if Profile.hasReceipt(data, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	data.coins += pack.coins
	Profile.addReceipt(data, receipt.PurchaseId)
	if not deps.save(player) then
		-- Roll back so the retry grants exactly once
		data.coins -= pack.coins
		local index = table.find(data.receipts, receipt.PurchaseId)
		if index then
			table.remove(data.receipts, index)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	deps.onGranted(player, pack.coins)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return Receipts
