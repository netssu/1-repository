local module = {

	initial_money = 600, -- slightly increased
	wave_rest_time = 5,
	ItemReward = "Purple Milk",
	EnemyStats = {
		normal = { 
			unit = "Soldier",
			health = 180,  -- was 165
			speed = 2.2,   -- was 2
			money_reward = 45 -- was 40
		}, 
		strong = {
			unit = "Stronger", 
			health = 190,  -- was 175
			speed = 2.2,
			money_reward = 55 -- was 50
		}, 
		tank = {
			unit = "Tank", 
			health = 210, -- was 185
			speed = 1.8,  -- slightly slower but tankier
			money_reward = 65 -- was 60
		}, 
		quick = {
			unit = "BATTLEDROID B-1 QUICK", 
			health = 185, -- was 170
			speed = 4.5,  -- was 4
			money_reward = 95 -- was 85
		},
		miniboss = {
			unit = "Tie Interceptor", 
			health = 320, -- was 295
			speed = 1.9,  -- was 1.7
			money_reward = 180 -- was 160
		},

		boss1 = {
			unit = "Dart Mayl", 
			health = 5800, -- was 5450
			speed = 2,
			money_reward = 1900 -- was 1750
		},
		boss2 = {
			unit = "Anikan Skaivoker", 
			health = 5950, 
			speed = 1.7,
			money_reward = 1900
		},
		boss3 = {
			unit = "Mayl Phantom Rage", 
			health = 6100, 
			speed = 1.6,
			money_reward = 1900
		},
		boss4 = {
			unit = "Dark Overlord", 
			health = 5800, 
			speed = 1.9,
			money_reward = 1900
		},
		boss5 = {
			unit = "Wader Last Breath", 
			health = 6700, -- was 6250
			speed = 1.4,
			money_reward = 1950
		},
	},
	Rewards = {

	},
	Rounds = {

	}
}

return module
