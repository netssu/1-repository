local module = {

	initial_money = 1000,
	wave_rest_time = 7,
	EnemyStats = {
		miniboss = {
			unit = "BX",
			health = 250,
			speed = 1.5,
			money_reward = 300,
		},
		boss = {
			unit = "Tact",
			health = 1000,
			speed = 1.7,
			money_reward = 2000,
		},
		mega_boss = {
			unit = "Wader Last Breath", -- Assume you have this or make it
			health = 2500,
			speed = 1.5,
			money_reward = 5000,
		}
	},

	Rounds = {
		{ -- Wave 1: Warmup minibosses
			wave = { { unit = "miniboss", amount = 5 } },
			wave_reward = 500,
			wave_diff_scale = 1.2
		},
		{ -- Wave 2: More minibosses
			wave = { { unit = "miniboss", amount = 6 } },
			wave_reward = 800,
			wave_diff_scale = 1.5
		},
		{ -- Wave 3: One real boss
			wave = { { unit = "boss", amount = 2, is_bossrush = true } },
			wave_reward = 1200,
			wave_diff_scale = 2,
			boss_wave = true
		},
		{ -- Wave 4: Miniboss mix with a boss
			wave = {
				{ unit = "miniboss", amount = 3 },
				{ unit = "boss", amount = 1, is_bossrush = true }
			},
			wave_reward = 1500,
			wave_diff_scale = 2.5
		},
		{ -- Wave 5: Dual bosses
			wave = { { unit = "boss", amount = 2, is_bossrush = true } },
			wave_reward = 1800,
			wave_diff_scale = 3,
			boss_wave = true
		},
		{ -- Wave 6: Chaos – 3 minibosses + 2 bosses
			wave = {
				{ unit = "miniboss", amount = 3 },
				{ unit = "boss", amount = 2, is_bossrush = true }
			},
			wave_reward = 2500,
			wave_diff_scale = 3.5
		},
		{ -- Wave 7: Final boss – Mega Boss
			wave = {
				{ unit = "mega_boss", amount = 1, is_boss = true }
			},
			wave_reward = 0, -- Final wave
			wave_diff_scale = 4,
			boss_wave = true
		}
	}
}

return module
