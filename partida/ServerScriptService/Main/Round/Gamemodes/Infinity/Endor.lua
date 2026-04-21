local module = {

	initial_money = 625, -- slightly increased again
	wave_rest_time = 5,
	ItemReward = "Purple Milk",
	EnemyStats = {
		normal = { 
			unit = "Soldier",
			health = 200,    -- was 180
			speed = 2.3,     -- was 2.2
			money_reward = 50 -- was 45
		}, 
		strong = {
			unit = "Stronger", 
			health = 215,    -- was 190
			speed = 2.3,
			money_reward = 60 -- was 55
		}, 
		tank = {
			unit = "Tank", 
			health = 240,    -- was 210
			speed = 1.75,    -- slightly slower
			money_reward = 75 -- was 65
		}, 
		quick = {
			unit = "BATTLEDROID B-1 QUICK", 
			health = 200,    -- was 185
			speed = 4.75,    -- was 4.5
			money_reward = 105 -- was 95
		},
		miniboss = {
			unit = "Tie Interceptor", 
			health = 350,    -- was 320
			speed = 2.0,     -- was 1.9
			money_reward = 200 -- was 180
		},

		boss1 = {
			unit = "Dart Mayl", 
			health = 6100,   -- was 5800
			speed = 2,
			money_reward = 2000 -- was 1900
		},
		boss2 = {
			unit = "Anikan Skaivoker", 
			health = 6250, 
			speed = 1.7,
			money_reward = 2000
		},
		boss3 = {
			unit = "Mayl Phantom Rage", 
			health = 6400, 
			speed = 1.6,
			money_reward = 2000
		},
		boss4 = {
			unit = "Dark Overlord", 
			health = 6100, 
			speed = 1.9,
			money_reward = 2000
		},
		boss5 = {
			unit = "Wader Last Breath", 
			health = 7100,   -- was 6700
			speed = 1.45,    -- slightly faster than before
			money_reward = 2100 -- was 1950
		},
	},
	Rewards = {

	},
	Rounds = {

	}
}

return module
