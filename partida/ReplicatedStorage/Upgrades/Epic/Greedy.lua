local burst = {0.5,0.5,0.5,0.5}

return {
	["Greedy"] = {
		MaxUpgrades = 5,
		["Name"] = "Greedy",
		["NotInBanner"] = false,
		["Rarity"] = "Epic",
		["Place Limit"] = 4,
		["Upgrades"] = {
			{Damage = 30, Range = 18.0, Cooldown = 5.0, AOEType = "Cone", Price = 180, AOESize = 4, Type = "Ground", AttackName = "Burst Fire", MultiDamageDelays = burst, AnimName = "Burst Fire"},
			{Damage = 56, Range = 19.25, Cooldown = 4.7, AOEType = "Cone", Price = 257, AOESize = 4, Type = "Ground", AttackName = "Burst Fire", MultiDamageDelays = burst, AnimName = "Burst Fire"},
			{Damage = 79, Range = 20.5, Cooldown = 4.4, AOEType = "Cone", Price = 367, AOESize = 4, Type = "Ground", AttackName = "Burst Fire", MultiDamageDelays = burst, AnimName = "Burst Fire"},
			{Damage = 98, Range = 21.75, Cooldown = 4.1, AOEType = "Cone", Price = 525, AOESize = 4.5, Type = "Ground", AttackName = "Burst Fire", MultiDamageDelays = burst, AnimName = "Burst Fire"},
			{Damage = 114, Range = 35.0, Cooldown = 3.8, AOEType = "Cone", Price = 750, AOESize = 6, Type = "Ground", AttackName = "Burst Fire", MultiDamageDelays = burst, AnimName = "Burst Fire"},
		}
	},
}