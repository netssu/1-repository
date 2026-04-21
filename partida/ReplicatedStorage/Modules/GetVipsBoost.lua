

return function(Player)
	local totalMultiplier = 1
	
	if Player.OwnGamePasses.VIP.Value then
		totalMultiplier = 1.1
	elseif Player.OwnGamePasses["Ultra VIP"].Value then
		totalMultiplier = 1.15
	end  
	
	return totalMultiplier
end
