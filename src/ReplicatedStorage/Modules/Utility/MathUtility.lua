------------------//CONSTANTS
local SUFFIXES = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}

------------------//VARIABLES
local MathUtility = {}

------------------//FUNCTIONS
function MathUtility.format_number(num: number): string
	if num < 1000 then
		return tostring(math.floor(num))
	end

	local suffixIndex = 1
	local value = num

	while value >= 1000 and suffixIndex < #SUFFIXES do
		value = value / 1000
		suffixIndex = suffixIndex + 1
	end

	if value >= 100 then
		return string.format("%d%s", math.floor(value), SUFFIXES[suffixIndex])
	elseif value >= 10 then
		return string.format("%.1f%s", math.floor(value * 10) / 10, SUFFIXES[suffixIndex])
	else
		return string.format("%.2f%s", math.floor(value * 100) / 100, SUFFIXES[suffixIndex])
	end
end

function MathUtility.round(num: number, decimals: number?): number
	local mult = 10 ^ (decimals or 0)
	return math.floor(num * mult + 0.5) / mult
end

function MathUtility.clamp(num: number, min: number, max: number): number
	return math.max(min, math.min(max, num))
end

function MathUtility.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

return MathUtility