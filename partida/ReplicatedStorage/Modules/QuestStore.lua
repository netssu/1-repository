local QuestStore = {
	

	Daily = {
		Summon = {
			{
				["Title"] = "Summoning I",
				["Desc"] = "Summon 10 Units",
				["Reward"] = {
					Gems = 150,
					Coins = 0,
					TraitPoint = 0,
				},
				["Progress"] = 10,
			},
			{
				["Title"] = "Summoning II",
				["Desc"] = "Summon 25 Units",
				["Reward"] = {
					Gems = 200,
					Coins = 0,
					TraitPoint = 0,
				},
				["Progress"] = 25,
			},
			{
				["Title"] = "Summoning III",
				["Desc"] = "Summon 50 Units",
				["Reward"] = {
					Gems = 400,
					Coins = 0,
					TraitPoint = 0,
				},
				["Progress"] = 50,
			},
		},
		
		Multiplayer = {
			{
				["Title"] = "Multiplayer I",
				["Desc"] = "Clear 30 waves with at least one other player",
				["Reward"] = {
					Gems = 100,
					Coins = 0,
					TraitPoint = 0,
				},
				["Progress"] = 30,
			},
			{
				["Title"] = "Multiplayer II",
				["Desc"] = "Clear 50 waves with at least one other player",
				["Reward"] = {
					Gems = 160,
					Coins = 0,
					TraitPoint = 0,
				},
				["Progress"] = 50,
			},
			{
				["Title"] = "Multiplayer III",
				["Desc"] = "Clear 75 waves with at least one other player",
				["Reward"] = {
					Gems = 230,
					Coins = 0,
					TraitPoint = 0,
				},
				["Progress"] = 75,
			},
		},
	},

	Weekly = {
		InfiniteWaves = {
			{
				["Title"] = "Reach Waves",
				["Desc"] = "Reach wave 50 in infinity",
				["Reward"] = {
					Gems = 0,
					Coins = 0,
					TraitPoint = 0,
				},
				["Progress"] = 50,
			},
		},
	},
}

return QuestStore
