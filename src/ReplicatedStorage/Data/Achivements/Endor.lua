return {
	Theme = {
		ThemeId = "endor_world_clear",
		ThemeImage = "rbxassetid://99657084528550",  
		ThemeName = "Endor",
		LayoutOrder = 11
	},
	Achievements = {
		{
			AchievementId = "endor_world_clear_0",
			AchievementName = "Master Of The Forest Moon",
			AchievementDescription = "Complete all acts of Endor on hard mode",
			AchievementReward = {
				Gems = 11000,        -- increased from 7000
				TraitPoint = 32     -- increased from 35
			},
			AchievementRequirement = {
				Type = "achievement_completed",
				ThemeId = "endor_world_clear",
				amount = 5
			},
			Final = true
		},{
			AchievementId = "endor_world_clear_act_1",
			AchievementName = "Landing on Endor",
			AchievementDescription = "Clear act 1 of Endor on hard mode", 
			AchievementReward = {
				TraitPoint = 22    -- increased from 16
			}, 
			AchievementRequirement = {
				Type = "finish_level",
				World = 11,
				Level = 1,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "endor_world_clear_act_2",
			AchievementName = "Forest Ambush",
			AchievementDescription = "Clear act 2 of Endor on hard mode", 
			AchievementReward = {
				TraitPoint = 22
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 11,
				Level = 2,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "endor_world_clear_act_3",
			AchievementName = "Strike the Shield Generator",
			AchievementDescription = "Clear act 3 of Endor on hard mode", 
			AchievementReward = {
				TraitPoint = 22
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 11,
				Level = 3,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "endor_world_clear_act_4",
			AchievementName = "Echoes in the Trees",
			AchievementDescription = "Clear act 4 of Endor on hard mode", 
			AchievementReward = {
				TraitPoint = 22
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 11,
				Level = 4,
				Mode = 2,
				Amount = 1
			}
		}, {
			AchievementId = "endor_world_clear_act_5",
			AchievementName = "Final Stand at the Forest Edge",
			AchievementDescription = "Clear act 5 of Endor on hard mode", 
			AchievementReward = {
				TraitPoint = 22
			}, 
			AchievementRequirement = {
				Type = "finish_level", 
				World = 11,
				Level = 5,
				Mode = 2,
				Amount = 1
			}
		}
	}
}
