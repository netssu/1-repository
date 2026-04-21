local module = {
--[[Map is "Naboo Planet"]]
	initial_money = 550,
	wave_rest_time = 3,
	EnemyStats = {
		normal   = { unit = "B1",	          health = 30,   speed = 2,    money_reward = 60},
		quick    = { unit = "Droideka", 	  health = 20,   speed = 4,    money_reward = 150},
		tank     = { unit = "B2",             health = 100,  speed = 1.5,  money_reward = 100}, 
		strong   = { unit = "SectarianGuard", health = 175,  speed = 1.35, money_reward = 150}, 
		debuff   = { unit = "Battledroid",	  health = 85,   speed = 3,    money_reward = 250, amount = 0.25}, --"Amount" = Debuff Multiplied on the Player's Damage in Range.
		miniboss = { unit = "BX",             health = 200,  speed = 1.75, money_reward = 300},
		boss     = { unit = "Hired Killer",           health = 650,  speed = 1.25, money_reward = 1500},

	},
	Rewards = {	Gems = 45, Items = { ["Milk"] = 2,},	PlayerExp = 15
	},
	Rounds = {
		{
--[[1]]		wave = { { unit = "debuff",   amount = 3  } }, wave_reward = 200, wave_diff_scale = 0.25}, 
		{
--[[2]]		wave = { { unit = "normal",   amount = 3  }, 
					 { unit = "quick",    amount = 1  } },	wave_reward = 300, wave_diff_scale = 0.25}, 
		{
--[[3]]		wave = { { unit = "normal",   amount = 3  },
					 { unit = "tank",     amount = 1  } }, wave_reward = 400, wave_diff_scale = 0.3},
		{
--[[4]]		wave = { { unit = "normal",   amount = 4  }, 
					 { unit = "quick",    amount = 2  }, 
					 { unit = "tank",     amount = 2  } }, wave_reward = 500, wave_diff_scale = 0.35},
		{
--[[5]]		wave = { { unit = "normal",   amount = 4  },
					 { unit = "quick",    amount = 2  }, 
					 { unit = "tank",     amount = 2  }, 
					 { unit = "strong",   amount = 1  } }, wave_reward = 650, wave_diff_scale = 0.35}, 
		{
--[[6]]		wave = { { unit = "normal",   amount = 4  }, 
					 { unit = "quick",    amount = 2  }, 
					 { unit = "tank",     amount = 1  } }, wave_reward = 650, wave_diff_scale = 0.4}, 
		{
--[[7]]		wave = { { unit = "normal",   amount = 4  }, 
					 { unit = "quick",    amount = 3  }, 
					 { unit = "tank",     amount = 2  } }, wave_reward = 700, wave_diff_scale = 0.45}, 
		{
--[[8]]		wave = { { unit = "normal",   amount = 4  }, 
					 { unit = "quick",    amount = 4  }, 
					 { unit = "tank",     amount = 2  } }, wave_reward = 700, wave_diff_scale = 0.5}, 
		{
--[[9]]		wave = { { unit = "normal",   amount = 5  }, 
					 { unit = "quick",    amount = 5  }, 
					 { unit = "tank",     amount = 3  }, 
					 { unit = "quick",    amount = 1  } }, wave_reward = 750, wave_diff_scale = 0.65}, 
		{
--[[10]]	wave = { { unit = "normal",   amount = 7 }, 
					 { unit = "quick",    amount = 3  }, 
					 { unit = "tank",     amount = 2  },
				     { unit = "boss",     amount = 1, is_boss = true  },
					 { unit = "strong",   amount = 2  }, 
					 { unit = "quick",    amount = 5  },
	          		 { unit = "miniboss", amount = 1  } }, wave_reward = 0, wave_diff_scale = 1, boss_wave = true
		} 

	}
}

return module