--!strict
-- Token bucket per key (usually a Player). Allows a short burst, then `rate` per second.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, last: number }
export type Limiter = typeof(setmetatable({} :: { burst: number, rate: number, buckets: { [any]: Bucket } }, RateLimiter))

function RateLimiter.new(burst: number, rate: number): Limiter
	return setmetatable({ burst = burst, rate = rate, buckets = {} }, RateLimiter)
end

function RateLimiter.allow(self: Limiter, key: any, now: number, cost: number?): boolean
	local bucket = self.buckets[key]
	if not bucket then
		bucket = { tokens = self.burst, last = now }
		self.buckets[key] = bucket
	end
	bucket.tokens = math.min(self.burst, bucket.tokens + (now - bucket.last) * self.rate)
	bucket.last = now
	local c = cost or 1
	if bucket.tokens < c then
		return false
	end
	bucket.tokens -= c
	return true
end

function RateLimiter.forget(self: Limiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
