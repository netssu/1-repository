local module = {

	initial_money = 550,
	wave_rest_time = 5,
	ItemReward = "Youngling Sauce",
	EnemyStats = {
		normal = { 
			unit = "Soldier",
			health = 165 ,
			speed = 2, 
			money_reward = 40
		}, 
		strong = {
			unit = "Stronger", 
			health = 175, 
			speed = 2, 
			money_reward = 50
		}, 
		tank = {
			unit = "Tank", 
			health = 185, 
			speed = 2, 
			money_reward = 60
		}, 
		quick = {
			unit = "BATTLEDROID B-1 QUICK", 
			health = 170, 
			speed = 4, 
			money_reward = 85
		},
		miniboss = {
			unit = "Tie Interceptor", 
			health = 295, 
			speed = 1.7, 
			money_reward = 160
		},

		boss1 = {
			unit = "Dart Mayl", 
			health = 5450, 
			speed = 2, 
			money_reward = 1750
		},
		boss2 = {
			unit = "Anikan Skaivoker", 
			health = 5600, 
			speed = 1.7, 
			money_reward = 1750
		},
		boss3 = {
			unit = "Mayl Phantom Rage", 
			health = 5700, 
			speed = 1.6, 
			money_reward = 1750
		},
		boss4 = {
			unit = "Dark Overlord", 
			health = 5450, 
			speed = 1.9, 
			money_reward = 1750
		},
		boss5 = {
			unit = "Wader Last Breath", 
			health = 6250, 
			speed = 1.4, 
			money_reward = 1750
		},

	},
	Rewards = {

	},
	Rounds = {


	}
}





return module
