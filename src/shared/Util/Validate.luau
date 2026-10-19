--!strict
-- Type checks for untrusted values arriving over remotes. Each checker returns
-- (true) or (false, reason). Never trust a client-supplied value without one of these.

export type Checker = (value: any) -> (boolean, string?)

local Validate = {}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Validate.string(maxLength: number, pattern: string?): Checker
	return function(value)
		if type(value) ~= "string" then
			return false, "expected string"
		end
		if #value == 0 or #value > maxLength then
			return false, "string length out of range"
		end
		if pattern and not string.match(value, pattern) then
			return false, "string has invalid characters"
		end
		return true
	end
end

-- Identifiers: letters, digits, underscore, hyphen.
function Validate.id(maxLength: number): Checker
	return Validate.string(maxLength, "^[%w_%-]+$")
end

function Validate.integer(min: number, max: number): Checker
	return function(value)
		if not isFiniteNumber(value) or value % 1 ~= 0 then
			return false, "expected integer"
		end
		if value < min or value > max then
			return false, "integer out of range"
		end
		return true
	end
end

function Validate.number(min: number, max: number): Checker
	return function(value)
		if not isFiniteNumber(value) then
			return false, "expected number"
		end
		if value < min or value > max then
			return false, "number out of range"
		end
		return true
	end
end

function Validate.boolean(): Checker
	return function(value)
		if type(value) ~= "boolean" then
			return false, "expected boolean"
		end
		return true
	end
end

function Validate.oneOf(allowed: { [any]: any }): Checker
	return function(value)
		if (type(value) ~= "string" and type(value) ~= "number") or allowed[value] == nil then
			return false, "unknown value"
		end
		return true
	end
end

-- A plain array (keys 1..n, no holes) of 1..maxCount items, each passing `item`.
function Validate.array(item: Checker, maxCount: number): Checker
	return function(value)
		if type(value) ~= "table" or getmetatable(value :: any) ~= nil then
			return false, "expected array"
		end
		local count = 0
		for key in value do
			if type(key) ~= "number" then
				return false, "expected array"
			end
			count += 1
		end
		if count == 0 or count > maxCount or #value ~= count then
			return false, "array size out of range"
		end
		for _, element in ipairs(value) do
			local ok, reason = item(element)
			if not ok then
				return false, reason
			end
		end
		return true
	end
end

-- Checks a full argument list against one checker per position; extra arguments fail.
function Validate.args(checkers: { Checker }, args: { any }, argCount: number): (boolean, string?)
	if argCount ~= #checkers then
		return false, `expected {#checkers} arguments, got {argCount}`
	end
	for i, checker in checkers do
		local ok, reason = checker(args[i])
		if not ok then
			return false, `argument {i}: {reason}`
		end
	end
	return true
end

return Validate
