local module = {
	initial_money = 1000,
	wave_rest_time = 5,
	EnemyStats = {
		normal = { 
			unit = "B1",
			health = 100, 
			speed = 2, 
			money_reward = 60
		}, 
		strong = {
			unit = "SectarianGuard", 
			health = 125, 
			speed = 2, 
			money_reward = 80
		}, 
		debuff = {
			unit = "Battledroid",
			health = 155,
			speed = 2,
			amount = .75, -- amount of debuff multiplied on the player's damage in range.
			money_reward = 90,
		},
		tank = {
			unit = "B2", 
			health = 150, 
			speed = 2, 
			money_reward = 100
		}, 
		quick = {
			unit = "Droideka", 
			health = 140, 
			speed = 4, 
			money_reward = 150
		},
		miniboss = {
			unit = "BX", 
			health = 175, 
			speed = 1.7, 
			money_reward = 300
		},
		boss = {
			unit = "Tact", 
			health = 3000, 
			speed = 1.7, 
			money_reward = 1500
		},

	},
	Rewards = {

		Gems = 60,
		Items = {
			Milk = 2,
		},
		PlayerExp = 25

	},
	Rounds = {
		{

			--[[1]]		wave = { {
				unit = "normal", 
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 0.2
		}, {
			--[[2]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 0.4
		}, {
			--[[3]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 2
			} }, 
			wave_reward = 600, 
			wave_diff_scale = 0.6
		}, {
			--[[4]]		wave = { {
				unit = "normal", 
				amount = 5
			}, {
					unit = "strong", 
					amount = 2
				} }, 
			wave_reward = 750, 
			wave_diff_scale = 0.8
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
			wave_diff_scale = 1.2
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
			wave_diff_scale = 1.4
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
			wave_diff_scale = 1.6
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
			wave_diff_scale = 1.8
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
			wave_diff_scale = 2, 
			boss_wave = true
		}, {

			--[[11]]		wave = { {
				unit = "normal", 
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 2.2
		}, {
			--[[12]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 2.4
		}, {
			--[[13]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 1
				} }, 
			wave_reward = 600, 
			wave_diff_scale = 2.6
		}, {
			--[[14]]		wave = { {
				unit = "normal", 
				amount = 5
			}, {
					unit = "strong", 
					amount = 2
				} }, 
			wave_reward = 750, 
			wave_diff_scale = 2.8
		}, {
			--[[15]]		wave = { {
				unit = "miniboss", 
				amount = 1
			}, {
					unit = "strong", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 3.0
		}, {
			--[[16]]		wave = { {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 3.2
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
			wave_diff_scale = 3.4
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
			wave_diff_scale = 3.6
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
			wave_diff_scale = 3.8
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
			wave_diff_scale = 4.0, 
			boss_wave = true
		}, {

			--[[21]]		wave = { {
				unit = "normal", 
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 4.5
		}, {
			--[[22]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 4.5
		}, {
			--[[23]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 1
				} }, 
			wave_reward = 600, 
			wave_diff_scale = 4.5
		}, {
			--[[24]]		wave = { {
				unit = "normal", 
				amount = 5
			}, {
					unit = "strong", 
					amount = 2
				} }, 
			wave_reward = 750, 
			wave_diff_scale = 4.75
		}, {
			--[[25]]		wave = { {
				unit = "miniboss", 
				amount = 1
			}, {
					unit = "strong", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 5
		}, {
			--[[26]]		wave = { {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 5
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
			wave_diff_scale = 5
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
			wave_diff_scale = 5
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
			wave_diff_scale = 5
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
			wave_diff_scale = 5, 
			boss_wave = true
		}, {
			--[[31]]		wave = { {
				unit = "normal", 
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 5
		}, {
			--[[32]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 5
		}, {
			--[[33]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 1
				} }, 
			wave_reward = 600, 
			wave_diff_scale = 5
		}, {
			--[[34]]		wave = { {
				unit = "normal", 
				amount = 5
			}, {
					unit = "strong", 
					amount = 2
				} }, 
			wave_reward = 750, 
			wave_diff_scale = 5
		}, {
			--[[35]]		wave = { {
				unit = "miniboss", 
				amount = 1
			}, {
					unit = "strong", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 5
		}, {
			--[[36]]		wave = { {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 5.2
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
			wave_diff_scale = 5.4
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
			wave_diff_scale = 5.6
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
			wave_diff_scale = 5.8
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
			wave_diff_scale = 6, 
			boss_wave = true
		}, {
			--[[41]]		wave = { {
				unit = "normal", 
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 6.2
		}, {
			--[[42]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 6.4
		}, {
			--[[43]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 1
				} }, 
			wave_reward = 600, 
			wave_diff_scale = 6.6
		}, {
			--[[44]]		wave = { {
				unit = "normal", 
				amount = 5
			}, {
					unit = "strong", 
					amount = 2
				} }, 
			wave_reward = 750, 
			wave_diff_scale = 6.8
		}, {
			--[[45]]		wave = { {
				unit = "miniboss", 
				amount = 1
			}, {
					unit = "strong", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 7
		}, {
			--[[46]]		wave = { {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 8
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
			wave_diff_scale = 9
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
			wave_diff_scale = 10
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
			wave_diff_scale = 12
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
			wave_diff_scale = 15, 
			boss_wave = true
		}
	}
}



return module
