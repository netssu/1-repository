return {
	Theme = {
		ThemeId = "temple_world_clear",
		ThemeImage = "rbxassetid://113741794143567",
		ThemeName = "Temple",
		LayoutOrder = 8
	},
	Achievements = {
		{
			AchievementId = "temple_world_clear_0",
			AchievementName = "Master Of The Temple",
			AchievementDescription = "Complete all acts of Temple on hard mode",
			AchievementReward = {
				Gems = 8000,
				TraitPoint = 26
			},
			AchievementRequirement = {
				Type = "achievement_completed",
				ThemeId = "temple_world_clear",
				amount = 5
			},
			Final = true
		},{
			AchievementId = "temple_world_clear_act_1",
			AchievementName = "Enter the temple",
			AchievementDescription = "Clear act 1 of Temple on hard mode", 
			AchievementReward = {
				TraitPoint = 16
			}, 
			AchievementRequirement = {
				Type = "finish_level",
				World = 8,
				Level = 1,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "temple_world_clear_act_2",
			AchievementName = "Ashes Of The Temple",
			AchievementDescription = "Clear act 2 of Temple on hard mode", 
			AchievementReward = {
				TraitPoint = 16
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 8,
				Level = 2,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "temple_world_clear_act_3",
			AchievementName = "Rage From The Temple",
			AchievementDescription = "Clear act 3 of Temple on hard mode", 
			AchievementReward = {
				TraitPoint = 16
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 8,
				Level = 3,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "temple_world_clear_act_4",
			AchievementName = "Echoes of the Dark Side",
			AchievementDescription = "Clear act 4 of Temple on hard mode", 
			AchievementReward = {
				TraitPoint = 16
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 8,
				Level = 4,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "temple_world_clear_act_5",
			AchievementName = "The Final Warrior",
			AchievementDescription = "Clear act 5 of Temple on hard mode", 
			AchievementReward = {
				TraitPoint = 16
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 8,
				Level = 5,
				Mode = 2,
				Amount = 1
			}
		}
	}
}
