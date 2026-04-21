local module = {}

module.towerExpCalculation = function(towerlevel)	-- this return the exp require to level up from lvl 1 to tower level
	return math.round((towerlevel*10)^1.1)
end

module.towerLevelCalculation = function(currentLevel,towerExp)
	local level = currentLevel
	local exp = towerExp

	while module.towerExpCalculation(level) <= exp do
		exp = exp - module.towerExpCalculation(level)
		level += 1
	end

	return level, exp
end


module.playerExpCalculation = function(playerlevel)
	return math.floor(100 + 7 * (playerlevel - 1))
end
module.playerLevelCalculation = function(player, currentLevel,playerExp)
	local level = currentLevel
	local exp = playerExp
	print(exp)
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
	return 50,module.towerExpCalculation(50)
end

return module
