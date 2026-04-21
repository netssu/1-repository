local module = {

	initial_money = 500,
	wave_rest_time = 5,
	EnemyStats = {
		normal = { 
			unit = "B1",
			health = 295, 
			speed = 2, 
			money_reward = 30
		}, 
		strong = {
			unit = "B2", 
			health = 325, 
			speed = 2, 
			money_reward = 40
		}, 
		tank = {
			unit = "BX", 
			health = 355, 
			speed = 2, 
			money_reward = 50
		}, 
		quick = {
			unit = "BATTLEDROID B-1 QUICK", 
			health = 325, 
			speed = 4, 
			money_reward = 75
		},
		miniboss = {
			unit = "Tie Interceptor", 
			health = 560, 
			speed = 1.7, 
			money_reward = 150
		},
		boss = {
			unit = "Mayl Phantom Rage", 
			health = 10600, 
			speed = 1.6, 
			money_reward = 1500
		},
	},
	Rewards = {
		Gems = 60,
		Items = {
			["Red Milk"] = 6,
		},
		PlayerExp = 35,
		Credits = math.random(4,8),
		Tower = { unit = "Bob", chance = 2.5 } -- 0.5%
	},
	Rounds = {
		--[[1]]{ wave = { { unit = "normal", amount = 3 } }, wave_reward = 200, wave_diff_scale = 0.5 },
		--[[2]]{ wave = { { unit = "normal", amount = 5 } }, wave_reward = 400, wave_diff_scale = 0.5 },
		--[[3]]{ wave = { { unit = "normal", amount = 4 }, { unit = "strong", amount = 1 } }, wave_reward = 600, wave_diff_scale = 0.5 },
		--[[4]]{ wave = { { unit = "normal", amount = 5 }, { unit = "strong", amount = 2 } }, wave_reward = 750, wave_diff_scale = 0.75 },
		--[[5]]{ wave = { { unit = "normal", amount = 6 }, { unit = "strong", amount = 4 } }, wave_reward = 1000, wave_diff_scale = 0.75 },
		--[[6]]{ wave = { { unit = "tank", amount = 4 } }, wave_reward = 1000, wave_diff_scale = 1 },
		--[[7]]{ wave = { { unit = "normal", amount = 6 }, { unit = "strong", amount = 6 }, { unit = "tank", amount = 4 } }, wave_reward = 1000, wave_diff_scale = 1 },
		--[[8]]{ wave = { { unit = "normal", amount = 6 }, { unit = "strong", amount = 8 }, { unit = "tank", amount = 4 } }, wave_reward = 1250, wave_diff_scale = 1.25 },
		--[[9]]{ wave = { { unit = "normal", amount = 4 }, { unit = "strong", amount = 8 }, { unit = "tank", amount = 6 } }, wave_reward = 1250, wave_diff_scale = 1.5 },
		--[[10]]{ wave = { { unit = "quick", amount = 3 } }, wave_reward = 1250, wave_diff_scale = 2 },
		--[[11]]{ wave = { { unit = "normal", amount = 12 }, { unit = "tank", amount = 6 }, { unit = "quick", amount = 2 } }, wave_reward = 1250, wave_diff_scale = 2 },
		--[[12]]{ wave = { { unit = "normal", amount = 10 }, { unit = "strong", amount = 6 }, { unit = "tank", amount = 4 }, { unit = "quick", amount = 2 } }, wave_reward = 1500, wave_diff_scale = 2.5 },
		--[[13]]{ wave = { { unit = "normal", amount = 11 }, { unit = "strong", amount = 6 }, { unit = "tank", amount = 9 } }, wave_reward = 1500, wave_diff_scale = 3 },
		--[[14]]{ wave = { { unit = "normal", amount = 13 }, { unit = "strong", amount = 9 }, { unit = "tank", amount = 7 }, { unit = "quick", amount = 3 } }, wave_reward = 1500, wave_diff_scale = 3 },
		--[[15]]{ wave = { { unit = "normal", amount = 9 }, { unit = "strong", amount = 12 }, { unit = "tank", amount = 6 }, { unit = "quick", amount = 3 } }, wave_reward = 1500, wave_diff_scale = 3.5 },
		--[[16]]{ wave = { { unit = "normal", amount = 14 }, { unit = "strong", amount = 6 }, { unit = "tank", amount = 13 } }, wave_reward = 1500, wave_diff_scale = 3.5 },
		--[[17]]{ wave = { { unit = "normal", amount = 16 }, { unit = "strong", amount = 10 }, { unit = "tank", amount = 9 } }, wave_reward = 1500, wave_diff_scale = 3.5 },
		--[[18]]{ wave = { { unit = "normal", amount = 17 }, { unit = "strong", amount = 15 }, { unit = "tank", amount = 6 }, { unit = "quick", amount = 9 } }, wave_reward = 1500, wave_diff_scale = 4 },
		--[[19]]	{ wave = { { unit = "normal", amount = 15 }, { unit = "strong", amount = 11 }, { unit = "tank", amount = 13 }, { unit = "quick", amount = 4 } }, wave_reward = 1500, wave_diff_scale = 4 },
		--[[20]]{ wave = { { unit = "normal", amount = 18 }, { unit = "strong", amount = 16 }, { unit = "tank", amount = 14 }, { unit = "quick", amount = 7 } }, wave_reward = 1500, wave_diff_scale = 4 },
		--[[21]]{ wave = { { unit = "normal", amount = 20 }, { unit = "strong", amount = 20 }, { unit = "tank", amount = 12 }, { unit = "quick", amount = 5 } }, wave_reward = 1500, wave_diff_scale = 4.5 },
		--[[22]]	{ wave = { { unit = "normal", amount = 18 }, { unit = "strong", amount = 22 }, { unit = "tank", amount = 12 }, { unit = "quick", amount = 10 } }, wave_reward = 1500, wave_diff_scale = 4.5 },
		--[[23]]{ wave = { { unit = "normal", amount = 14 }, { unit = "strong", amount = 14 }, { unit = "tank", amount = 19 }, { unit = "quick", amount = 12 } }, wave_reward = 1500, wave_diff_scale = 4.5 },
		--[[24]]{ wave = { { unit = "normal", amount = 18 }, { unit = "strong", amount = 18 }, { unit = "tank", amount = 18 }, { unit = "quick", amount = 7 } }, wave_reward = 1500, wave_diff_scale = 4.5 },
		--[[25]]{ wave = { { unit = "tank", amount = 15 }, { unit = "boss", amount = 1, is_boss = true } }, wave_reward = 0, wave_diff_scale = 4.5, boss_wave = true }
	}
}

return module
