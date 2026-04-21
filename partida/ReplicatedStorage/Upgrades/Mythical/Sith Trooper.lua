return {
	["Sith Trooper"] = {
		MaxUpgrades = 8,
		["Name"] = "Sith Trooper",
		["Rarity"] = "Mythical",
		["Place Limit"] = 3,
		['NotInBanner'] = true,
		["Upgrades"] = {

			{Damage = 140, Range = 20.0, Cooldown = 6.4, AOEType = "Splash", Price = 750, AOESize = 5.5, Type = "Ground", AttackName = "Rocket Shot", MultiDamageDelays = {1}, AnimName = "Rocket Shot"},
			{Damage = 274, Range = 21.43, Cooldown = 6.26, AOEType = "Splash", Price = 1046, AOESize = 5.5, Type = "Ground", AttackName = "Rocket Shot", MultiDamageDelays = {1}, AnimName = "Rocket Shot"},
			{Damage = 401, Range = 22.86, Cooldown = 6.11, AOEType = "Splash", Price = 1459, AOESize = 5.5, Type = "Ground", AttackName = "Rocket Shot", MultiDamageDelays = {1}, AnimName = "Rocket Shot"},
			{Damage = 522, Range = 24.29, Cooldown = 5.97, AOEType = "Splash", Price = 2035, AOESize = 5.5, Type = "Ground", AttackName = "Rocket Shot", MultiDamageDelays = {1}, AnimName = "Rocket Shot"},
			{Damage = 638, Range = 25.71, Cooldown = 5.83, AOEType = "Splash", Price = 2838, AOESize = 6.5, Type = "Ground", AttackName = "High Energy Shot", MultiDamageDelays = {1.3, 0.45, 0.3, 0.35}, AnimName = "Alpha Strike"},
			{Damage = 747, Range = 27.14, Cooldown = 5.69, AOEType = "Splash", Price = 3958, AOESize = 6.5, Type = "Ground", AttackName = "Alpha Strike", MultiDamageDelays = {0.9, 0.2, 0.2, 0.2, 0.2}, AnimName = "Alpha Strike"},
			{Damage = 848, Range = 28.57, Cooldown = 5.54, AOEType = "Splash", Price = 5521, AOESize = 6.5, Type = "Ground", AttackName = "Alpha Strike", MultiDamageDelays = {0.9, 0.2, 0.2, 0.2, 0.2}, AnimName = "Alpha Strike"},
			{Damage = 945, Range = 30.0, Cooldown = 5.4, AOEType = "Splash", Price = 7700, AOESize = 6.5, Type = "Ground", AttackName = "Alpha Strike", MultiDamageDelays = {0.9, 0.2, 0.2, 0.2, 0.2}, AnimName = "Alpha Strike"},
		},

		["Evolve"] = {
			["EvolutionRequirement"] = {
				["Killer Helmet"] = 1,
				["Milk"] = 20,
				["Yellow Milk"] = 15,
				["Blue Milk"] = 10,
				["Red Milk"] = 5,
			},
			["EvolvedUnit"] = "Sith Trooper (Bloodthirsty)",
			["EvolveBonus"] = "+25% Attack      +High Energy Shot",
		},
	},
}