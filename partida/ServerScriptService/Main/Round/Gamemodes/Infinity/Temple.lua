local module = {

	initial_money = 500,
	wave_rest_time = 5,
	ItemReward = "Youngling Sauce",
	EnemyStats = {
		normal = { 
			unit = "Bobby",
			health = 115, 
			speed = 4, 
			money_reward = 30
		}, 
		strong = {
			unit = "BigRickDandy", 
			health = 145, 
			speed = 3, 
			money_reward = 40
		}, 
		tank = {
			unit = "Croozie", 
			health = 155, 
			speed = 3.5, 
			money_reward = 50
		}, 
		quick = {
			unit = "Bite-Size Binks", 
			health = 105, 
			speed = 6, 
			money_reward = 75
		},
		miniboss = {
			unit = "Fauzen", 
			health = 305, 
			speed = 2.5, 
			money_reward = 150
		},

		boss1 = {
			unit = "Tosuoii", 
			health = 800, 
			speed = 2, 
			money_reward = 1500
		},
		boss2 = {
			unit = "Ace", 
			health = 775, 
			speed = 2.3, 
			money_reward = 1500
		},
		boss3 = {
			unit = "Scruffy", 
			health = 725, 
			speed = 2.5, 
			money_reward = 1500
		},
		boss4 = {
			unit = "Yassin", 
			health = 700, 
			speed = 2.7, 
			money_reward = 1500
		},
		boss5 = {
			unit = "Jack the worst community manager in the world", 
			health = 650, 
			speed = 3, 
			money_reward = 1500
		},

	},
	
	Rewards = {
		--Tower = {unit = "Anikin Armor", chance = 0.001},
	},

	Rounds = {
	}
}





return module