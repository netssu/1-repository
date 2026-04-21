local format = {}

function format.Format(value, dp)
	local suffixes = {"", "K", "M", "B", "T", "q", "Q", "s", "S", "O", "N", "dD", "uD", "dD2", "tD", "qD", "Qd", "sD", "sD2", "eD", "nD", "vD", "cD"}
	local absValue = math.abs(value)
	local suffixIndex = 1

	while absValue >= 1000 and suffixIndex < #suffixes do
		absValue = absValue / 1000
		suffixIndex = suffixIndex + 1
	end

	local formattedValue
	if suffixIndex == 1 then
		formattedValue = string.format("%." .. (dp or 2) .. "f", math.round(value * 10^(dp or 2)) / 10^(dp or 2))
	else
		formattedValue = string.format("%.2f%s", absValue, suffixes[suffixIndex])
	end

	formattedValue = formattedValue:gsub("%.?0+$", "")

	if value < 0 then
		formattedValue = "-" .. formattedValue
	end

	return formattedValue
end


function format.Commas(val)
	local str = tostring(val):reverse()
	str = str:gsub("(%d%d%d)", "%1,")
	return str:reverse():gsub("^,", "")
end

function format.Round(val,dp)
	local mult = 10^(dp or 0)
	return math.round(val * mult) / mult
end

function format.len(tbl: {[any]: any}): number
	local count: number = 0

	for _, _ in tbl do
		count += 1
	end

	return count
end


return format
