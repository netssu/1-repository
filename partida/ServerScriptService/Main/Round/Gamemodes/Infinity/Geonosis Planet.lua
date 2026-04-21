local module = {
	initial_money = 500,
	wave_rest_time = 5,
	ItemReward = "Yellow Milk",
	EnemyStats = {
		normal = { 
			unit = "Soldier",
			health = 45, 
			speed = 2, 
			money_reward = 30
		}, 
		strong = {
			unit = "Stronger", 
			health = 55, 
			speed = 2, 
			money_reward = 40
		}, 
		tank = {
			unit = "Tank", 
			health = 65, 
			speed = 2, 
			money_reward = 50
		}, 
		quick = {
			unit = "BATTLEDROID B-1 QUICK", 
			health = 55, 
			speed = 4, 
			money_reward = 75
		},
		miniboss = {
			unit = "Tie Interceptor", 
			health = 115, 
			speed = 1.7, 
			money_reward = 150
		},
	
		boss1 = {
			unit = "General", 
			health = 600, 
			speed = 1.7, 
			money_reward = 1500
		},
		boss2 = {
			unit = "Senior Commandor", 
			health = 750, 
			speed = 1.5, 
			money_reward = 1500
		},
		boss3 = {
			unit = "Kaller", 
			health = 850, 
			speed = 1.3, 
			money_reward = 1500
		},
		boss4 = {
			unit = "Anekan Skaivoker", 
			health = 700, 
			speed = 2, 
			money_reward = 1500
		},
		boss5 = {
			unit = "Grand Vazien", 
			health = 750, 
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
