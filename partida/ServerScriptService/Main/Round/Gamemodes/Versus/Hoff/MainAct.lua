local module = {

	initial_money = 1000,
	wave_rest_time = 5,
	EnemyStats = {
		normal = { 
			unit = "B1",
			health = 200, 
			speed = 2, 
			money_reward = 60
		}, 
		strong = {
			unit = "SectarianGuard", 
			health = 225, 
			speed = 2, 
			money_reward = 80
		}, 
		debuff = {
			unit = "Battledroid",
			health = 255,
			speed = 2,
			amount = .75, -- amount of debuff multiplied on the player's damage in range.
			money_reward = 90,
		},
		tank = {
			unit = "B2", 
			health = 250, 
			speed = 2, 
			money_reward = 100
		}, 
		quick = {
			unit = "Droideka", 
			health = 240, 
			speed = 4, 
			money_reward = 150
		},
		miniboss = {
			unit = "BX", 
			health = 300, 
			speed = 1.7, 
			money_reward = 300
		},
		boss = {
			unit = "Tact", 
			health = 7000, 
			speed = 1.7, 
			money_reward = 1500
		},

	},
	Rewards = {

		Gems = 140,
		Items = {
			Milk = 2,
		},
		PlayerExp = 75

	},
	Rounds = {
		{

			--[[1]]		wave = { {
				unit = "normal", 
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 0.5
		}, {
			--[[2]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 0.5
		}, {
			--[[3]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 1
				} }, 
			wave_reward = 600, 
			wave_diff_scale = 0.5
		}, {
			--[[4]]		wave = { {
				unit = "normal", 
				amount = 5
			}, {
					unit = "strong", 
					amount = 2
				} }, 
			wave_reward = 750, 
			wave_diff_scale = 0.5
		}, {
			--[[5]]		wave = { {
				unit = "miniboss", 
				amount = 1
			}, {
					unit = "strong", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 1.0
		}, {
			--[[6]]		wave = { {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 1
		}, {
			--[[7]]		wave = { {
				unit = "normal", 
				amount = 6
			}, {
					unit = "strong", 
					amount = 6
				}, {
					unit = "tank", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 1.0
		}, {
			--[[8]]		wave = { {
				unit = "normal", 
				amount = 6
			}, {
					unit = "strong", 
					amount = 8
				}, {
					unit = "tank", 
					amount = 4
				} }, 
			wave_reward = 1250, 
			wave_diff_scale = 1.0
		}, {
			--[[9]]		wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 8
				}, {
					unit = "tank", 
					amount = 6
				} }, 
			wave_reward = 1250, 
			wave_diff_scale = 1.0
		}, {
			--[[10]]			wave = { {
				unit = "tank", 
				amount = 6
			}, {
					unit = "boss", 
					amount = 1, 
					is_boss = true
				} }, 
			wave_reward = 0, 
			wave_diff_scale = 1.5, 
			boss_wave = true
		}, {

			--[[11]]		wave = { {
				unit = "normal", 
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 1.5
		}, {
			--[[12]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 1.5
		}, {
			--[[13]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 1
				} }, 
			wave_reward = 600, 
			wave_diff_scale = 1.5
		}, {
			--[[14]]			wave = { {
				unit = "normal", 
				amount = 5
			}, {
					unit = "strong", 
					amount = 2
				} }, 
			wave_reward = 750, 
			wave_diff_scale = 1.5
		}, {
			--[[15]]		wave = { {
				unit = "miniboss", 
				amount = 1
			}, {
					unit = "strong", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 1.5
		}, {
			--[[16]]		wave = { {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 2.0
		}, {
			--[[17]]		wave = { {
				unit = "normal", 
				amount = 6
			}, {
					unit = "strong", 
					amount = 6
				}, {
					unit = "tank", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 2.0
		}, {
			--[[18]]		wave = { {
				unit = "normal", 
				amount = 6
			}, {
					unit = "strong", 
					amount = 8
				}, {
					unit = "tank", 
					amount = 4
				} }, 
			wave_reward = 1250, 
			wave_diff_scale = 2.0
		}, {
			--[[19]]		wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 8
				}, {
					unit = "tank", 
					amount = 6
				} }, 
			wave_reward = 1250, 
			wave_diff_scale = 2.00
		}, {
			--[[20]]			wave = { {
				unit = "tank", 
				amount = 6
			}, {
					unit = "boss", 
					amount = 1, 
					is_boss = true
				} }, 
			wave_reward = 0, 
			wave_diff_scale = 2.0, 
			boss_wave = true
		}, {

			--[[21]]		wave = { {
				unit = "normal", 
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 3.0
		}, {
			--[[22]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 3.0
		}, {
			--[[23]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 1
				} }, 
			wave_reward = 600, 
			wave_diff_scale = 3.0
		}, {
			--[[24]]		wave = { {
				unit = "normal", 
				amount = 5
			}, {
					unit = "strong", 
					amount = 2
				} }, 
			wave_reward = 750, 
			wave_diff_scale = 3.0
		}, {
			--[[25]]		wave = { {
				unit = "miniboss", 
				amount = 1
			}, {
					unit = "strong", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 3.5
		}, {
			--[[26]]		wave = { {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 3.5
		}, {
			--[[27]]		wave = { {
				unit = "normal", 
				amount = 6
			}, {
					unit = "strong", 
					amount = 6
				}, {
					unit = "tank", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 3.5
		}, {
			--[[28]]		wave = { {
				unit = "normal", 
				amount = 6
			}, {
					unit = "strong", 
					amount = 8
				}, {
					unit = "tank", 
					amount = 4
				} }, 
			wave_reward = 1250, 
			wave_diff_scale = 3.5
		}, {
			--[[29]]		wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 8
				}, {
					unit = "tank", 
					amount = 6
				} }, 
			wave_reward = 1250, 
			wave_diff_scale = 3.5
		}, {
			--[[30]]			wave = { {
				unit = "tank", 
				amount = 6
			}, {
					unit = "boss", 
					amount = 1, 
					is_boss = true
				} }, 
			wave_reward = 0, 
			wave_diff_scale = 3.5, 
			boss_wave = true
		}, {

			--[[31]]		wave = { {
				unit = "normal", 
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 4.0
		}, {
			--[[32]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 4.0
		}, {
			--[[33]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 1
				} }, 
			wave_reward = 600, 
			wave_diff_scale = 4.0
		}, {
			--[[34]]		wave = { {
				unit = "normal", 
				amount = 5
			}, {
					unit = "strong", 
					amount = 2
				} }, 
			wave_reward = 750, 
			wave_diff_scale = 4.0
		}, {
			--[[35]]		wave = { {
				unit = "miniboss", 
				amount = 1
			}, {
					unit = "strong", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 4.5
		}, {
			--[[36]]		wave = { {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 4.5
		}, {
			--[[37]]		wave = { {
				unit = "normal", 
				amount = 6
			}, {
					unit = "strong", 
					amount = 6
				}, {
					unit = "tank", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 4.5
		}, {
			--[[38]]		wave = { {
				unit = "normal", 
				amount = 6
			}, {
					unit = "strong", 
					amount = 8
				}, {
					unit = "tank", 
					amount = 4
				} }, 
			wave_reward = 1250, 
			wave_diff_scale = 4.5
		}, {
			--[[39]]		wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 8
				}, {
					unit = "tank", 
					amount = 6
				} }, 
			wave_reward = 1250, 
			wave_diff_scale = 4.5
		}, {
			--[[40]]			wave = { {
				unit = "tank", 
				amount = 6
			}, {
					unit = "boss", 
					amount = 1, 
					is_boss = true
				} }, 
			wave_reward = 0, 
			wave_diff_scale = 5.0, 
			boss_wave = true
		}, {

			--[[41]]		wave = { {
				unit = "normal", 
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 5.0
		}, {
			--[[42]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 5.0
		}, {
			--[[43]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 1
				} }, 
			wave_reward = 600, 
			wave_diff_scale = 5.0
		}, {
			--[[44]]		wave = { {
				unit = "normal", 
				amount = 5
			}, {
					unit = "strong", 
					amount = 2
				} }, 
			wave_reward = 750, 
			wave_diff_scale = 5.0
		}, {
			--[[45]]		wave = { {
				unit = "miniboss", 
				amount = 1
			}, {
					unit = "strong", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 5.5
		}, {
			--[[46]]		wave = { {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 5.5
		}, {
			--[[47]]		wave = { {
				unit = "normal", 
				amount = 6
			}, {
					unit = "strong", 
					amount = 6
				}, {
					unit = "tank", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 5.5
		}, {
			--[[48]]		wave = { {
				unit = "normal", 
				amount = 6
			}, {
					unit = "strong", 
					amount = 8
				}, {
					unit = "tank", 
					amount = 4
				} }, 
			wave_reward = 1250, 
			wave_diff_scale = 5.5
		}, {
			--[[49]]		wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 8
				}, {
					unit = "tank", 
					amount = 6
				} }, 
			wave_reward = 1250, 
			wave_diff_scale = 7.5
		}, {
			--[[50]]			wave = { {
				unit = "tank", 
				amount = 6
			}, {
					unit = "boss", 
					amount = 1, 
					is_boss = true
				} }, 
			wave_reward = 0, 
			wave_diff_scale = 8.5, 
			boss_wave = true
		}
	}
}




return module
