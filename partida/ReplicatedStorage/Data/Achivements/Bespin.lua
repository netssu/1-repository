return {
	Theme = {
		ThemeId = "bespin_world_clear",
		ThemeImage = "rbxassetid://88974324482612",  
		ThemeName = "Bespin",
		LayoutOrder = 10
	},
	Achievements = {
		{
			AchievementId = "bespin_world_clear_0",
			AchievementName = "Master Of The Gas Giant",
			AchievementDescription = "Complete all acts of Bespin on hard mode",
			AchievementReward = {
				Gems = 10000,
				TraitPoint = 30
			},
			AchievementRequirement = {
				Type = "achievement_completed",
				ThemeId = "bespin_world_clear",
				amount = 5
			},
			Final = true
		},{
			AchievementId = "bespin_world_clear_act_1",
			AchievementName = "Cloud City Arrival",
			AchievementDescription = "Clear act 1 of Bespin on hard mode", 
			AchievementReward = {
				TraitPoint = 20
			}, 
			AchievementRequirement = {
				Type = "finish_level",
				World = 10,
				Level = 1,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "bespin_world_clear_act_2",
			AchievementName = "Sabotage on the Platform",
			AchievementDescription = "Clear act 2 of Bespin on hard mode", 
			AchievementReward = {
				TraitPoint = 20
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 10,
				Level = 2,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "bespin_world_clear_act_3",
			AchievementName = "Betrayal in the Mines",
			AchievementDescription = "Clear act 3 of Bespin on hard mode", 
			AchievementReward = {
				TraitPoint = 20
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 10,
				Level = 3,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "bespin_world_clear_act_4",
			AchievementName = "Echoes in the Cloud",
			AchievementDescription = "Clear act 4 of Bespin on hard mode", 
			AchievementReward = {
				TraitPoint = 20
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 10,
				Level = 4,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "bespin_world_clear_act_5",
			AchievementName = "Final Stand at the Edge",
			AchievementDescription = "Clear act 5 of Bespin on hard mode", 
			AchievementReward = {
				TraitPoint = 20
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 10,
				Level = 5,
				Mode = 2,
				Amount = 1
			}
		}
	}
}
