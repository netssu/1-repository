local module = {

	initial_money = 500,
	wave_rest_time = 5,
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
		boss = {
			unit = "Chancelar", 
			health = 500, 
			speed = 1.5, 
			money_reward = 1500
		},

	},
	Rewards = {

		Gems = 60,
		Items = {
			Milk = 3,
		},
		PlayerExp = 25

	},
	Rounds = {
		{

			wave = { {
				unit = "normal", 
				amount = 2
			}, {
				unit = "strong", 
				amount = 1
			} }, 
			wave_reward = 200, 
			wave_diff_scale = 0.5
		}, {
			wave = { {
				unit = "normal", 
				amount = 3
			}, {
				unit = "strong", 
				amount = 1
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 0.5
		}, {
			wave = { {
				unit = "normal", 
				amount = 2
			}, {
				unit = "strong", 
				amount = 1
			}, {
				unit = "tank", 
				amount = 1
			} }, 
			wave_reward = 600, 
			wave_diff_scale = 0.5
		}, {
			wave = { {
				unit = "strong", 
				amount = 2
			}, {
				unit = "tank", 
				amount = 1
			}, {
				unit = "quick", 
				amount = 1
			} }, 
			wave_reward = 750, 
			wave_diff_scale = 0.75
		}, {
			wave = { {
				unit = "normal", 
				amount = 4
			}, {
				unit = "strong", 
				amount = 1
			}, {
				unit = "quick", 
				amount = 2
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 0.75
		}, {
			wave = { {
				unit = "normal", 
				amount = 10
			}, {
				unit = "miniboss", 
				amount = 1
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 1
		}, {
			wave = { {
				unit = "normal", 
				amount = 4
			}, {
				unit = "strong", 
				amount = 3
			}, {
				unit = "tank", 
				amount = 2
			}, {
				unit = "quick", 
				amount = 3
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 1
		}, {
			wave = { {
				unit = "normal", 
				amount = 12
			}, {
				unit = "tank", 
				amount = 4
			}, {
				unit = "quick", 
				amount = 2
			}, {
				unit = "miniboss", 
				amount = 3
			} }, 
			wave_reward = 1250, 
			wave_diff_scale = 1.5
		}, {
			wave = { {
				unit = "normal", 
				amount = 14
			}, {
				unit = "strong", 
				amount = 8
			}, {
				unit = "tank", 
				amount = 3
			}, {
				unit = "miniboss", 
				amount = 2
			} }, 
			wave_reward = 1250, 
			wave_diff_scale = 2.25
		}, {
			wave = { {
				unit = "normal", 
				amount = 18
			}, {
				unit = "strong", 
				amount = 8
			}, {
				unit = "miniboss", 
				amount = 3
			} }, 
			wave_reward = 1250, 
			wave_diff_scale = 2.25
		}, {
			wave = { {
				unit = "tank", 
				amount = 4
			}, {
				unit = "quick", 
				amount = 6
			} }, 
			wave_reward = 1250, 
			wave_diff_scale = 3
		}, {
			wave = { {
				unit = "normal", 
				amount = 20
			}, {
				unit = "strong", 
				amount = 12
			}, {
				unit = "tank", 
				amount = 8
			}, {
				unit = "quick", 
				amount = 2
			}, {
				unit = "miniboss", 
				amount = 1
			} }, 
			wave_reward = 1500, 
			wave_diff_scale = 3
		}, {
			wave = { {
				unit = "normal", 
				amount = 20
			}, {
				unit = "strong", 
				amount = 14
			}, {
				unit = "tank", 
				amount = 8
			}, {
				unit = "miniboss", 
				amount = 2
			} }, 
			wave_reward = 1500, 
			wave_diff_scale = 4
		}, {
			wave = { {
				unit = "normal", 
				amount = 24
			}, {
				unit = "strong", 
				amount = 18
			}, {
				unit = "tank", 
				amount = 12
			}, {
				unit = "miniboss", 
				amount = 2
			}, }, 
			wave_reward = 1500, 
			wave_diff_scale = 4.5
		}, {
			wave = { {
				unit = "boss", 
				amount = 1, 
				is_boss = true
			} }, 
			wave_reward = 0, 
			wave_diff_scale = 4.5, 
			boss_wave = true
		} 

	}
}





return module
