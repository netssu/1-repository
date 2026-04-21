return {
	["Fawn"] = {
		MaxUpgrades = 5,
		["Name"] = "Fawn",
		["Rarity"] = "Exclusive",
		["Place Limit"] = 1,
		NotInBanner = true,
		["Upgrades"] = { -- dont touch range
			{Damage = 100, Range = 5, SpawnedCooldown = 0.5, SpawnedRange = 5, Cooldown = 30, AOEType = "Splash", Price = 550, AOESize = 0, Type = "Spawner", SpawnedName = "FawnPlane1", AnimName = "Spawner"},
			{Damage = 250, Range = 5, SpawnedCooldown = 0.475, SpawnedRange = 7.5, Cooldown = 27, AOEType = "Splash", Price = 5000, AOESize = 0, Type = "Spawner", SpawnedName = "FawnPlane1", AnimName = "Spawner"},
			{Damage = 750, Range = 5, SpawnedCooldown = 0.45, SpawnedRange = 10, Cooldown = 25, AOEType = "Splash", Price = 8000, AOESize = 0, Type = "Spawner", SpawnedName = "FawnPlane1", AnimName = "Spawner"},
			{Damage = 1250, Range = 5, SpawnedCooldown = 0.425, SpawnedRange = 12.5, Cooldown = 22, AOEType = "Splash", Price = 15000, AOESize = 0, Type = "Spawner", SpawnedName = "FawnPlane1", AnimName = "Spawner"},
			{Damage = 2000, Range = 5, SpawnedCooldown = 0.4, SpawnedRange = 15, Cooldown = 20, AOEType = "Splash", Price = 25000, AOESize = 0, Type = "Spawner", SpawnedName = "FawnPlane1", AnimName = "Spawner",
				AbilityAttackRate = 0.05,
				AbilityDamage = 1000,
				AbilityCooldown = 120, -- in seconds
			},
		},
	},
}
