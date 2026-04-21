local module = {

	initial_money = 500,
	wave_rest_time = 5,
	ItemReward = "Blue Milk",
	EnemyStats = {
		normal = { 
			unit = "Soldier",
			health = 70, 
			speed = 2, 
			money_reward = 30
		}, 
		strong = {
			unit = "Stronger", 
			health = 80, 
			speed = 2, 
			money_reward = 40
		}, 
		tank = {
			unit = "Tank", 
			health = 90, 
			speed = 2, 
			money_reward = 50
		}, 
		quick = {
			unit = "BATTLEDROID B-1 QUICK", 
			health = 95, 
			speed = 4, 
			money_reward = 75
		},
		miniboss = {
			unit = "Tie Interceptor", 
			health = 140, 
			speed = 1.7, 
			money_reward = 150
		},

		boss1 = {
			unit = "Pilot", 
			health = 700, 
			speed = 2, 
			money_reward = 1500
		},
		boss2 = {
			unit = "Senior Pilot", 
			health = 900, 
			speed = 1.7, 
			money_reward = 1500
		},
		boss3 = {
			unit = "Shock Trooper", 
			health = 1000, 
			speed = 1.6, 
			money_reward = 1500
		},
		boss4 = {
			unit = "CosmoShip", 
			health = 1100, 
			speed = 1.9, 
			money_reward = 1500
		},
		boss5 = {
			unit = "Imperial Destroyer", 
			health = 1400, 
			speed = 1.4, 
			money_reward = 1500
		},

	},
	Rewards = {
		
	},
	Rounds = {
		

	}
}





return module
