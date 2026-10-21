--!nocheck
local T = require("./runner/T")
local Loader = require("./runner/Loader")
local ProfileStore = Loader.require(Loader.Server.Data.ProfileStore)
local describe, it, expect = T.describe, T.it, T.expect

-- In-memory DataStore with UpdateAsync semantics (transform returning nil = no write)
-- and optional injected failures.
local function deepCopy(v)
	if typeof(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

local function fakeStore()
	local store = { data = {}, failNext = 0, writes = 0 }
	function store:UpdateAsync(key, transform)
		if self.failNext > 0 then
			self.failNext -= 1
			error("502: API Services rejected request")
		end
		local current = self.data[key]
		local result = transform(deepCopy(current))
		if result ~= nil then
			self.data[key] = deepCopy(result) -- DataStores serialise: no shared references
			self.writes += 1
		end
		return result
	end
	return store
end

local function clockAt(t)
	local c = { t = t }
	return c, function()
		return c.t
	end, function(dt)
		c.t += dt
	end
end

describe("ProfileStore", function()
	it("creates a fresh profile and locks it", function()
		local store = fakeStore()
		local c, clock, sleep = clockAt(1000)
		local ps = ProfileStore.new(store, { jobId = "A", clock = clock, sleep = sleep })
		local data = ps:load("u_1")
		expect(data ~= nil).toBe(true)
		expect(data.coins).toBe(0)
		expect(store.data.u_1.lock.jobId).toBe("A")
		local _ = c
	end)

	it("saves and releases", function()
		local store = fakeStore()
		local _, clock, sleep = clockAt(1000)
		local ps = ProfileStore.new(store, { jobId = "A", clock = clock, sleep = sleep })
		local data = ps:load("u_1")
		data.coins = 250
		expect(ps:save("u_1", data, true)).toBe(true)
		expect(store.data.u_1.data.coins).toBe(250)
		expect(store.data.u_1.lock).toBe(nil)
	end)

	it("waits for another server's fresh lock, then takes it over", function()
		local store = fakeStore()
		local c, clock, sleep = clockAt(1000)
		store.data.u_1 = { data = { coins = 40 }, lock = { jobId = "B", at = 995 } }
		local ps =
			ProfileStore.new(store, { jobId = "A", clock = clock, sleep = sleep, lockWaits = 3, lockWaitTime = 4 })
		local data = ps:load("u_1")
		expect(data.coins).toBe(40)
		expect(store.data.u_1.lock.jobId).toBe("A")
		expect(c.t >= 1012).toBe(true) -- waited 3 x 4 s first
	end)

	it("loads immediately once the other server releases", function()
		local store = fakeStore()
		local _, clock, sleep = clockAt(1000)
		store.data.u_1 = { data = { coins = 40 }, lock = nil }
		local ps = ProfileStore.new(store, { jobId = "A", clock = clock, sleep = sleep })
		expect(ps:load("u_1").coins).toBe(40)
	end)

	it("takes over a stale lock right away", function()
		local store = fakeStore()
		local c, clock, sleep = clockAt(5000)
		store.data.u_1 = { data = { coins = 7 }, lock = { jobId = "B", at = 100 } }
		local ps = ProfileStore.new(store, { jobId = "A", clock = clock, sleep = sleep })
		expect(ps:load("u_1").coins).toBe(7)
		expect(c.t).toBe(5000)
	end)

	it("refuses to save over a profile another server took", function()
		local store = fakeStore()
		local _, clock, sleep = clockAt(1000)
		local ps = ProfileStore.new(store, { jobId = "A", clock = clock, sleep = sleep })
		local data = ps:load("u_1")
		store.data.u_1.lock = { jobId = "B", at = 1001 }
		data.coins = 999
		local ok, reason = ps:save("u_1", data, false)
		expect(ok).toBe(false)
		expect(reason).toBe("lost")
		expect(store.data.u_1.data.coins).toBe(0)
	end)

	it("retries DataStore errors with backoff", function()
		local store = fakeStore()
		local c, clock, sleep = clockAt(1000)
		local ps = ProfileStore.new(store, { jobId = "A", clock = clock, sleep = sleep, retries = 3 })
		store.failNext = 2
		local data = ps:load("u_1")
		expect(data ~= nil).toBe(true)
		expect(c.t).toBe(1000 + 2 + 4)
	end)

	it("gives up after the retry budget", function()
		local store = fakeStore()
		local _, clock, sleep = clockAt(1000)
		local ps = ProfileStore.new(store, { jobId = "A", clock = clock, sleep = sleep, retries = 2 })
		store.failNext = 10
		local data, err = ps:load("u_1")
		expect(data).toBe(nil)
		expect(typeof(err)).toBe("string")
	end)

	it("sanitizes stored data on load", function()
		local store = fakeStore()
		local _, clock, sleep = clockAt(1000)
		store.data.u_1 = { data = { coins = -5, xp = "lots", owned = { Hacked = true } } }
		local ps = ProfileStore.new(store, { jobId = "A", clock = clock, sleep = sleep })
		local data = ps:load("u_1")
		expect(data.coins).toBe(0)
		expect(data.xp).toBe(0)
		expect(data.owned.Hacked).toBe(nil)
	end)
end)
