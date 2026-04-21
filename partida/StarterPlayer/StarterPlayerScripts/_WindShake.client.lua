local WindShake = require(script.WindShake)
local WIND_DIRECTION = Vector3.new(1, 0, 0.3)
local WIND_SPEED = 20
local WIND_POWER = 0.3

WindShake:SetDefaultSettings({
	WindSpeed = WIND_SPEED,
	WindDirection = WIND_DIRECTION,
	WindPower = WIND_POWER,
})

WindShake:Init({
	MatchWorkspaceWind = false
})