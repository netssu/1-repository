local WeatherControl = {}

local forcedRainUntil = 0
local MIN_FORCE_DURATION = 10
local DEFAULT_FORCE_DURATION = 300

function WeatherControl.force_rain_for(seconds: number?)
	local duration = tonumber(seconds) or DEFAULT_FORCE_DURATION
	duration = math.max(MIN_FORCE_DURATION, math.floor(duration))
	forcedRainUntil = os.time() + duration
	return forcedRainUntil
end

function WeatherControl.is_forced_active(now: number): boolean
	return now < forcedRainUntil
end

function WeatherControl.get_forced_until(): number
	return forcedRainUntil
end

return WeatherControl
