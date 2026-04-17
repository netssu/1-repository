return {
	["2x XP"] = {
		Name = "2x XP",
		Rarity = "Epic",
		Description = "+2x XP for 1 hour",
		Itemtype = "Boost",
		--Itemtype = "Lucky_boost",
		--InMerchant = true,
		Buff = {
			Buff = "XP",
			StartTime = os.time(),
			Duration = 3600,
			Multiplier = 1,
			BuffType = "2x XP"
		},
		--Price = {
		--	Type = "Gems",
		--	Amount = 500
		--},
	} 
}