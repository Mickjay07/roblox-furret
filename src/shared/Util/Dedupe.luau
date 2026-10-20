--!strict
-- Suppresses repeats of the same key within a time window (identical toasts, e.g. several
-- "Not enough Cash" from quick clicks). Pure: the clock is injected for tests.
local Dedupe = {}

export type Dedupe = (key: string) -> boolean

-- Returns a function that answers true when `key` should be shown now, false when the
-- same key was shown less than `window` seconds ago.
function Dedupe.new(window: number, clock: () -> number): Dedupe
	local last: { [string]: number } = {}
	return function(key: string): boolean
		local now = clock()
		local previous = last[key]
		if previous and now - previous < window then
			return false
		end
		-- Forget stale keys so the table stays small.
		for k, t in last do
			if now - t >= window then
				last[k] = nil
			end
		end
		last[key] = now
		return true
	end
end

return Dedupe
