--!strict
-- Cosmetic catalog. Cosmetics never change damage, timing, spread, sound loudness or
-- visibility: a skin only recolours the shotgun.
--
-- How an item unlocks:
--   price   buy with coins (earned by playing; coins can also come from Robux packs)
--   level   reach a player level
--   mastery reach a shotgun mastery tier (see Levels.Mastery)
--   default owned from the start

local Cosmetics = {}

export type Unlock =
	{ kind: "default" }
	| { kind: "price", coins: number }
	| { kind: "level", level: number }
	| { kind: "mastery", tier: number }

export type Skin = {
	id: string,
	name: string,
	rarity: "Common" | "Rare" | "Epic" | "Legendary",
	unlock: Unlock,
	metal: Color3,
	wood: Color3,
	accent: Color3,
	material: Enum.Material?,
	tint: Color3?,
}

local rgb = Color3.fromRGB

Cosmetics.Skins = {
	{
		id = "Default",
		name = "Standard Issue",
		rarity = "Common",
		unlock = { kind = "default" },
		metal = rgb(40, 44, 54),
		wood = rgb(150, 88, 48),
		accent = rgb(24, 26, 30),
	},
	{
		id = "Slate",
		name = "Slate",
		rarity = "Common",
		unlock = { kind = "price", coins = 150 },
		metal = rgb(78, 84, 96),
		wood = rgb(52, 56, 64),
		accent = rgb(30, 32, 38),
	},
	{
		id = "Sandstorm",
		name = "Sandstorm",
		rarity = "Common",
		unlock = { kind = "price", coins = 300 },
		metal = rgb(186, 160, 116),
		wood = rgb(120, 92, 60),
		accent = rgb(80, 64, 44),
	},
	{
		id = "Glacier",
		name = "Glacier",
		rarity = "Rare",
		unlock = { kind = "price", coins = 500 },
		metal = rgb(214, 232, 244),
		wood = rgb(118, 170, 210),
		accent = rgb(60, 110, 160),
	},
	{
		id = "Crimson",
		name = "Crimson",
		rarity = "Rare",
		unlock = { kind = "price", coins = 600 },
		metal = rgb(150, 26, 34),
		wood = rgb(36, 20, 22),
		accent = rgb(230, 190, 120),
	},
	{
		id = "Cobalt",
		name = "Cobalt",
		rarity = "Rare",
		unlock = { kind = "price", coins = 600 },
		metal = rgb(32, 70, 170),
		wood = rgb(24, 28, 40),
		accent = rgb(200, 210, 230),
	},
	{
		id = "Toxic",
		name = "Toxic",
		rarity = "Epic",
		unlock = { kind = "price", coins = 1200 },
		metal = rgb(30, 34, 30),
		wood = rgb(120, 230, 40),
		accent = rgb(120, 230, 40),
		material = Enum.Material.SmoothPlastic,
	},
	{
		id = "Sunset",
		name = "Sunset",
		rarity = "Epic",
		unlock = { kind = "price", coins = 1500 },
		metal = rgb(255, 120, 60),
		wood = rgb(120, 40, 140),
		accent = rgb(255, 210, 90),
		material = Enum.Material.SmoothPlastic,
	},
	{
		id = "Rookie",
		name = "Rookie Teal",
		rarity = "Common",
		unlock = { kind = "level", level = 5 },
		metal = rgb(30, 130, 130),
		wood = rgb(220, 220, 210),
		accent = rgb(20, 60, 60),
	},
	{
		id = "Veteran",
		name = "Veteran Olive",
		rarity = "Rare",
		unlock = { kind = "level", level = 20 },
		metal = rgb(80, 90, 50),
		wood = rgb(110, 80, 50),
		accent = rgb(30, 30, 24),
	},
	{
		id = "Elite",
		name = "Elite Carbon",
		rarity = "Epic",
		unlock = { kind = "level", level = 50 },
		metal = rgb(20, 20, 24),
		wood = rgb(36, 36, 42),
		accent = rgb(255, 168, 38),
		material = Enum.Material.Slate,
	},
	{
		id = "MasteryBronze",
		name = "Bronze Mastery",
		rarity = "Rare",
		unlock = { kind = "mastery", tier = 1 },
		metal = rgb(150, 92, 40),
		wood = rgb(70, 40, 24),
		accent = rgb(205, 127, 50),
		material = Enum.Material.Metal,
	},
	{
		id = "MasterySilver",
		name = "Silver Mastery",
		rarity = "Rare",
		unlock = { kind = "mastery", tier = 2 },
		metal = rgb(190, 196, 206),
		wood = rgb(46, 48, 56),
		accent = rgb(230, 234, 240),
		material = Enum.Material.Metal,
	},
	{
		id = "MasteryGold",
		name = "Gold Mastery",
		rarity = "Epic",
		unlock = { kind = "mastery", tier = 3 },
		metal = rgb(230, 180, 50),
		wood = rgb(40, 30, 24),
		accent = rgb(255, 230, 140),
		material = Enum.Material.Metal,
	},
	{
		id = "MasteryDiamond",
		name = "Diamond Mastery",
		rarity = "Legendary",
		unlock = { kind = "mastery", tier = 4 },
		metal = rgb(120, 220, 255),
		wood = rgb(30, 40, 60),
		accent = rgb(220, 250, 255),
		material = Enum.Material.Glass,
	},
	{
		id = "PumpMaster",
		name = "Pump Master",
		rarity = "Legendary",
		unlock = { kind = "mastery", tier = 5 },
		metal = rgb(24, 22, 26),
		wood = rgb(255, 120, 40),
		accent = rgb(255, 210, 80),
		material = Enum.Material.Neon,
	},
} :: { Skin }

Cosmetics.RarityColors = {
	Common = rgb(170, 176, 190),
	Rare = rgb(70, 160, 255),
	Epic = rgb(190, 90, 255),
	Legendary = rgb(255, 168, 38),
}

local byId: { [string]: Skin } = {}
for _, skin in Cosmetics.Skins do
	byId[skin.id] = skin
end

function Cosmetics.skin(id: string?): Skin
	return (id and byId[id]) or byId.Default
end

function Cosmetics.exists(id: any): boolean
	return typeof(id) == "string" and byId[id] ~= nil
end

-- True when the player meets the unlock condition without paying (default/level/mastery).
function Cosmetics.earned(skin: Skin, level: number, masteryTier: number): boolean
	local u = skin.unlock :: any
	if u.kind == "default" then
		return true
	elseif u.kind == "level" then
		return level >= u.level
	elseif u.kind == "mastery" then
		return masteryTier >= u.tier
	end
	return false
end

function Cosmetics.price(skin: Skin): number?
	local u = skin.unlock :: any
	return if u.kind == "price" then u.coins else nil
end

function Cosmetics.unlockText(skin: Skin): string
	local u = skin.unlock :: any
	if u.kind == "price" then
		return `{u.coins} coins`
	elseif u.kind == "level" then
		return `Reach level {u.level}`
	elseif u.kind == "mastery" then
		return `Mastery tier {u.tier}`
	end
	return "Owned"
end

return Cosmetics
