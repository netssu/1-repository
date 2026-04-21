return {
	["2x Raid Luck"] = {
		Name = "2x Raid Luck",
		Rarity = "Epic",
		Description = "+50% Raid Luck for 20 minutes",
		Itemtype = "Boost",
		InMerchant = false,
		Buff = {Buff = "Luck",
			StartTime = os.time()
			,Duration = 1200,
			Multiplier=1.5,
			BuffType="RaidLuck2x"
		},
		Price = {
			Type = "Coins",
			Amount = 20000
		},
	} 
}