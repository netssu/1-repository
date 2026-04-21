local module = {

	initial_money = 500,
	wave_rest_time = 5,
	ItemReward = "Red Milk",
	EnemyStats = {
		normal = { 
			unit = "Soldier",
			health = 100, 
			speed = 2, 
			money_reward = 30
		}, 
		strong = {
			unit = "Stronger", 
			health = 110, 
			speed = 2, 
			money_reward = 40
		}, 
		tank = {
			unit = "Tank", 
			health = 120, 
			speed = 2, 
			money_reward = 50
		}, 
		quick = {
			unit = "BATTLEDROID B-1 QUICK", 
			health = 110, 
			speed = 4, 
			money_reward = 75
		},
		miniboss = {
			unit = "Tie Interceptor", 
			health = 180, 
			speed = 1.7, 
			money_reward = 150
		},

		boss1 = {
			unit = "Dart Mayl", 
			health = 700, 
			speed = 2, 
			money_reward = 1500
		},
		boss2 = {
			unit = "Anikan Skaivoker", 
			health = 900, 
			speed = 1.7, 
			money_reward = 1500
		},
		boss3 = {
			unit = "Mayl Phantom Rage", 
			health = 1000, 
			speed = 1.6, 
			money_reward = 1500
		},
		boss4 = {
			unit = "Dark Overlord", 
			health = 1100, 
			speed = 1.9, 
			money_reward = 1500
		},
		boss5 = {
			unit = "Wader Last Breath", 
			health = 1400, 
			speed = 1.4, 
			money_reward = 1500
		},

	},
	Rewards = {
		Tower = { unit = "Hunter", chance = 0.1 } -- 0.5%
	},
	Rounds = {
		

	}
}





return module
