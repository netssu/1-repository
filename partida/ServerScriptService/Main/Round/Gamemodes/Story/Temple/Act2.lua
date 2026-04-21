local module = {
--[[Map is "Temple"]]
	initial_money = 750,
	wave_rest_time = 3,
	EnemyStats = {
		normal   = { unit = "Ace",	    health = 105,  speed = 4,    money_reward = 30},
		quick    = { unit = "Bobby",    health = 115,   speed = 6,     money_reward = 75},
		tank     = { unit = "Croozie",  health = 120,  speed = 2.5,  money_reward = 50}, 
		strong   = { unit = "Jack the worst community manager in the world", health = 125, speed = 1.5, money_reward = 75}, 
		debuff   = { unit = "Fauzen",   health = 115,  speed = 2,    money_reward = 125, amount = 0.25}, --"Amount" = Debuff Multiplied on the Player's Damage in Range.
		miniboss = { unit = "Mathirix", health = 195,  speed = 3,  money_reward = 150},
		boss     = { unit = "Scruffy",  health = 8000, speed = 2, money_reward = 1500},

	},
	Rewards = {	Gems = 180, Items = { ["Youngling Sauce"] = 2,},	PlayerExp = 52
	},
	Rounds = {
		{
--[[1]]		wave = { { unit = "normal",   amount = 5  } }, wave_reward = 200, wave_diff_scale = 0.5}, 
		{
--[[2]]		wave = { { unit = "normal",   amount = 5  }, 
					 { unit = "quick",    amount = 2  } },	wave_reward = 300, wave_diff_scale = 0.5}, 
		{
--[[3]]		wave = { { unit = "normal",   amount = 5  },
					 { unit = "tank",     amount = 2  } }, wave_reward = 400, wave_diff_scale = 0.5},
		{
--[[4]]		wave = { { unit = "normal",   amount = 5  }, 
					 { unit = "quick",    amount = 4  }, 
					 { unit = "tank",     amount = 2  } }, wave_reward = 500, wave_diff_scale = 0.75},
		{
--[[5]]		wave = { { unit = "normal",   amount = 5  },
					 { unit = "quick",    amount = 3  }, 
					 { unit = "tank",     amount = 2  },
				     { unit = "miniboss", amount = 1  }, 
				     { unit = "strong",   amount = 2  } },   wave_reward = 650, wave_diff_scale = 0.75}, 
		{
--[[6]]		wave = { { unit = "normal",   amount = 6  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 650, wave_diff_scale = 1}, 
		{
--[[7]]		wave = { { unit = "normal",   amount = 6  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 700, wave_diff_scale = 1}, 
		{
--[[8]]		wave = { { unit = "normal",   amount = 6  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 700, wave_diff_scale = 1.5}, 
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
					 { unit = "strong",   amount = 2  } }, wave_reward = 750, wave_diff_scale = 2.25}, 
		{
--[[11]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 8  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 750, wave_diff_scale = 3}, 
		{
--[[12]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 8  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 800, wave_diff_scale = 3}, 
		{
--[[13]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 8  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 900, wave_diff_scale = 4}, 
		{
--[[14]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 8  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 1000, wave_diff_scale = 4.4},
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