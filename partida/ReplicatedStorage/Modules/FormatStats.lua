local module = {}

module.Format = function(value)
	local rounded

	if value > 100 then
		rounded = math.round(value) 
	else
		rounded = tonumber(string.format("%.1f", value)) 
	end

	return rounded
end

return module
