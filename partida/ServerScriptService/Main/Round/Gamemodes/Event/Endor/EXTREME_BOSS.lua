local module = {

	initial_money = 99999999999,
	wave_rest_time = 7,
	EnemyStats = {
		boss = {
			unit = "Fawn", -- Assume you have this or make it
			health = 90000000,
			speed = 0.6,
			money_reward = 5000,
		}
	},

	Rounds = {
		{ -- Wave 1: Warmup minibosses
			wave = { { unit = "boss", amount = 1, is_boss = true } },
			wave_reward = 500,
			wave_diff_scale = 1.2
		},
	}
}

return module
