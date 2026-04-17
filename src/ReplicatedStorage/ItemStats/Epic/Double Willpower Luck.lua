return {
	["Double Willpower Luck"] = {
		Name = "Double Willpower Luck",
		Rarity = "Epic",
		Description = "+50% willpower luck for 20 minutes",
		Itemtype = "Boost",
		InMerchant = false,
		Buff = {Buff = "Luck",
			StartTime = os.time()
			,Duration = 1200,
			Multiplier= 2,
			BuffType="WillpowerLuckyCrystal"
		},
		Price = {
			Type = "Coins",
			Amount = 20000
		},
	} 
}