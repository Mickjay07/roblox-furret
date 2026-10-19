--!strict
-- Per-key token bucket. Each key starts with `burst` tokens and regains `rate` per second.

export type RateLimiter = {
	allow: (self: RateLimiter, key: any) -> boolean,
	forget: (self: RateLimiter, key: any) -> (),
}

local RateLimiter = {}

function RateLimiter.new(rate: number, burst: number, clock: (() -> number)?): RateLimiter
	local now = clock or os.clock
	local buckets: { [any]: { tokens: number, last: number } } = {}

	local self = {}

	function self.allow(_, key: any): boolean
		local t = now()
		local bucket = buckets[key]
		if not bucket then
			bucket = { tokens = burst, last = t }
			buckets[key] = bucket
		end
		bucket.tokens = math.min(burst, bucket.tokens + (t - bucket.last) * rate)
		bucket.last = t
		if bucket.tokens >= 1 then
			bucket.tokens -= 1
			return true
		end
		return false
	end

	function self.forget(_, key: any)
		buckets[key] = nil
	end

	return (self :: any) :: RateLimiter
end

return RateLimiter
