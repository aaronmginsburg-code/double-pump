--!nocheck
local T = require("./runner/T")
local Loader = require("./runner/Loader")
local Shared = Loader.Shared
local Levels = Loader.require(Shared.Progression.Levels)
local Challenges = Loader.require(Shared.Progression.Challenges)
local Cosmetics = Loader.require(Shared.Progression.Cosmetics)
local Profile = Loader.require(Shared.Progression.Profile)
local Products = Loader.require(Shared.Config.Products)
local describe, it, expect = T.describe, T.it, T.expect

describe("Levels", function()
	it("starts at level 1", function()
		local info = Levels.fromXp(0)
		expect(info.level).toBe(1)
		expect(info.need).toBe(400)
	end)
	it("levels up at exact thresholds", function()
		expect(Levels.fromXp(399).level).toBe(1)
		expect(Levels.fromXp(400).level).toBe(2)
		expect(Levels.fromXp(400 + 500).level).toBe(3)
		expect(Levels.fromXp(400 + 500).into).toBe(0)
	end)
	it("caps at max level", function()
		local info = Levels.fromXp(10 ^ 9)
		expect(info.level).toBe(Levels.MaxLevel)
		expect(info.isMax).toBe(true)
	end)
	it("ignores negative and fractional xp", function()
		expect(Levels.fromXp(-50).level).toBe(1)
		expect(Levels.fromXp(399.9).level).toBe(1)
	end)
end)

describe("Match rewards", function()
	local base = {
		kills = 0,
		assists = 0,
		headshotKills = 0,
		doublePumps = 0,
		won = false,
		timePlayed = 300,
		matchLength = 300,
		activeTime = 280,
	}
	local function with(t)
		local s = table.clone(base)
		for k, v in t do
			s[k] = v
		end
		return s
	end
	it("rewards a full active match", function()
		local r = Levels.matchReward(base)
		expect(r.xp).toBe(Levels.Rewards.Completion)
		expect(r.idle).toBe(false)
	end)
	it("adds win, kills and bonuses", function()
		local r = Levels.matchReward(with({ kills = 10, headshotKills = 3, doublePumps = 2, assists = 4, won = true }))
		local R = Levels.Rewards
		expect(r.xp).toBe(10 * R.Kill + 3 * R.Headshot + 2 * R.DoublePump + 4 * R.Assist + R.Completion + R.Win)
		expect(r.coins).toBe(10 * R.CoinsPerKill + R.CoinsCompletion + R.CoinsWin)
	end)
	it("gives idle players no completion or win reward", function()
		local r = Levels.matchReward(with({ activeTime = 10, won = true }))
		expect(r.idle).toBe(true)
		expect(r.xp).toBe(0)
		expect(r.coins).toBe(0)
	end)
	it("still pays for eliminations when mostly idle", function()
		local r = Levels.matchReward(with({ activeTime = 10, kills = 2 }))
		expect(r.xp).toBe(2 * Levels.Rewards.Kill)
	end)
	it("scales completion by time in the match", function()
		local r = Levels.matchReward(with({ timePlayed = 150, activeTime = 140 }))
		expect(r.xp).toBe(math.floor(Levels.Rewards.Completion * 0.5))
	end)
end)

describe("Mastery", function()
	it("uses 25/100/250/500/1000", function()
		expect(Levels.mastery(0).tier).toBe(0)
		expect(Levels.mastery(24).tier).toBe(0)
		expect(Levels.mastery(25).tier).toBe(1)
		expect(Levels.mastery(100).tier).toBe(2)
		expect(Levels.mastery(250).tier).toBe(3)
		expect(Levels.mastery(500).tier).toBe(4)
		expect(Levels.mastery(1000).tier).toBe(5)
		expect(Levels.mastery(1000).nextAt).toBe(nil)
		expect(Levels.mastery(30).nextAt).toBe(100)
	end)
end)

