return {
	["2x Gems"] = {
		Name = "2x Gems",
		Rarity = "Epic",
		Description = "+2x Gems for 1 hour",
		Itemtype = "Boost",
		--Itemtype = "Lucky_boost",
		--InMerchant = true,
		Buff = {
			Buff = "Gems",
			StartTime = os.time(),
			Duration = 3600,
			Multiplier = 1,
			BuffType="2x Gems"
		},
		--Price = {
		--	Type = "Gems",
		--	Amount = 500
		--},
	} 
}