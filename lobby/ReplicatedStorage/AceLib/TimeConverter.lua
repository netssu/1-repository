local TimeConversion = {}

function TimeConversion.secondsToTime(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remainingSeconds = seconds % 60

	local formattedTime = string.format("%02d:%02d", minutes, remainingSeconds)

	if hours > 0 then
		formattedTime = string.format("%d:%s", hours, formattedTime)
	end

	return formattedTime
end

return TimeConversion