describe("Challenges", function()
	local monday = 1729468800 -- 2024-10-21 00:00 UTC, a Monday
	it("picks the same set for the same day", function()
		local a = Challenges.current("daily", nil, monday + 100)
		local b = Challenges.current("daily", nil, monday + 80000)
		expect(#a.entries).toBe(3)
		for i = 1, 3 do
			expect(a.entries[i].id).toBe(b.entries[i].id)
		end
	end)
	it("picks distinct challenges", function()
		local set = Challenges.current("weekly", nil, monday)
		local seen = {}
		for _, e in set.entries do
			expect(seen[e.id]).toBe(nil)
			seen[e.id] = true
		end
	end)
	it("rolls over to a new day", function()
		local a = Challenges.current("daily", nil, monday)
		a.entries[1].progress = 5
		local same = Challenges.current("daily", a, monday + 3600)
		expect(same).toBe(a)
		local nextDay = Challenges.current("daily", a, monday + 86400)
		expect(nextDay.period).toBe(a.period + 1)
		expect(nextDay.entries[1].progress).toBe(0)
	end)
	it("weeks start on Monday", function()
		expect(Challenges.weekNumber(monday)).toBe(Challenges.weekNumber(monday + 6 * 86400 + 86399))
		expect(Challenges.weekNumber(monday - 1)).toBe(Challenges.weekNumber(monday) - 1)
		expect(Challenges.secondsLeft("weekly", monday)).toBe(7 * 86400)
		expect(Challenges.secondsLeft("daily", monday + 3600)).toBe(86400 - 3600)
	end)
	it("completes once and clamps progress", function()
		local set = { period = 1, entries = { { id = "d_kills10", progress = 8, done = false } } }
		local done = Challenges.progress(set, { kills = 5 })
		expect(#done).toBe(1)
		expect(set.entries[1].progress).toBe(10)
		expect(#Challenges.progress(set, { kills = 5 })).toBe(0)
	end)
end)

describe("Cosmetics", function()
	it("unlocks by level and mastery", function()
		local rookie = Cosmetics.skin("Rookie")
		expect(Cosmetics.earned(rookie, 4, 0)).toBe(false)
		expect(Cosmetics.earned(rookie, 5, 0)).toBe(true)
		local gold = Cosmetics.skin("MasteryGold")
		expect(Cosmetics.earned(gold, 99, 2)).toBe(false)
		expect(Cosmetics.earned(gold, 1, 3)).toBe(true)
	end)
	it("falls back to the default skin", function()
		expect(Cosmetics.skin("nope").id).toBe("Default")
		expect(Cosmetics.exists("nope")).toBe(false)
	end)
	it("has unique ids", function()
		local seen = {}
		for _, s in Cosmetics.Skins do
			expect(seen[s.id]).toBe(nil)
			seen[s.id] = true
		end
	end)
end)

describe("Profile", function()
	it("sanitizes garbage into a fresh profile", function()
		local p = Profile.sanitize("garbage", 5)
		expect(p.xp).toBe(0)
		expect(p.owned.Default).toBe(true)
		expect(p.equipped.skin).toBe("Default")
	end)
	it("keeps valid fields and drops invalid ones", function()
		local p = Profile.sanitize({
			xp = 1234.7,
			coins = -50,
			stats = { kills = 12, deaths = "x" },
			owned = { Crimson = true, Fake = true },
			equipped = { skin = "Crimson" },
			receipts = { "a", 5, "b" },
		}, 0)
		expect(p.xp).toBe(1234)
		expect(p.coins).toBe(0)
		expect(p.stats.kills).toBe(12)
		expect(p.stats.deaths).toBe(0)
		expect(p.owned.Crimson).toBe(true)
		expect(p.owned.Fake).toBe(nil)
		expect(p.equipped.skin).toBe("Crimson")
		expect(#p.receipts).toBe(2)
	end)
	it("refuses an equipped skin that is not owned", function()
		local p = Profile.sanitize({ equipped = { skin = "PumpMaster" } }, 0)
		expect(p.equipped.skin).toBe("Default")
	end)
	it("bounds the receipt ledger", function()
		local p = Profile.new(0)
		for i = 1, Profile.MaxReceipts + 10 do
			Profile.addReceipt(p, tostring(i))
		end
		expect(#p.receipts).toBe(Profile.MaxReceipts)
		expect(Profile.hasReceipt(p, "1")).toBe(false)
		expect(Profile.hasReceipt(p, tostring(Profile.MaxReceipts + 10))).toBe(true)
	end)
end)

describe("Products", function()
	it("ships with real-money sales off and no product ids", function()
		expect(Products.Enabled).toBe(false)
		for _, pack in Products.CoinPacks do
			expect(pack.productId).toBe(nil)
			expect(Products.available(pack)).toBe(false)
		end
	end)
end)
