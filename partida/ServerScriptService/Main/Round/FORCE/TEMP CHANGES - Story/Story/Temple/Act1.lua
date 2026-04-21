local module = {
--[[Map is "Temple"]]
	initial_money = 750,
	wave_rest_time = 3,
	EnemyStats = {
		normal   = { unit = "Ace",	    health = 1013,  speed = 4,    money_reward = 30},
		quick    = { unit = "Bobby",    health = 709,   speed = 6,    money_reward = 75},
		tank     = { unit = "Croozie",  health = 3038,  speed = 2.5,  money_reward = 50}, 
		strong   = { unit = "Jack the worst community manager in the world", health = 5063,  speed = 1.5, money_reward = 75}, 
		debuff   = { unit = "Fauzen",	health = 2531,  speed = 2,    money_reward = 125, amount = 0.25}, --"Amount" = Debuff Multiplied on the Player's Damage in Range.
		miniboss = { unit = "Mathirix", health = 8100,  speed = 3,  money_reward = 150},
		boss     = { unit = "Scruffy",  health = 52625, speed = 2, money_reward = 1500},

	},
	Rewards = {	Gems = 175, Items = { ["Red Milk"] = 2,},	PlayerExp = 50
	}, -- Is this the map where the younglings are supposed to be?
	-- yeah im tryna change the stuff up to fit in new bosses and younglings
	-- So you're the one who's importing the younglings?
	-- Um probably but is there anything special we need to do with them
	-- I got no clue, jay is gonna vc in a bit, I need to know which guns and sabers go to which new 3.0 units, would you happen to know? no lol
	-- Bruh im cooked
	-- Ngl ill just wait for vc before i start importing over mobs ill do the bosses for now 
	-- 👍
	Rounds = {
		{
--[[1]]		wave = { { unit = "normal",   amount = 4  } }, wave_reward = 200, wave_diff_scale = 0.25}, 
		{
--[[2]]		wave = { { unit = "normal",   amount = 4  }, 
					 { unit = "quick",    amount = 1  } },	wave_reward = 300, wave_diff_scale = 0.25}, 
		{
--[[3]]		wave = { { unit = "normal",   amount = 4  },
					 { unit = "tank",     amount = 1  } }, wave_reward = 400, wave_diff_scale = 0.3},
		{
--[[4]]		wave = { { unit = "normal",   amount = 4  }, 
					 { unit = "quick",    amount = 2  }, 
					 { unit = "tank",     amount = 2  } }, wave_reward = 500, wave_diff_scale = 0.35},
		{
--[[5]]		wave = { { unit = "normal",   amount = 4  },
					 { unit = "quick",    amount = 4  }, 
					 { unit = "tank",     amount = 2  }, 
					 { unit = "strong",   amount = 1  } }, wave_reward = 650, wave_diff_scale = 0.35}, 
		{
--[[6]]		wave = { { unit = "normal",   amount = 5  }, 
					 { unit = "quick",    amount = 4  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 650, wave_diff_scale = 0.4}, 
		{
--[[7]]		wave = { { unit = "normal",   amount = 5  }, 
					 { unit = "quick",    amount = 4  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 700, wave_diff_scale = 0.45}, 
		{
--[[8]]		wave = { { unit = "normal",   amount = 5  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  } }, wave_reward = 700, wave_diff_scale = 0.5}, 
		{
--[[9]]		wave = { { unit = "normal",   amount = 6  }, 
					 { unit = "quick",    amount = 5  }, 
					 { unit = "tank",     amount = 3  }, 
					 { unit = "quick",    amount = 3  } }, wave_reward = 750, wave_diff_scale = 0.65}, 
		{
--[[10]]	wave = { { unit = "normal",   amount = 6  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 3  }, 
					 { unit = "miniboss", amount = 2  }, 
					 { unit = "strong",   amount = 3  } }, wave_reward = 750, wave_diff_scale = 0.75}, 
		{
--[[11]]	wave = { { unit = "normal",   amount = 8  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 4  }, 
					 { unit = "quick",    amount = 4  } }, wave_reward = 750, wave_diff_scale = 0.8}, 
		{
--[[12]]	wave = { { unit = "normal",   amount = 8  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 4  }, 
					 { unit = "quick",    amount = 4  } }, wave_reward = 800, wave_diff_scale = 0.9}, 
		{
--[[13]]	wave = { { unit = "normal",   amount = 8  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 4  }, 
					 { unit = "quick",    amount = 4  } }, wave_reward = 900, wave_diff_scale = 0.9}, 
		{
--[[14]]	wave = { { unit = "normal",   amount = 8  }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 6  }, 
					 { unit = "quick",    amount = 6  } }, wave_reward = 1000, wave_diff_scale = 1},
		{
--[[15]]	wave = { { unit = "normal",   amount = 10 }, 
					 { unit = "quick",    amount = 6  }, 
					 { unit = "tank",     amount = 6  },
				     { unit = "boss",     amount = 1, is_boss = true  },
				     { unit = "miniboss", amount = 5  }, 
					 { unit = "strong",   amount = 5  }, 
					 { unit = "quick",    amount = 5  },
	          		 { unit = "miniboss", amount = 1  } }, wave_reward = 0, wave_diff_scale = 1, boss_wave = true
		} 

	}
}

return module