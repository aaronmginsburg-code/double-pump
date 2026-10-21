--!strict
-- Session-locked profile storage on top of a DataStore-like object (anything with
-- UpdateAsync). Kept free of Roblox services so it can be unit tested with a fake store.
--
-- Record layout: { data = <profile>, lock = { jobId = string, at = number }? }
--
-- Session locking: a server that loads a profile stamps its JobId on it and refreshes the
-- stamp on every autosave. Another server that wants the same profile (the player
-- rejoined quickly) waits for the lock to be released; a lock that hasn't been refreshed
-- for `lockTimeout` seconds belongs to a dead server and is taken over. A server that
-- finds its lock taken stops saving that profile, so two servers never overwrite each
-- other.

local Profile = require(game:GetService("ReplicatedStorage").Shared.Progression.Profile)

local ProfileStore = {}
ProfileStore.__index = ProfileStore

export type Store = { UpdateAsync: (any, string, (any) -> any) -> any }

export type Options = {
	jobId: string,
	clock: () -> number,
	sleep: (number) -> (),
	lockTimeout: number?,
	lockWaits: number?, -- how many times to wait for a held lock before taking it
	lockWaitTime: number?,
	retries: number?, -- retries for DataStore errors (throttling, outages)
}

export type ProfileStoreT = typeof(setmetatable(
	{} :: {
		store: Store,
		jobId: string,
		clock: () -> number,
		sleep: (number) -> (),
		lockTimeout: number,
		lockWaits: number,
		lockWaitTime: number,
		retries: number,
	},
	ProfileStore
))

function ProfileStore.new(store: Store, options: Options): ProfileStoreT
	return setmetatable({
		store = store,
		jobId = options.jobId,
		clock = options.clock,
		sleep = options.sleep,
		lockTimeout = options.lockTimeout or 600,
		lockWaits = options.lockWaits or 5,
		lockWaitTime = options.lockWaitTime or 4,
		retries = options.retries or 5,
	}, ProfileStore)
end

-- Calls UpdateAsync, retrying errors with exponential backoff. Returns (ok, result, err).
local function update(self: ProfileStoreT, key: string, transform: (any) -> any): (boolean, any, string?)
	local lastErr: string? = nil
	for attempt = 1, self.retries + 1 do
		local ok, result = pcall(function()
			return self.store:UpdateAsync(key, transform)
		end)
		if ok then
			return true, result, nil
		end
		lastErr = tostring(result)
		if attempt <= self.retries then
			self.sleep(math.min(2 ^ attempt, 16))
		end
	end
	return false, nil, lastErr
end

-- Loads and locks a profile. Returns (data, nil) or (nil, reason).
function ProfileStore.load(self: ProfileStoreT, key: string): (Profile.Data?, string?)
	for attempt = 1, self.lockWaits + 1 do
		local now = self.clock()
		local blocked = false
		local loaded: Profile.Data? = nil
		local force = attempt > self.lockWaits
		local ok, _, err = update(self, key, function(record: any)
			record = if typeof(record) == "table" then record else {}
			local lock = record.lock
			if
				not force
				and typeof(lock) == "table"
				and lock.jobId ~= self.jobId
				and typeof(lock.at) == "number"
				and now - lock.at < self.lockTimeout
			then
				blocked = true
				return nil -- cancel the write; someone else holds it
			end
			loaded = Profile.sanitize(record.data, now)
			return { data = loaded, lock = { jobId = self.jobId, at = now } }
		end)
		if not ok then
			return nil, err or "DataStore error"
		end
		if not blocked and loaded then
			return loaded, nil
		end
		self.sleep(self.lockWaitTime)
	end
	return nil, "locked"
end

-- Saves a profile. `release` also drops the session lock (player leaving). Returns
-- (true) on success, (false, "lost") if another server has taken the profile, or
-- (false, err) on DataStore failure.
function ProfileStore.save(self: ProfileStoreT, key: string, data: Profile.Data, release: boolean): (boolean, string?)
	local lost = false
	local now = self.clock()
	local ok, _, err = update(self, key, function(record: any)
		record = if typeof(record) == "table" then record else {}
		local lock = record.lock
		if typeof(lock) == "table" and lock.jobId ~= self.jobId then
			lost = true
			return nil
		end
		return {
			data = data,
			lock = if release then nil else { jobId = self.jobId, at = now },
		}
	end)
	if not ok then
		return false, err
	end
	if lost then
		return false, "lost"
	end
	return true, nil
end

return ProfileStore
