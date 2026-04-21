local module = {

	initial_money = 500,
	wave_rest_time = 5,
	EnemyStats = {
		normal = { 
			unit = "B1", 
			health = 25, 
			speed = 2, 
			money_reward = 30
		}, 
		strong = {
			unit = "SectarianGuard", 
			health = 35, 
			speed = 2, 
			money_reward = 40
		}, 
		debuff = {
			unit = "Battledroid",
			health = 40,
			speed = 2,
			amount = .75, -- amount of debuff multiplied on the player's damage in range.
			money_reward = 45,
		},
		tank = {
			unit = "B2", 
			health = 45, 
			speed = 2, 
			money_reward = 50
		}, 
		quick = {
			unit = "Droideka", 
			health = 35, 
			speed = 4, 
			money_reward = 75
		},
		miniboss = {
			unit = "BX", 
			health = 95, 
			speed = 1.7, 
			money_reward = 150
		},
		boss = {
			unit = "Tact", 
			health = 200, 
			speed = 1.7, 
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
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 0.5
		}, 
		
		{
			wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 0.5
		}, {
			wave = { {
				unit = "normal", 
				amount = 4
			}, {
				unit = "strong", 
				amount = 1
			} }, 
			wave_reward = 600, 
			wave_diff_scale = 0.5
		}, {
			wave = { {
				unit = "normal", 
				amount = 5
			}, {
				unit = "strong", 
				amount = 2
			} }, 
			wave_reward = 750, 
			wave_diff_scale = 0.75
		}, {
			wave = { {
				unit = "normal", 
				amount = 6
			}, {
				unit = "strong", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 0.75
		}, {
			wave = { {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 1
		}, {
			wave = { {
				unit = "normal", 
				amount = 6
			}, {
				unit = "strong", 
				amount = 6
			}, {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 1
		}, {
			wave = { {
				unit = "normal", 
				amount = 6
			}, {
				unit = "strong", 
				amount = 8
			}, {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1250, 
			wave_diff_scale = 1.5
		}, {
			wave = { {
				unit = "normal", 
				amount = 4
			}, {
				unit = "strong", 
				amount = 8
			}, {
				unit = "tank", 
				amount = 6
			} }, 
			wave_reward = 1250, 
			wave_diff_scale = 2.25
		}, {
			wave = { {
				unit = "quick", 
				amount = 3
			} }, 
			wave_reward = 1250, 
			wave_diff_scale = 2.25
		}, {
			wave = { {
				unit = "normal", 
				amount = 15
			}, {
				unit = "tank", 
				amount = 8
			}, {
				unit = "quick", 
				amount = 3
			} }, 
			wave_reward = 1250, 
			wave_diff_scale = 3
		}, {
			wave = { {
				unit = "normal", 
				amount = 14
			}, {
				unit = "strong", 
				amount = 8
			}, {
				unit = "tank", 
				amount = 6
			}, {
				unit = "quick", 
				amount = 4
			} }, 
			wave_reward = 1500, 
			wave_diff_scale = 3
		}, {
			wave = { {
				unit = "normal", 
				amount = 20
			}, {
				unit = "strong", 
				amount = 8
			}, {
				unit = "tank", 
				amount = 12
			} }, 
			wave_reward = 1500, 
			wave_diff_scale = 4
		}, {
			wave = { {
				unit = "normal", 
				amount = 20
			}, {
				unit = "strong", 
				amount = 12
			}, {
				unit = "tank", 
				amount = 10
			}, {
				unit = "quick", 
				amount = 4
			} }, 
			wave_reward = 1500, 
			wave_diff_scale = 4.5
		}, {
			wave = { {
				unit = "tank", 
				amount = 6
			}, {
				unit = "boss", 
				amount = 1, 
				is_boss = true
			} }, 
			wave_reward = 0, 
			wave_diff_scale = 2.5, 
			boss_wave = true
		}, 

	}
}





return module
