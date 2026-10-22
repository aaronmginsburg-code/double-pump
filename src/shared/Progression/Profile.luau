--!strict
-- Saved profile schema. `sanitize` turns whatever came out of the DataStore (old
-- version, missing fields, corrupted values) into a valid current profile, keeping
-- everything that is still valid. Never throws.

local Challenges = require(script.Parent.Challenges)
local Cosmetics = require(script.Parent.Cosmetics)

local Preferences = require(script.Parent.Parent.Preferences)

local Profile = {}

Profile.Version = 3
Profile.MaxReceipts = 200

export type Stats = {
	kills: number,
	deaths: number,
	assists: number,
	headshots: number,
	doublePumps: number,
	wins: number,
	losses: number,
	matches: number,
	damage: number,
	pelletsFired: number,
	pelletsHit: number,
	timePlayed: number,
}

export type Data = {
	version: number,
	xp: number,
	coins: number,
	stats: Stats,
	masteryKills: number,
	owned: { [string]: boolean },
	equipped: { skin: string },
	daily: Challenges.Set?,
	weekly: Challenges.Set?,
	settings: { [string]: any },
	tutorialDone: boolean,
	receipts: { string }, -- PurchaseIds already granted (newest last)
	createdAt: number,
}

local STAT_KEYS = {
	"kills",
	"deaths",
	"assists",
	"headshots",
	"doublePumps",
	"wins",
	"losses",
	"matches",
	"damage",
	"pelletsFired",
	"pelletsHit",
	"timePlayed",
}
Profile.StatKeys = STAT_KEYS

function Profile.new(now: number): Data
	local stats = {}
	for _, key in STAT_KEYS do
		stats[key] = 0
	end
	return {
		version = Profile.Version,
		xp = 0,
		coins = 0,
		stats = stats :: any,
		masteryKills = 0,
		owned = { Default = true },
		equipped = { skin = "Default" },
		daily = nil,
		weekly = nil,
		settings = { controlLayout = "right", weaponHand = "right", touchLayoutV2 = {} },
		tutorialDone = false,
		receipts = {},
		createdAt = now,
	}
end

local function num(v: any, fallback: number): number
	if typeof(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then
		return math.max(0, v)
	end
	return fallback
end

local function challengeSet(v: any): Challenges.Set?
	if typeof(v) ~= "table" or typeof(v.period) ~= "number" or typeof(v.entries) ~= "table" then
		return nil
	end
	local entries = {}
	for _, e in v.entries do
		if typeof(e) == "table" and typeof(e.id) == "string" and Challenges.find(e.id) then
			table.insert(entries, { id = e.id, progress = num(e.progress, 0), done = e.done == true })
		end
	end
	return { period = v.period, entries = entries }
end

function Profile.sanitize(raw: any, now: number): Data
	local p = Profile.new(now)
	if typeof(raw) ~= "table" then
		return p
	end
	p.xp = math.floor(num(raw.xp, 0))
	p.coins = math.floor(num(raw.coins, 0))
	p.masteryKills = math.floor(num(raw.masteryKills, 0))
	p.createdAt = num(raw.createdAt, now)
	p.tutorialDone = raw.tutorialDone == true
	if typeof(raw.stats) == "table" then
		for _, key in STAT_KEYS do
			(p.stats :: any)[key] = num(raw.stats[key], 0)
		end
	end
	if typeof(raw.owned) == "table" then
		for id, owned in raw.owned do
			if owned == true and Cosmetics.exists(id) then
				p.owned[id] = true
			end
		end
	end
	if typeof(raw.equipped) == "table" and Cosmetics.exists(raw.equipped.skin) and p.owned[raw.equipped.skin] then
		p.equipped.skin = raw.equipped.skin
	end
	p.daily = challengeSet(raw.daily)
	p.weekly = challengeSet(raw.weekly)
	if typeof(raw.settings) == "table" then
		for k, v in raw.settings do
			local t = typeof(v)
			if typeof(k) == "string" and (t == "number" or t == "boolean" or t == "string" or t == "table") then
				p.settings[k] = v
			end
		end
	end
	-- v1 -> v2: preserve legacy button positions separately; new control roles use
	-- a fresh layout so an old FIRE position cannot become an overlapping fire pad.
	-- v2 -> v3: retain both sides of the old coupled preference, then save separately.
	local presentation = Preferences.normalize(raw.settings)
	p.settings.controlLayout = presentation.controlLayout
	p.settings.weaponHand = presentation.weaponHand
	if typeof(p.settings.touchLayoutV2) ~= "table" then
		p.settings.touchLayoutV2 = {}
	end
	if typeof(raw.receipts) == "table" then
		for _, id in raw.receipts do
			if typeof(id) == "string" then
				table.insert(p.receipts, id)
			end
		end
		while #p.receipts > Profile.MaxReceipts do
			table.remove(p.receipts, 1)
		end
	end
	return p
end

function Profile.hasReceipt(p: Data, purchaseId: string): boolean
	return table.find(p.receipts, purchaseId) ~= nil
end

function Profile.addReceipt(p: Data, purchaseId: string)
	table.insert(p.receipts, purchaseId)
	while #p.receipts > Profile.MaxReceipts do
		table.remove(p.receipts, 1)
	end
end

return Profile
