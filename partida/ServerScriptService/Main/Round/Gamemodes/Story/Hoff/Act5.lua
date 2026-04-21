local module = {
--[[Map is Hoth]]
	initial_money = 750,
	wave_rest_time = 5,
	EnemyStats = {
		normal   = { unit = "B1",	          health = 140,   speed = 2,   money_reward = 30},
		strong   = { unit = "SectarianGuard", health = 160,   speed = 2,   money_reward = 40}, 
		debuff   = { unit = "Battledroid",	  health = 150,   speed = 2,   money_reward = 40, amount = .75},
		tank     = { unit = "B2",             health = 155,   speed = 2,   money_reward = 50}, 
		quick    = { unit = "Droideka",    	  health = 130,   speed = 4,   money_reward = 75},
		miniboss = { unit = "BX",             health = 240,   speed = 1.7, money_reward = 150},
		boss     = { unit = "Tact",           health = 11500, speed = 2,   money_reward = 1500},
	},
	Rewards = {
		
		Gems = 220,
		Items = { ["Youngling Sauce"] = 4, }, PlayerExp = 65
	},
	Rounds = {
		{
--[[1]]		wave = { { unit = "normal",   amount = 7  } }, wave_reward = 150, wave_diff_scale = 0.5}, 
		{
--[[2]]		wave = { { unit = "normal",   amount = 7  }, 
					 { unit = "quick",    amount = 3  } },	wave_reward = 200, wave_diff_scale = 0.5}, 
		{
--[[3]]		wave = { { unit = "normal",   amount = 7  },
					 { unit = "tank",     amount = 3  } }, wave_reward = 250, wave_diff_scale = 0.5},
		{
--[[4]]		wave = { { unit = "normal",   amount = 7  }, 
					 { unit = "quick",    amount = 4  }, 
					 { unit = "tank",     amount = 4  } }, wave_reward = 325, wave_diff_scale = 0.75},
		{
--[[5]]		wave = { { unit = "normal",   amount = 7  },
					 { unit = "quick",    amount = 5  }, 
					 { unit = "tank",     amount = 4  }, 
					 { unit = "miniboss", amount = 3  }, 
					 { unit = "debuff",   amount = 1  }, 
					 { unit = "strong",   amount = 3  } }, wave_reward = 525, wave_diff_scale = 0.75}, 
		{
--[[6]]		wave = { { unit = "normal",   amount = 8  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 525, wave_diff_scale = 1}, 
		{
--[[7]]		wave = { { unit = "normal",   amount = 8  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 550, wave_diff_scale = 1}, 
		{
--[[8]]		wave = { { unit = "normal",   amount = 8  }, 
					 { unit = "quick",    amount = 8  }, 
					 { unit = "tank",     amount = 5  } }, wave_reward = 550, wave_diff_scale = 1.5}, 
		{
--[[9]]		wave = { { unit = "normal",   amount = 9  }, 
					 { unit = "quick",    amount = 9  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 625, wave_diff_scale = 2.25}, 
		{
--[[10]]	wave = { { unit = "normal",   amount = 9  }, 
					 { unit = "quick",    amount = 9  }, 
					 { unit = "tank",     amount = 6  }, 
				     { unit = "debuff",   amount = 1  }, 
					 { unit = "miniboss", amount = 4  }, 
				     { unit = "debuff",   amount = 1  }, 
					 { unit = "strong",   amount = 3  } }, wave_reward = 650, wave_diff_scale = 2.25}, 
		{
--[[11]]	wave = { { unit = "normal",   amount = 12 }, 
					 { unit = "quick",    amount = 9  }, 
					 { unit = "tank",     amount = 7  }, 
					 { unit = "quick",    amount = 9  } }, wave_reward = 675, wave_diff_scale = 3}, 
		{
--[[12]]	wave = { { unit = "normal",   amount = 12 }, 
					 { unit = "quick",    amount = 9  }, 
					 { unit = "tank",     amount = 7  }, 
					 { unit = "quick",    amount = 9  } }, wave_reward = 750, wave_diff_scale = 3}, 
		{
--[[13]]	wave = { { unit = "normal",   amount = 12 }, 
					 { unit = "quick",    amount = 9  }, 
					 { unit = "tank",     amount = 7  }, 
					 { unit = "strong",   amount = 4  } }, wave_reward = 800, wave_diff_scale = 4}, 
		{
--[[14]]	wave = { { unit = "normal",   amount = 12 }, 
					 { unit = "quick",    amount = 9  }, 
					 { unit = "tank",     amount = 7  }, 
					 { unit = "quick",    amount = 9  },
					 { unit = "strong",   amount = 9  } }, wave_reward = 1000, wave_diff_scale = 4.5},
		{
--[[15]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 6  },
					 { unit = "miniboss", amount = 4  },
				     { unit = "debuff",   amount = 1  }, 
				     { unit = "boss",     amount = 1, is_boss = true  },
					 { unit = "miniboss", amount = 4  }, 
					 { unit = "debuff",   amount = 1  }, 
					 { unit = "strong",   amount = 6  }, 
					 { unit = "quick",    amount = 5  },
				     { unit = "debuff",   amount = 1  }, 
	                 { unit = "miniboss", amount = 4  } }, wave_reward = 0, wave_diff_scale = 4.5, boss_wave = true
		} 

	}
}

return module