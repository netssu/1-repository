local RomanConverter = {}

local romanNumerals = {
	{1000, "M"},
	{900, "CM"},
	{500, "D"},
	{400, "CD"},
	{100, "C"},
	{90, "XC"},
	{50, "L"},
	{40, "XL"},
	{10, "X"},
	{9, "IX"},
	{5, "V"},
	{4, "IV"},
	{1, "I"}
}

function RomanConverter.toRoman(num)
	if num == 0 or num == tostring('0') then return 0 end
	
	local result = ""

	for _, numeral in ipairs(romanNumerals) do
		local value, symbol = numeral[1], numeral[2]
		while num >= value do
			result = result .. symbol
			num = num - value
		end
	end

	return result
end

return RomanConverter
