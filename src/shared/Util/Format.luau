--!strict
-- Number formatting for the UI.

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234567 -> "1,234,567"
function Format.commas(n: number): string
	local negative = n < 0
	local digits = tostring(math.floor(math.abs(n)))
	local formatted = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	return if negative then "-" .. formatted else formatted
end

-- 999 -> "999", 1234 -> "1.23K", 15600000 -> "15.6M". Values below `commasBelow` use commas.
function Format.short(n: number, commasBelow: number?): string
	local limit = commasBelow or 1000
	if math.abs(n) < limit then
		return Format.commas(n)
	end
	local negative = n < 0
	local value = math.abs(n)
	local index = 0
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	if index == 0 then
		return Format.commas(n)
	end
	-- Truncate (never round up past what the player owns) to 3 significant digits.
	local decimals = if value >= 100 then 0 elseif value >= 10 then 1 else 2
	local factor = 10 ^ decimals
	local truncated = math.floor(value * factor) / factor
	local text = string.format(`%.{decimals}f`, truncated)
	if decimals > 0 then
		text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	end
	return (if negative then "-" else "") .. text .. SUFFIXES[index]
end

-- 3725 -> "1:02:05", 125 -> "2:05"
function Format.duration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h, m = s // 3600, (s % 3600) // 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s % 60)
	end
	return string.format("%d:%02d", m, s % 60)
end

-- Income per second: one decimal below 1,000 when it isn't whole (71.4), short form above.
-- Truncated like Format.short, so a rate is never shown higher than it is.
function Format.rate(n: number): string
	if math.abs(n) < 1000 then
		local tenths = math.floor(n * 10 + 1e-9) / 10
		if tenths % 1 ~= 0 then
			return string.format("%.1f", tenths)
		end
	end
	return Format.short(n)
end

-- Income bonus over a base value as a tag: (71.4, 70) -> "+2%", (210, 70) -> "+200%".
-- Nil when there is no visible difference.
function Format.bonusPercent(value: number, base: number): string?
	if base <= 0 then
		return nil
	end
	local rounded = math.floor((value / base - 1) * 1000 + 0.5) / 10
	if rounded == 0 then
		return nil
	end
	local text = if rounded % 1 == 0 then string.format("%d", rounded) else string.format("%.1f", rounded)
	return (if rounded > 0 then "+" else "") .. text .. "%"
end

return Format
