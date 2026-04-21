return {
	["Fortunate Crystal"] = {
		Name = "Fortunate Crystal",
		Rarity = "Legendary",
		Description = "+100% luck for 20 minutes",
		Itemtype = "Boost",
		InMerchant = false,
		Buff = {Buff = "Luck",
			StartTime = os.time(),
			Duration = 1200,
			Multiplier=2,
			BuffType="FortunateCrystal"
		},
		Price = {
			Type = "Coins",
			Amount = 30000
		}
	}
}