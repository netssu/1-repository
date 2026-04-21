local module = {
	{
		QuestId = "event_naboo_planet_act5",
		QuestName = "Defeat the Chanceller", 
		QuestDescription = "", 
		QuestReward = {
			Badge = 1825567174069736
		}, 
		QuestRequirement = {
			Type = "finish_level", 
			World = 1,
			Level = 5,
			Amount = 1
		},
		ExpireTime = 1744782587,
		IsUnique = true
	},
	--4403924743658221
	{
		QuestId = "event_easter_reach_wave",
		QuestName = "They Kept Coming…", 
		QuestDescription = "Clear 50 waves in Easter Event", 
		QuestReward = {
			Badge = 778268411443411
		}, 
		QuestRequirement = {
			Type = "clear_waves", 
			World = 5,
			Amount = 50
		},
		ExpireTime = 1745640000,
		IsUnique = true
	},
	{
		QuestId = "event_easter_summon",
		QuestName = "Legendary Awakening", 
		QuestDescription = "Summon 1 legendary units", 
		QuestReward = {
			Badge = 778268411443411
		}, 
		QuestRequirement = {
			Type = "summon_rarity_unit", 
			Rarity = "Legendary",
			Amount = 1
		},
		ExpireTime = 1745640000,
		IsUnique = true
	},
	{
		QuestId = "event_free_easter",
		QuestName = "Easter Event", 
		QuestDescription = "Here is a small gift to help with the event", 
		QuestReward = {
			Eggs = 100
		}, 
		QuestRequirement = {
			Type = "free", 

		},
		ExpireTime = 1745640000,
		IsUnique = true
	}

}

return module
