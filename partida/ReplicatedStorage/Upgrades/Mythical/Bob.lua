return {
	["Bob"] = {
		MaxUpgrades = 6,
		["Name"] = "Bob",
		["Rarity"] = "Mythical",
		["NotInBanner"] = true,
		["Hybrid"] = true,
		["Place Limit"] = 3,
		["Upgrades"] = {

			{Damage = 82, Range = 20, Cooldown = 6, AOEType = "Cone", Price = 780, AOESize = 12,Type = "Hybrid",AttackName = "Hip Shot",MultiDamageDelays = {.75},AnimName = "Hip Shot"},
			{Damage = 150, Range = 21.4, Cooldown = 5.8, AOEType = "Cone", Price = 1365, AOESize = 12,Type = "Hybrid",AttackName = "Hip Shot",MultiDamageDelays = {.75},AnimName = "Hip Shot"},
			{Damage = 203, Range = 22.8, Cooldown = 5.6, AOEType = "Splash", Price = 2150, AOESize = 12,Type = "Hybrid",AttackName = "Rocket Shot",MultiDamageDelays = {1},AnimName = "Rocket Shot"},
			{Damage = 312, Range = 24.5, Cooldown = 5.5, AOEType = "Splash", Price = 2985, AOESize = 5.6,Type = "Hybrid",AttackName = "Rocket Shot",MultiDamageDelays = {1},AnimName = "Rocket Shot"},
			{Damage = 454, Range = 25.2, Cooldown = 6, AOEType = "Splash", Price = 3770, AOESize = 5.6,Type = "Hybrid",AttackName = "Rocket Barrage",MultiDamageDelays = {1, 1, 1},AnimName = "Rocket Barrage"},
			{Damage = 695, Range = 26.9, Cooldown = 5.8, AOEType = "Splash", Price = 5155, AOESize = 5.6,Type = "Hybrid",AttackName = "Rocket Barrage",MultiDamageDelays = {1, 1, 1},AnimName = "Rocket Barrage"},
		},

		["Evolve"] = {
			["EvolutionRequirement"] = {
				["Blue Pistol"] = 1,
				["Red Pistol"] = 1,
				["Milk"] = 25,
			},
			["EvolvedUnit"] = "Bob (Omega)",
			["EvolveBonus"] = "+20% Attack",
		},
	},
}