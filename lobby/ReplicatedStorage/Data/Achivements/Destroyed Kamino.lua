return {
	Theme = {
		ThemeId = "destroyed_kamino_world_clear",
		ThemeImage = "rbxassetid://134785018786874",
		ThemeName = "Destroyed Kamino",
		LayoutOrder = 7
	},
	Achievements = {
		{
			AchievementId = "destroyed_kamino_world_clear_0",
			AchievementName = "Master of the Storm",
			AchievementDescription = "Complete all acts of Destroyed Kamino on hard mode",
			AchievementReward = {
				Gems = 7000,
				TraitPoint = 24
			},
			AchievementRequirement = {
				Type = "achievement_completed",
				ThemeId = "destroyed_kamino_world_clear",
				amount = 5
			},
			Final = true
		},{
			AchievementId = "destroyed_kamino_world_clear_act_1",
			AchievementName = "Tempest Rising",
			AchievementDescription = "Clear act 1 of Destroyed Kamino on hard mode", 
			AchievementReward = {
				TraitPoint = 14
			}, 
			AchievementRequirement = {
				Type = "finish_level",
				World = 7,
				Level = 1,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "destroyed_kamino_world_clear_act_2",
			AchievementName = "Ashes of the Clones",
			AchievementDescription = "Clear act 2 of Destroyed Kamino on hard mode", 
			AchievementReward = {
				TraitPoint = 14
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 7,
				Level = 2,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "destroyed_kamino_world_clear_act_3",
			AchievementName = "Wrath from the Deep",
			AchievementDescription = "Clear act 3 of Destroyed Kamino on hard mode", 
			AchievementReward = {
				TraitPoint = 14
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 7,
				Level = 3,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "destroyed_kamino_world_clear_act_4",
			AchievementName = "Echoes of the Dark Side",
			AchievementDescription = "Clear act 4 of Destroyed Kamino on hard mode", 
			AchievementReward = {
				TraitPoint = 14
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 7,
				Level = 4,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "destroyed_kamino_world_clear_act_5",
			AchievementName = "The Final Purge",
			AchievementDescription = "Clear act 5 of Destroyed Kamino on hard mode", 
			AchievementReward = {
				TraitPoint = 14
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 7,
				Level = 5,
				Mode = 2,
				Amount = 1
			}
		}
	}
}
