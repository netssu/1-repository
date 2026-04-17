return {
	[1] = {
		QuestName = "Destroyer of Worlds",
		Type = "Kills",
		Amount = 300000,
		Icon = 'rbxassetid://139019506486716',
		Rewards = {

			[1] = {
				Type = 'Gems',
				Amount = 250
			},
			[2] = {
				Type = 'ClanXP',
				Amount = 2000,
			}

		}
	},
	[2] = {
		QuestName = "Grinder",
		Type = "Playtime",
		Amount = 60*10, -- Amount in minutes(so 10 hours here)
		Icon = 'rbxassetid://114784246822567',
		Rewards = {
			[1] = {
				Type = 'Gems',
				Amount = 250
			},
			[2] = {
				Type = 'ClanXP',
				Amount = 2000
			}
		}
	},
	[3] = {
		QuestName = "Boss Shredder",
		Type = "Kills:Bosses",
		Amount = math.round(math.random(1000, 1500)), -- Amount in minutes(so 10 hours here)
		Icon = 'rbxassetid://98834877724222',
		Rewards = {
			[1] = {
				Type = 'Gems',
				Amount = 200
			},
			[2] = {
				Type = 'ClanXP',
				Amount = 2000
			}
		}
	},
	[4] = {
		QuestName = "Timeless",
		Type = "Playtime",
		Amount = 60*24, -- Amount in minutes(so 10 hours here)
		Icon = 'rbxassetid://114784246822567',
		Rewards = {
			[1] = {
				Type = 'Gems',
				Amount = 500
			},
			[2] = {
				Type = 'ClanXP',
				Amount = 2000
			}
		}
	},
	[5] = {
		QuestName = "Boss Annihilator",
		Type = "Kills:Bosses",
		Amount = math.round(math.random(750, 1000)),
		Icon = 'rbxassetid://98834877724222',
		Rewards = {
			[1] = {
				Type = 'Gems',
				Amount = 350
			},
			[2] = {
				Type = 'ClanXP',
				Amount = 2000
			}
		}
	},
	[6] = {
		QuestName = "Destiny",
		Type = "Kills",
		Amount = 100000,
		Icon = 'rbxassetid://139019506486716',
		Rewards = {

			[1] = {
				Type = 'Gems',
				Amount = 250
			},
			[2] = {
				Type = 'ClanXP',
				Amount = 1250,
			}

		}
	},
}