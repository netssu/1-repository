return {
	["Junk Offering"] = {
		Name = "Junk Offering",
		Rarity = "Legendary",
		Description = "+100% Junk luck for 20 minutes",
		Itemtype = "Boost",
		InMerchant = true,
		Buff = {Buff = "Luck",
			StartTime = os.time(),
			Duration = 1200,
			Multiplier=2,
			BuffType="Junk Offering"
		},
		Price = {
			Type = "Coins",
			Amount = 35000
		}
	}
}