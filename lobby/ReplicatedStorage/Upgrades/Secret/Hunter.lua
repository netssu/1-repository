return {
	["Hunter"] = {
		MaxUpgrades = 9,
		["Name"] = "Hunter",
		["Rarity"] = "Secret",
		["Place Limit"] = 3,
		['NotInBanner'] = false,
		["Upgrades"] = {
			{Damage = 82,  Range = 19.2,Cooldown = 5,   AOEType = "Cone", Price = 700, AOESize = 6, Type = "Ground", AttackName = "Pistol",  MultiDamageDelays = {0.5,0.5,0.5,0.5},           AnimName = "Attack1"},
			{Damage = 133, Range = 20.3,Cooldown = 4,8, AOEType = "Cone", Price = 1335, AOESize = 7, Type = "Ground", AttackName = "Pistol",  MultiDamageDelays = {0.5,0.5,0.5,0.5},          AnimName = "Attack1"},
			{Damage = 168, Range = 21,Cooldown = 4.7, AOEType = "Cone", Price = 1980,AOESize = 7, Type = "Ground", AttackName = "Pistol",  MultiDamageDelays = {0.5,0.5,0.5,0.5},           AnimName = "Attack1"},
			{Damage = 254, Range = 21.8,Cooldown = 4.5, AOEType = "Cone", Price = 2450, AOESize = 8, Type = "Ground", AttackName = "Pistol", MultiDamageDelays = {0.5,0.5,0.5,0.5}, AnimName = "Attack1"},
			{Damage = 1001, Range = 23.55,Cooldown = 10,   AOEType = "Splash", Price = 3070, AOESize = 14, Type = "Ground", AttackName = "Electro Grenades", MultiDamageDelays = {0.63,0.63,0.63}, AnimName = "Attack2"},
			{Damage = 1203, Range = 25.3,Cooldown = 9.6,   AOEType = "Splash",    Price = 4325, AOESize = 14.25,   Type = "Ground", AttackName = "Electro Grenades", MultiDamageDelays = {0.63,0.63,0.63}, AnimName = "Attack2"},
			{Damage = 1449, Range = 27.5,Cooldown = 8.7, AOEType = "Splash",    Price = 5110, AOESize = 14.5,   Type = "Ground", AttackName = "Electro Grenades", MultiDamageDelays = {0.63,0.63,0.63}, AnimName = "Attack2"},
			{Damage = 1645, Range = 28.4,Cooldown = 8.2,AOEType = "Splash",    Price = 6470, AOESize = 14.75,   Type = "Ground", AttackName = "Electro Grenades", MultiDamageDelays = {0.63,0.63,0.63}, AnimName = "Attack2"},
			{Damage = 1889, Range = 29.85,Cooldown = 7.5,AOEType = "Splash",    Price = 7705, AOESize = 15,   Type = "Ground", AttackName = "Electro Grenades", MultiDamageDelays = {0.63,0.63,0.63}, AnimName = "Attack2"},
		},

		["Evolve"] = {
			["EvolutionRequirement"] = {
				["Orange Pistol"] = 1,
				["Milk"] = 50,
			},
			["EvolvedUnit"] = "Hunter (Ghost Wolf)",
			["EvolveBonus"] = "+30% Attack      +Vibro Knife Throw",
		},
	},
}
