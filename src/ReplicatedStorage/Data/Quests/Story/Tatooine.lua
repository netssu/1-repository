local module = {
	{
		QuestId = "tatooine_act1",
		QuestName = "Defeat Pilot", 
		QuestDescription = "", 
		QuestReward = {
			Gems = 50
		}, 
		QuestRequirement = {
			Type = "finish_level", 
			Level = 1, 
			World = 5,
			Amount = 1
		},
		IsUnique = true
	}, {
		QuestId = "tatooine_act2",
		QuestName = "Defeat Hyena Bomber", 
		QuestDescription = "", 
		QuestReward = {
			Gems = 50
		}, 
		QuestRequirement = {
			Type = "finish_level", 
			Level = 2, 
			World = 5,
			Amount = 1
		},
		IsUnique = true
	}, {
		QuestId = "tatooine_act3",
		QuestName = "Defeat General (Tatooine)", 
		QuestDescription = "", 
		QuestReward = {
			Gems = 50
		}, 
		QuestRequirement = {
			Type = "finish_level", 
			Level = 3, 
			World = 5,
			Amount = 1
		},
		IsUnique = true
	}, {
		QuestId = "tatooine_act4",
		QuestName = "Defeat Kit Fishto", 
		QuestDescription = "", 
		QuestReward = {
			Gems = 50
		}, 
		QuestRequirement = {
			Type = "finish_level", 
			Level = 4, 
			World = 5,
			Amount = 1
		},
		IsUnique = true
	}, {
		QuestId = "tatooine_act5",
		QuestName = "Defeat Kit Fishto (Supreme)", 
		QuestDescription = "", 
		QuestReward = {
			Gems = 100,
			TraitPoint = 1
		}, 
		QuestRequirement = {
			Type = "finish_level", 
			Level = 5, 
			World = 5,
			Amount = 1
		},
		IsUnique = true
	}
}

return module
