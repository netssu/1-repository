local GetPlayerBoost = require(game.ReplicatedStorage.Modules.GetPlayerBoost)

local module = {}

module.towerExpCalculation = function(towerlevel)
	return math.round((towerlevel*10)^1.1)
end

module.towerLevelCalculation = function(player, currentLevel, towerExp)
	local level = currentLevel
	local exp = towerExp

	if player.OwnGamePasses["Ultra VIP"].Value then
		exp += towerExp * 0.15
	elseif player.OwnGamePasses.VIP.Value then
		exp += towerExp * 0.1
	end

	while module.towerExpCalculation(level) <= exp do
		exp = exp - module.towerExpCalculation(level)
		level += 1
	end

	local maxLevel, maxExp = module.getTowerMaxStats()
	if level >= maxLevel then
		if level > maxLevel then
			exp = maxExp
		end
		level = maxLevel
	end

	return level, math.floor(exp)
end



module.playerExpCalculation = function(playerlevel)
	return math.floor(100 + 7 * (playerlevel - 1))
end
module.playerLevelCalculation = function(player, currentLevel,playerExp)
	local level = currentLevel
	local exp = playerExp
	
	--if player.OwnGamePasses["2x Player XP"].Value == true then
	--	exp += exp
	--end
	
	
	while module.playerExpCalculation(level) <= exp do
		exp = exp - module.playerExpCalculation(level)
		level += 1
	end

	return level, exp
end


module.getTowerMaxStats = function()
	return 100,module.towerExpCalculation(100)
end

return module
