--!strict
-- Robux products. Cosmetic currency only: coins buy skins, nothing that affects combat.
--
-- Real-money sales are OFF until the owner turns them on:
--   1. Create each Developer Product in the Creator Dashboard (see docs/PUBLISHING.md).
--   2. Paste its numeric ID into `productId` below.
--   3. Set `Enabled = true`.
-- Until then the shop shows these packs as "coming soon" and the server ignores any
-- receipt for an unknown product. No IDs are guessed or hard-coded here.

local Products = {}

Products.Enabled = false

export type CoinPack = { key: string, name: string, coins: number, productId: number? }

Products.CoinPacks = {
	{ key = "Coins500", name = "Pocket of Shells", coins = 500, productId = nil },
	{ key = "Coins1200", name = "Bandolier", coins = 1200, productId = nil },
	{ key = "Coins3000", name = "Ammo Crate", coins = 3000, productId = nil },
} :: { CoinPack }

function Products.byKey(key: any): CoinPack?
	for _, pack in Products.CoinPacks do
		if pack.key == key then
			return pack
		end
	end
	return nil
end

function Products.byProductId(id: number): CoinPack?
	for _, pack in Products.CoinPacks do
		if pack.productId ~= nil and pack.productId == id then
			return pack
		end
	end
	return nil
end

-- A pack can be sold only when sales are enabled and it has a real product ID.
function Products.available(pack: CoinPack): boolean
	return Products.Enabled and typeof(pack.productId) == "number" and (pack.productId :: number) > 0
end

return Products
