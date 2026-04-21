local module = {
--[[Map is "Naboo Planet"]]
	initial_money = 550,
	wave_rest_time = 3,
	EnemyStats = {
		normal   = { unit = "B1",	          health = 60,   speed = 2,    money_reward = 30},
		quick    = { unit = "Droideka", 	  health = 40,   speed = 4,    money_reward = 75},
		tank     = { unit = "B2",             health = 175,  speed = 1.5,  money_reward = 50}, 
		strong   = { unit = "SectarianGuard", health = 300,  speed = 1.35, money_reward = 75}, 
		debuff   = { unit = "Battledroid",	  health = 140,  speed = 3,    money_reward = 125, amount = 0.25}, --"Amount" = Debuff Multiplied on the Player's Damage in Range.
		miniboss = { unit = "BX",             health = 475,  speed = 1.75, money_reward = 150},
		boss     = { unit = "Tact",           health = 1250, speed = 1.25, money_reward = 1500},

	},
	Rewards = {	Gems = 50, Items = { ["Milk"] = 2,},	PlayerExp = 17
	},
	Rounds = {
		{
--[[1]]		wave = { { unit = "normal",   amount = 5  } }, wave_reward = 200, wave_diff_scale = 0.1}, 
		{
--[[2]]		wave = { { unit = "normal",   amount = 5  }, 
					 { unit = "quick",    amount = 2  } },	wave_reward = 300, wave_diff_scale = 0.15}, 
		{
--[[3]]		wave = { { unit = "normal",   amount = 5  },
					 { unit = "tank",     amount = 2  } }, wave_reward = 400, wave_diff_scale = 0.2},
		{
--[[4]]		wave = { { unit = "normal",   amount = 5  }, 
					 { unit = "quick",    amount = 4  }, 
					 { unit = "tank",     amount = 2  } }, wave_reward = 500, wave_diff_scale = 0.25},
		{
--[[5]]		wave = { { unit = "normal",   amount = 5  },
					 { unit = "quick",    amount = 3  }, 
					 { unit = "tank",     amount = 2  },
				     { unit = "miniboss", amount = 1  }, 
				     { unit = "strong",   amount = 2  } },   wave_reward = 650, wave_diff_scale = 0.35}, 
		{
--[[6]]		wave = { { unit = "normal",   amount = 6  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 650, wave_diff_scale = 0.4}, 
		{
--[[7]]		wave = { { unit = "normal",   amount = 6  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 700, wave_diff_scale = 0.45}, 
		{
--[[8]]		wave = { { unit = "normal",   amount = 6  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 700, wave_diff_scale = 0.5}, 
		{
--[[9]]		wave = { { unit = "normal",   amount = 7  }, 
					 { unit = "quick",    amount = 7  }, 
					 { unit = "tank",     amount = 4  }, 
					 { unit = "quick",    amount = 4  } }, wave_reward = 750, wave_diff_scale = 0.65}, 
		{
--[[10]]	wave = { { unit = "normal",   amount = 7  }, 
					 { unit = "quick",    amount = 7  }, 
					 { unit = "tank",     amount = 4  }, 
					 { unit = "miniboss", amount = 2  }, 
					 { unit = "strong",   amount = 2  } }, wave_reward = 750, wave_diff_scale = 0.75}, 
		{
--[[11]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 8  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 750, wave_diff_scale = 0.8}, 
		{
--[[12]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 8  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 800, wave_diff_scale = 0.9}, 
		{
--[[13]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 8  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 900, wave_diff_scale = 0.9}, 
		{
--[[14]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 8  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 1000, wave_diff_scale = 1},
		{
--[[15]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 6  },
        			 { unit = "boss",     amount = 1, is_boss = true  },
					 { unit = "miniboss", amount = 3  }, 
					 { unit = "debuff",   amount = 1  }, 
					 { unit = "strong",   amount = 4  }, 
					 { unit = "quick",    amount = 5  },
	                 { unit = "miniboss", amount = 1  } }, wave_reward = 0, wave_diff_scale = 1, boss_wave = true
		} 

	}
}

return module