return {
	Theme = {
		ThemeId = "hoff_world_clear",
		ThemeImage = "rbxassetid://79920000701742",
		ThemeName = "Hoff",
		LayoutOrder = 9
	},
	Achievements = {
		{
			AchievementId = "hoff_world_clear_0",
			AchievementName = "Master Of The Hoff",
			AchievementDescription = "Complete all acts of Hoff on hard mode",
			AchievementReward = {
				Gems = 9000,
				TraitPoint = 28
			},
			AchievementRequirement = {
				Type = "achievement_completed",
				ThemeId = "hoff_world_clear",
				amount = 5
			},
			Final = true
		},{
			AchievementId = "hoff_world_clear_act_1",
			AchievementName = "Enter the Hoff",
			AchievementDescription = "Clear act 1 of Hoff on hard mode", 
			AchievementReward = {
				TraitPoint = 18
			}, 
			AchievementRequirement = {
				Type = "finish_level",
				World = 9,
				Level = 1,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "hoff_world_clear_act_2",
			AchievementName = "Ashes Of The Hoff",
			AchievementDescription = "Clear act 2 of Hoff on hard mode", 
			AchievementReward = {
				TraitPoint = 18
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 9,
				Level = 2,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "hoff_world_clear_act_3",
			AchievementName = "Rage From The Hoff",
			AchievementDescription = "Clear act 3 of Hoff on hard mode", 
			AchievementReward = {
				TraitPoint = 18
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 9,
				Level = 3,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "hoff_world_clear_act_4",
			AchievementName = "Echoes of the Dark Side",
			AchievementDescription = "Clear act 4 of Hoff on hard mode", 
			AchievementReward = {
				TraitPoint = 18
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 9,
				Level = 4,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "hoff_world_clear_act_5",
			AchievementName = "The Final Warrior",
			AchievementDescription = "Clear act 5 of Hoff on hard mode", 
			AchievementReward = {
				TraitPoint = 18
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 9,
				Level = 5,
				Mode = 2,
				Amount = 1
			}
		}
	}
}
