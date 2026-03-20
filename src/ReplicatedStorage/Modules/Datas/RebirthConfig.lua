------------------//VARIABLES
local RebirthConfig = {}

------------------//CONSTANTS
RebirthConfig.BASE_COINS_REQ = 5000
RebirthConfig.COIN_SCALING = 1.8
RebirthConfig.TOKENS_PER_REBIRTH = 1
RebirthConfig.POWER_RESET_VALUE = 120

------------------//FUNCTIONS
function RebirthConfig.GetRequirement(currentRebirths: number)
	local rawCoins = RebirthConfig.BASE_COINS_REQ * (RebirthConfig.COIN_SCALING ^ currentRebirths)

	local coinsReq = math.round(rawCoins / 5000) * 5000

	if coinsReq < RebirthConfig.BASE_COINS_REQ then
		coinsReq = RebirthConfig.BASE_COINS_REQ
	end

	return coinsReq, 0
end

return RebirthConfig
