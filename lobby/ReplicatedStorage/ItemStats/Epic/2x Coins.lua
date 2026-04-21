return {
	["2x Coins"] = {
		Name = "2x Coins",
		Rarity = "Epic",
		Description = "+2x Coins for 1 hour",
		Itemtype = "Boost",
		--Itemtype = "Lucky_boost",
		--InMerchant = true,
		Buff = {
			Buff = "Coins",
			StartTime = os.time(),
			Duration = 3600,
			Multiplier = 2,
			BuffType = "2x Coins"
		},
		--Price = {
		--	Type = "Gems",
		--	Amount = 500
		--},
	} 
}