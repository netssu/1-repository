local module = {

	initial_money = 500,
	wave_rest_time = 5,
	EnemyStats = {
		normal = { 
			unit = "B1",
			health = 5, 
			speed = 2, 
			money_reward = 60
		}, 
		strong = {
			unit = "SectarianGuard", 
			health = 10, 
			speed = 2, 
			money_reward = 80
		}, 
		debuff = {
			unit = "Battledroid",
			health = 15,
			speed = 2,
			amount = .75, -- amount of debuff multiplied on the player's damage in range.
			money_reward = 90,
		},
		tank = {
			unit = "B2", 
			health = 25, 
			speed = 2, 
			money_reward = 100
		}, 
		quick = {
			unit = "Droideka", 
			health = 5, 
			speed = 4, 
			money_reward = 150
		},
		miniboss = {
			unit = "BX", 
			health = 45, 
			speed = 1.7, 
			money_reward = 300
		},
		boss = {
			unit = "Tact", 
			health = 100, 
			speed = 1.7, 
			money_reward = 1500
		},

	},
	Rewards = {
		
		Gems = 60,
		Items = {
			Milk = 2,
		},
		PlayerExp = 25

	},
	Rounds = {
		{

--[[1]]		wave = { {
				unit = "normal", 
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 0.5
		}, {
--[[2]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 0.5
		}, {
--[[3]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
				unit = "strong", 
				amount = 1
			} }, 
			wave_reward = 600, 
			wave_diff_scale = 0.5
		}, {
--[[4]]		wave = { {
				unit = "normal", 
				amount = 5
			}, {
				unit = "strong", 
				amount = 2
			} }, 
			wave_reward = 750, 
			wave_diff_scale = 0.75
		}, {
--[[5]]		wave = { {
				unit = "miniboss", 
				amount = 1
			}, {
				unit = "strong", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 0.75
		}, {
--[[6]]		wave = { {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 1
		}, {
--[[7]]		wave = { {
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
--[[8]]		wave = { {
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
--[[9]]		wave = { {
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
				unit = "tank", 
				amount = 6
			}, {
				unit = "boss", 
				amount = 1, 
				is_boss = true
			} }, 
			wave_reward = 0, 
			wave_diff_scale = 4.5, 
			boss_wave = true
		}, 

	}
}





return module
