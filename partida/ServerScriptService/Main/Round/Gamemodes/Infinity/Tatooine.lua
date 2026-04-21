local module = {

	initial_money = 500,
	wave_rest_time = 5,
	ItemReward = "Red Milk",
	EnemyStats = {
		normal = { 
			unit = "BATTLEDROID B-1",
			health = 135, 
			speed = 2, 
			money_reward = 30
		}, 
		strong = {
			unit = "BATTLEDROID B-1 STRONG", 
			health = 145, 
			speed = 2, 
			money_reward = 40
		}, 
		tank = {
			unit = "B2", 
			health = 155, 
			speed = 2, 
			money_reward = 50
		}, 
		quick = {
			unit = "BATTLEDROID B-1 QUICK", 
			health = 145, 
			speed = 4, 
			money_reward = 75
		},
		miniboss = {
			unit = "B1 SHADOW DROID",
			health = 225, 
			speed = 1.7, 
			money_reward = 150
		},

		boss1 = {
			unit = "Bulwark Battlecruiser Mk.3", 
			health = 1450, 
			speed = 1.7, 
			money_reward = 1500
		},
		boss2 = {
			unit = "Hyena Bomber", 
			health = 1050, 
			speed = 2.5, 
			money_reward = 1500
		},
		boss3 = {
			unit = "General", 
			health = 1275, 
			speed = 2, 
			money_reward = 1500
		},


	},
	Rewards = {

	},
	Rounds = {


	}
}

return module