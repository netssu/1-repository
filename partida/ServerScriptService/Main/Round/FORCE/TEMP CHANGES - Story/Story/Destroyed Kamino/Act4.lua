local module = {
--[[Map is "Destroyed Kamino"]]
	initial_money = 750,
	wave_rest_time = 3,
	EnemyStats = {
		normal   = { unit = "B1",	          health = 1620,  speed = 2,    money_reward = 30},
		quick    = { unit = "Droideka", 	  health = 1013,  speed = 4,    money_reward = 75},
		tank     = { unit = "B2",             health = 4556,  speed = 1.5,  money_reward = 50}, 
		strong   = { unit = "SectarianGuard", health = 8100, speed = 1.35, money_reward = 75}, 
		debuff   = { unit = "Battledroid",	  health = 3443,  speed = 3,    money_reward = 125, amount = 0.35}, --"Amount" = Debuff Multiplied on the Player's Damage in Range.
		miniboss = { unit = "BX",             health = 12656, speed = 1.75, money_reward = 150},
		boss     = { unit = "Tact",           health = 56625, speed = 1.25, money_reward = 1500},

	},
	Rewards = {	Gems = 160, Items = { ["Red Milk"] = 3,},	PlayerExp = 51
	},
	Rounds = {
		{
--[[1]]		wave = { { unit = "normal",   amount = 7  } }, wave_reward = 150, wave_diff_scale = 0.25}, 
		{
--[[2]]		wave = { { unit = "normal",   amount = 7  }, 
					 { unit = "quick",    amount = 3  } },	wave_reward = 200, wave_diff_scale = 0.25}, 
		{
--[[3]]		wave = { { unit = "normal",   amount = 7  },
					 { unit = "tank",     amount = 3  } }, wave_reward = 250, wave_diff_scale = 0.3},
		{
--[[4]]		wave = { { unit = "normal",   amount = 7  }, 
					 { unit = "quick",    amount = 4  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 325, wave_diff_scale = 0.35},
		{
--[[5]]		wave = { { unit = "normal",   amount = 7  },
					 { unit = "quick",    amount = 5  }, 
					 { unit = "tank",     amount = 4  }, 
					 { unit = "miniboss", amount = 3  }, 
					 { unit = "debuff",   amount = 1  }, 
					 { unit = "strong",   amount = 3  } }, wave_reward = 525, wave_diff_scale = 0.35}, 
		{
--[[6]]		wave = { { unit = "normal",   amount = 8  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 525, wave_diff_scale = 0.4}, 
		{
--[[7]]		wave = { { unit = "normal",   amount = 8  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 550, wave_diff_scale = 0.45}, 
		{
--[[8]]		wave = { { unit = "normal",   amount = 8  }, 
					 { unit = "quick",    amount = 8  }, 
					 { unit = "tank",     amount = 5  } }, wave_reward = 550, wave_diff_scale = 0.5}, 
		{
--[[9]]		wave = { { unit = "normal",   amount = 9  }, 
					 { unit = "quick",    amount = 9  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 625, wave_diff_scale = 0.65}, 
		{
--[[10]]	wave = { { unit = "normal",   amount = 9  }, 
					 { unit = "quick",    amount = 9  }, 
					 { unit = "tank",     amount = 6  }, 
				     { unit = "debuff",   amount = 1  }, 
					 { unit = "miniboss", amount = 4  }, 
				     { unit = "debuff",   amount = 1  }, 
					 { unit = "strong",   amount = 3  } }, wave_reward = 650, wave_diff_scale = 0.75}, 
		{
--[[11]]	wave = { { unit = "normal",   amount = 12 }, 
					 { unit = "quick",    amount = 9  }, 
					 { unit = "tank",     amount = 7  }, 
					 { unit = "quick",    amount = 9  } }, wave_reward = 675, wave_diff_scale = 0.8}, 
		{
--[[12]]	wave = { { unit = "normal",   amount = 12 }, 
					 { unit = "quick",    amount = 9  }, 
					 { unit = "tank",     amount = 7  }, 
					 { unit = "quick",    amount = 9  } }, wave_reward = 750, wave_diff_scale = 0.9}, 
		{
--[[13]]	wave = { { unit = "normal",   amount = 12 }, 
					 { unit = "quick",    amount = 9  }, 
					 { unit = "tank",     amount = 7  }, 
					 { unit = "strong",   amount = 4  } }, wave_reward = 800, wave_diff_scale = 0.9}, 
		{
--[[14]]	wave = { { unit = "normal",   amount = 12 }, 
					 { unit = "quick",    amount = 9  }, 
					 { unit = "tank",     amount = 7  }, 
					 { unit = "quick",    amount = 9  },
					 { unit = "strong",   amount = 9  } }, wave_reward = 1000, wave_diff_scale = 1},
		{
--[[15]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 6  },
			         { unit = "debuff",   amount = 1  }, 
				     { unit = "boss",     amount = 1, is_boss = true  },
					 { unit = "miniboss", amount = 5  }, 
					 { unit = "debuff",   amount = 1  }, 
					 { unit = "strong",   amount = 5  }, 
					 { unit = "quick",    amount = 5  },
	                 { unit = "miniboss", amount = 2  } }, wave_reward = 0, wave_diff_scale = 1, boss_wave = true
		} 

	}
}

return module