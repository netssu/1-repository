return function(Player, Buff : "Luck" | "Coins" | "XP" | "Gems")
	local totalMultiplier = 1

	if Player.OwnGamePasses['x2 Gems'].Value and Buff == 'Gems' then totalMultiplier += 1 end
	if Player.OwnGamePasses["2x Player XP"].Value and Buff == 'XP' then totalMultiplier += 1 end
	if Player.OwnGamePasses['Ultra VIP'].Value and Buff == 'XP' then totalMultiplier += 0.15 end

	if Buff == 'XP' then
		local Prestige = Player.Prestige
		totalMultiplier += (Prestige.Value * 10)/100
	end
	for _, buffFolder in Player.Buffs:GetChildren() do
		if buffFolder.Buff.Value ~= Buff then continue end
		totalMultiplier += buffFolder.Multiplier.Value
	end
	return totalMultiplier
end