--!strict
-- Coalesce(fn) returns a function that schedules `fn` once for the end of the current
-- frame, however many times it is called before then. Used for window re-renders: one pack
-- opening replicates several data keys (Cards, Discovered, ...) back to back, and each
-- would otherwise rebuild every card tile again.
local function Coalesce(fn: () -> ()): () -> ()
	local scheduled = false
	return function()
		if scheduled then
			return
		end
		scheduled = true
		task.defer(function()
			scheduled = false
			fn()
		end)
	end
end

return Coalesce
