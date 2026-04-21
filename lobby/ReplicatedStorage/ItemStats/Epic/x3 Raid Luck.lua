return {
	["x3 Raid Luck"] = {
		Name = "x3 Raid Luck",
		Rarity = "Epic",
		Description = "+x3 Raid Luck for 20 minutes",
		Itemtype = "Boost",
		InMerchant = false,
		Buff = {Buff = "Luck",
			StartTime = os.time()
			,Duration = 1200,
			Multiplier=1.5,
			BuffType="RaidLuck3x"
		},
		Price = {
			Type = "Coins",
			Amount = 20000
		},
	} 
}