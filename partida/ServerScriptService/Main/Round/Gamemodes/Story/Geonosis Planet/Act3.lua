local module = {

	initial_money = 500,
	wave_rest_time = 5,
	EnemyStats = {
		normal = { 
			unit = "B1",
			health = 35, 
			speed = 2, 
			money_reward = 30
		}, 
		strong = {
			unit = "SectarianGuard", 
			health = 45, 
			speed = 2, 
			money_reward = 40
		}, 
		debuff = {
			unit = "Battledroid",
			health = 50,
			speed = 2,
			amount = .65, -- amount of debuff multiplied on the player's damage in range.
			money_reward = 45,
		},
		tank = {
			unit = "B2", 
			health = 55, 
			speed = 2, 
			money_reward = 50
		}, 
		quick = {
			unit = "Droideka", 
			health = 45, 
			speed = 4, 
			money_reward = 75
		},
		miniboss = {
			unit = "BX", 
			health = 105, 
			speed = 1.7, 
			money_reward = 150
		},
		boss = {
			unit = "Tact", 
			health = 350, 
			speed = 1.3, 
			money_reward = 1500
		},

	},
	Rewards = {

		Gems = 60,
		Items = {
			["Yellow Milk"] = 2,
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
				amount = 4
			}, {
				unit = "tank", 
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
				unit = "tank", 
				amount = 3
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 0.75
		}, {
			wave = { {
				unit = "normal", 
				amount = 5
			}, {
				unit = "tank", 
				amount = 1
			}, {
				unit = "quick", 
				amount = 2
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
				amount = 4
			}, {
				unit = "tank", 
				amount = 4
			}, {
				unit = "quick", 
				amount = 2
			}, {
				unit = "miniboss", 
				amount = 1
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
				amount = 16
			}, {
				unit = "strong", 
				amount = 6
			}, {
				unit = "miniboss", 
				amount = 3
			} }, 
			wave_reward = 1250, 
			wave_diff_scale = 2.25
		}, {
			wave = { {
				unit = "tank", 
				amount = 6
			}, {
				unit = "quick", 
				amount = 4
			} }, 
			wave_reward = 1250, 
			wave_diff_scale = 3
		}, {
			wave = { {
				unit = "normal", 
				amount = 18
			}, {
				unit = "strong", 
				amount = 12
			}, {
				unit = "tank", 
				amount = 8
			}, {
				unit = "quick", 
				amount = 4
			} }, 
			wave_reward = 1500, 
			wave_diff_scale = 3
		}, {
			wave = { {
				unit = "normal", 
				amount = 22
			}, {
				unit = "strong", 
				amount = 16
			}, {
				unit = "tank", 
				amount = 8
			}, {
				unit = "miniboss", 
				amount = 1
			} }, 
			wave_reward = 1500, 
			wave_diff_scale = 4
		}, {
			wave = { {
				unit = "normal", 
				amount = 30
			}, {
				unit = "strong", 
				amount = 20
			}, {
				unit = "tank", 
				amount = 4
			}, {
				unit = "quick", 
				amount = 3
			}, {
				unit = "miniboss", 
				amount = 1
			} }, 
			wave_reward = 1500, 
			wave_diff_scale = 4.5
		}, {
			wave = { {
				unit = "tank", 
				amount = 4
			}, {
				unit = "boss", 
				amount = 1, 
				is_boss = true
			} }, 
			wave_reward = 0, 
			wave_diff_scale = 2.5, 
			boss_wave = true
		}

	}
}





return module
