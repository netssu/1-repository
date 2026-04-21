return {
	["Lucky Crystal"] = {
		Name = "Lucky Crystal",
		Rarity = "Epic",
		Description = "+50% luck for 20 minutes",
		Itemtype = "Boost",
		InMerchant = false,
		Buff = {Buff = "Luck",
			StartTime = os.time()
			,Duration = 1200,
			Multiplier=1.5,
			BuffType="LuckyCrystal"
		},
		Price = {
			Type = "Coins",
			Amount = 20000
		},
	} 
}