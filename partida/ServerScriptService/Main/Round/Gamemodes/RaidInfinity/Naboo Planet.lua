local module = {

	initial_money = 500,
	wave_rest_time = 5,
	ItemReward = "Milk",
	EnemyStats = {
		normal = { 
			unit = "Soldier",
			health = 20, 
			speed = 2, 
			money_reward = 30
		}, 
		strong = {
			unit = "Stronger", 
			health = 30, 
			speed = 2, 
			money_reward = 40
		}, 
		tank = {
			unit = "Tank", 
			health = 40, 
			speed = 2, 
			money_reward = 50
		}, 
		quick = {
			unit = "BATTLEDROID B-1 QUICK", 
			health = 30, 
			speed = 4, 
			money_reward = 75
		},
		miniboss = {
			unit = "Tie Interceptor", 
			health = 90, 
			speed = 1.7, 
			money_reward = 150
		},
	
		boss1 = {
			unit = "Commander", 
			health = 400, 
			speed = 1.7, 
			money_reward = 1500
		},
		boss2 = {
			unit = "Loner", 
			health = 250, 
			speed = 2.5, 
			money_reward = 1500
		},
		boss3 = {
			unit = "GalacticShip", 
			health = 300, 
			speed = 2, 
			money_reward = 1500
		},
		boss4 = {
			unit = "Mandalorian", 
			health = 400, 
			speed = 1.6, 
			money_reward = 1500
		},
		boss5 = {
			unit = "Chancelar", 
			health = 500, 
			speed = 1.5, 
			money_reward = 1500
		},

	},
	Rewards = {
		
	},
	Rounds = {
		

	}
}





return module
