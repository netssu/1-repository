local module = {
--[[Map is Hoth]]
	initial_money = 750,
	wave_rest_time = 5,
	EnemyStats = {
		normal   = { unit = "B1",	          health = 150,  speed = 2,   money_reward = 30},
		strong   = { unit = "SectarianGuard", health = 170,  speed = 2,   money_reward = 40}, 
		debuff   = { unit = "Battledroid",	  health = 160,  speed = 2,   money_reward = 40, amount = .75},
		tank     = { unit = "B2",             health = 165,  speed = 2,   money_reward = 50}, 
		quick    = { unit = "Droideka",    	  health = 140,  speed = 4,   money_reward = 75},
		miniboss = { unit = "BX",             health = 250,  speed = 1.7, money_reward = 150},
		boss     = { unit = "Tact",           health = 11000, speed = 2,   money_reward = 1500},
	},
	Rewards = {
		
		Gems = 280,
		Items = { ["Purple Milk"] = 2, }, PlayerExp = 75
	},
	Rounds = {
		{
--[[1]]		wave = { { unit = "normal",   amount = 5  } }, wave_reward = 200, wave_diff_scale = 0.5}, 
		{
--[[2]]		wave = { { unit = "normal",   amount = 5  }, 
					 { unit = "quick",    amount = 2  } },	wave_reward = 300, wave_diff_scale = 0.65}, 
		{
--[[3]]		wave = { { unit = "normal",   amount = 5  },
					 { unit = "tank",     amount = 2  } }, wave_reward = 400, wave_diff_scale = 0.7},
		{
--[[4]]		wave = { { unit = "normal",   amount = 5  }, 
					 { unit = "quick",    amount = 4  }, 
					 { unit = "tank",     amount = 2  } }, wave_reward = 500, wave_diff_scale = 0.75},
		{
--[[5]]		wave = { { unit = "normal",   amount = 5  },
					 { unit = "quick",    amount = 3  }, 
					 { unit = "tank",     amount = 2  },
				     { unit = "miniboss", amount = 1  }, 
				     { unit = "strong",   amount = 2  } },   wave_reward = 650, wave_diff_scale = 0.85}, 
		{
--[[6]]		wave = { { unit = "normal",   amount = 6  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 650, wave_diff_scale = 1}, 
		{
--[[7]]		wave = { { unit = "normal",   amount = 6  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 700, wave_diff_scale = 1.5}, 
		{
--[[8]]		wave = { { unit = "normal",   amount = 6  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 700, wave_diff_scale = 2.0}, 
		{
--[[9]]		wave = { { unit = "normal",   amount = 7  }, 
					 { unit = "quick",    amount = 7  }, 
					 { unit = "tank",     amount = 4  }, 
					 { unit = "quick",    amount = 4  } }, wave_reward = 750, wave_diff_scale = 2.25}, 
		{
--[[10]]	wave = { { unit = "normal",   amount = 7  }, 
					 { unit = "quick",    amount = 7  }, 
					 { unit = "tank",     amount = 4  }, 
					 { unit = "miniboss", amount = 2  }, 
					 { unit = "strong",   amount = 2  } }, wave_reward = 750, wave_diff_scale = 2.5}, 
		{
--[[11]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 8  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 750, wave_diff_scale = 3}, 
		{
--[[12]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 8  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 800, wave_diff_scale = 3.5}, 
		{
--[[13]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 8  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 900, wave_diff_scale = 4}, 
		{
--[[14]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 8  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 1000, wave_diff_scale = 4.5},
		{
--[[15]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 6  },
        			 { unit = "boss",     amount = 1, is_boss = true  },
					 { unit = "miniboss", amount = 3  }, 
					 { unit = "debuff",   amount = 1  }, 
					 { unit = "strong",   amount = 4  }, 
					 { unit = "quick",    amount = 5  },
	                 { unit = "miniboss", amount = 1  } }, wave_reward = 0, wave_diff_scale = 4.5, boss_wave = true
		} 

	}
}

return module