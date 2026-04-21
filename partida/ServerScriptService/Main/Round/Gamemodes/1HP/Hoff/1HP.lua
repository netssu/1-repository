local module = {

	initial_money = 1000,
	wave_rest_time = 7,

	EnemyStats = {
		miniboss = {
			unit = "BX",
			health = 2500,
			speed = 1.5,
			money_reward = 300,
		},
		boss = {
			unit = "Tact",
			health = 15000,
			speed = 1.6,
			money_reward = 2200,
		},
		mega_boss = {
			unit = "Wader Last Breath",
			health = 30000,
			speed = 1.4,
			money_reward = 6000,
		},
		support = {
			unit = "Battledroid",
			health = 1000,
			speed = 2.5,
			money_reward = 50,
		}
	},

	Rounds = {
		{ -- Wave 1: Strong open
			wave = {
				{ unit = "miniboss", amount = 4 },
				{ unit = "support",  amount = 2 },
			},
			wave_reward = 600,
			wave_diff_scale = 1.5,
		},

		{ -- Wave 2: Pressure with faster bosses
			wave = {
				{ unit = "miniboss", amount = 5 },
				{ unit = "support",  amount = 3 },
			},
			wave_reward = 800,
			wave_diff_scale = 1.75,
		},

		{ -- Wave 3: First boss encounter
			wave = {
				{ unit = "boss", amount = 1, is_bossrush = true }
			},
			wave_reward = 1000,
			wave_diff_scale = 2.2,
			boss_wave = true,
		},

		{ -- Wave 4: Mix-up of chaos
			wave = {
				{ unit = "miniboss", amount = 3 },
				{ unit = "support",  amount = 2 },
				{ unit = "boss",     amount = 1, is_bossrush = true }
			},
			wave_reward = 1300,
			wave_diff_scale = 2.6,
		},

		{ -- Wave 5: Twin bosses + small support
			wave = {
				{ unit = "boss",     amount = 2, is_bossrush = true },
				{ unit = "support",  amount = 2 }
			},
			wave_reward = 1600,
			wave_diff_scale = 3.1,
			boss_wave = true,
		},

		{ -- Wave 6: Final chaos before finale
			wave = {
				{ unit = "miniboss", amount = 3 },
				{ unit = "boss",     amount = 2, is_bossrush = true },
				{ unit = "support",  amount = 3 },
			},
			wave_reward = 2000,
			wave_diff_scale = 3.7,
		},

		{ -- Wave 7: Final Boss
			wave = {
				{ unit = "mega_boss", amount = 1, is_boss = true },
				{ unit = "support",   amount = 2 },
			},
			wave_reward = 0,
			wave_diff_scale = 4.5,
			boss_wave = true,
		}
	}
}

return module
