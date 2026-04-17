local module = {
	{
		QuestId = "kashyyyk_planet_act1",
		QuestName = "Defeat Pilot", 
		QuestDescription = "", 
		QuestReward = {
			Gems = 50
		}, 
		QuestRequirement = {
			Type = "finish_level", 
			Level = 1, 
			World = 3,
			Amount = 1
		},
		IsUnique = true
	}, {
		QuestId = "kashyyyk_planet_act2",
		QuestName = "Defeat Senior Pilot", 
		QuestDescription = "", 
		QuestReward = {
			Gems = 50
		}, 
		QuestRequirement = {
			Type = "finish_level", 
			Level = 2, 
			World = 3,
			Amount = 1
		},
		IsUnique = true
	}, {
		QuestId = "kashyyyk_planet_act3",
		QuestName = "Defeat Shock Trooper", 
		QuestDescription = "", 
		QuestReward = {
			Gems = 50
		}, 
		QuestRequirement = {
			Type = "finish_level", 
			Level = 3, 
			World = 3,
			Amount = 1
		},
		IsUnique = true
	}, {
		QuestId = "kashyyyk_planet_act4",
		QuestName = "Defeat CosmoShip", 
		QuestDescription = "", 
		QuestReward = {
			Gems = 50
		}, 
		QuestRequirement = {
			Type = "finish_level", 
			Level = 4, 
			World = 3,
			Amount = 1
		},
		IsUnique = true
	}, {
		QuestId = "kashyyyk_planet_act5",
		QuestName = "Defeat Imiperial Destroyer", 
		QuestDescription = "", 
		QuestReward = {
			Gems = 100,
			TraitPoint = 1
		}, 
		QuestRequirement = {
			Type = "finish_level", 
			Level = 5, 
			World = 3,
			Amount = 1
		},
		IsUnique = true
	}
}

return module
