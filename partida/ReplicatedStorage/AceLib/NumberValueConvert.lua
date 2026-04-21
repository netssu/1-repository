local module = {}

local abbreviations = {
	["k"] = 4,
	["m"] = 7,
	["b"] = 10,
	["t"] = 13,
	["qd"] = 16,
	["qi"] = 19,
	["se"] = 22,
	["sp"] = 25,
	["o"] = 28,
}

local function round2dp(num)
	return math.floor(num * 100 + 0.5) / 100
end

function module.convert(number)
	number = round2dp(number)
	
	local text = tostring(string.format("%.f", math.floor(number)))

	local chosenAbbreviation
	for abbreviation, digit in pairs(abbreviations) do
		if (#text >= digit and #text < (digit + 3)) then
			chosenAbbreviation = abbreviation
			break
		end
	end

	if chosenAbbreviation then
		local digits = abbreviations[chosenAbbreviation]
		local shortValue = number / 10 ^ (digits - 1)

		-- Use 2 decimal places for 1M and above, otherwise 1
		local decimalPlaces = digits >= 7 and 2 or 1

		text = string.format("%." .. decimalPlaces .. "f", shortValue) .. chosenAbbreviation
	else
		text = number
	end

	return text
end

function module.formatNumber(num: number): string
	local formatted = tostring(num)
	while true do
		local k
		formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

return module