local module = {}

function module.truncateToCharacterLength(str, maxLength)
	if #str <= maxLength then
		return str
	end
	return string.sub(str, 1, maxLength)
end

function module.stringToNumbers(str)
	return string.gsub(str, "[^%d]", "")
end

function module.cleanString(str, dontRemoveSpaces)
	if dontRemoveSpaces then
		return string.gsub(str, "[^%w%s]", "")
	else
		return string.gsub(str, "[^%w]", "")
	end
end

return module