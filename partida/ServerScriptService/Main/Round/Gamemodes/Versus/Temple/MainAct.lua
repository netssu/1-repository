local module = {

	initial_money = 1000,
	wave_rest_time = 5,
	EnemyStats = {
		normal = { 
			unit = "B1",
			health = 150, 
			speed = 2, 
			money_reward = 60
		}, 
		strong = {
			unit = "SectarianGuard", 
			health = 175, 
			speed = 2, 
			money_reward = 80
		}, 
		debuff = {
			unit = "Battledroid",
			health = 205,
			speed = 2,
			amount = .75, -- amount of debuff multiplied on the player's damage in range.
			money_reward = 90,
		},
		tank = {
			unit = "B2", 
			health = 200, 
			speed = 2, 
			money_reward = 100
		}, 
		quick = {
			unit = "Droideka", 
			health = 190, 
			speed = 4, 
			money_reward = 150
		},
		miniboss = {
			unit = "BX", 
			health = 250, 
			speed = 1.7, 
			money_reward = 300
		},
		boss = {
			unit = "Tact", 
			health = 5000, 
			speed = 1.7, 
			money_reward = 1500
		},

	},
	Rewards = {
		
		Gems = 100,
		Items = {
			Milk = 2,
		},
		PlayerExp = 50

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
			wave_diff_scale = 0.6
		}, {
--[[3]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
				unit = "strong", 
				amount = 1
			} }, 
			wave_reward = 600, 
			wave_diff_scale = 0.7
		}, {
--[[4]]		wave = { {
				unit = "normal", 
				amount = 5
			}, {
				unit = "strong", 
				amount = 2
			} }, 
			wave_reward = 750, 
			wave_diff_scale = 0.75
		}, {
--[[5]]		wave = { {
				unit = "miniboss", 
				amount = 1
			}, {
				unit = "strong", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 0.8
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
			wave_diff_scale = 1
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
			wave_diff_scale = 0.5
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
			wave_diff_scale = 0.75
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
			wave_diff_scale = 1.0, 
			boss_wave = true
		}, {
--[[11]]		wave = { {
				unit = "normal", 
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 1.0
		}, {
--[[12]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 1.0
		}, {
--[[13]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 1
				} }, 
			wave_reward = 600, 
			wave_diff_scale = 1.25
		}, {
--[[14]]		wave = { {
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
			wave_diff_scale = 1.75
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
			wave_diff_scale = 1.75
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
			wave_diff_scale = 1.75
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
			wave_diff_scale = 1.75
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
			wave_diff_scale = 2.0
		}, {
--[[22]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 2.0
		}, {
--[[23]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 1
				} }, 
			wave_reward = 600, 
			wave_diff_scale = 2.0
		}, {
--[[24]]		wave = { {
				unit = "normal", 
				amount = 5
			}, {
					unit = "strong", 
					amount = 2
				} }, 
			wave_reward = 750, 
			wave_diff_scale = 2.00
		}, {
--[[25]]		wave = { {
				unit = "miniboss", 
				amount = 1
			}, {
					unit = "strong", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 2.5
		}, {
--[[26]]		wave = { {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 2.5
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
			wave_diff_scale = 2.5
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
			wave_diff_scale = 2.5
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
			wave_diff_scale = 2.5
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
			wave_diff_scale = 3.0, 
			boss_wave = true
		}, {
--[[31]]		wave = { {
				unit = "normal", 
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 3.0
		}, {
--[[32]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 3.0
		}, {
--[[33]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 1
				} }, 
			wave_reward = 600, 
			wave_diff_scale = 3.0
		}, {
--[[34]]		wave = { {
				unit = "normal", 
				amount = 5
			}, {
					unit = "strong", 
					amount = 2
				} }, 
			wave_reward = 750, 
			wave_diff_scale = 3.0
		}, {
--[[35]]		wave = { {
				unit = "miniboss", 
				amount = 1
			}, {
					unit = "strong", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 3.5
		}, {
--[[36]]		wave = { {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 3.5
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
			wave_diff_scale = 3.5
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
			wave_diff_scale = 3.5
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
			wave_diff_scale = 3.5
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
			wave_diff_scale = 4.0, 
			boss_wave = true
		}, {
--[[41]]		wave = { {
				unit = "normal", 
				amount = 3,
			}, }, 
			wave_reward = 200, 
			wave_diff_scale = 4.0
		}, {
--[[42]]		wave = { {
				unit = "normal", 
				amount = 5
			} }, 
			wave_reward = 400, 
			wave_diff_scale = 4.0
		}, {
--[[43]]			wave = { {
				unit = "normal", 
				amount = 4
			}, {
					unit = "strong", 
					amount = 1
				} }, 
			wave_reward = 600, 
			wave_diff_scale = 4.0
		}, {
--[[44]]		wave = { {
				unit = "normal", 
				amount = 5
			}, {
					unit = "strong", 
					amount = 2
				} }, 
			wave_reward = 750, 
			wave_diff_scale = 4.0
		}, {
--[[45]]		wave = { {
				unit = "miniboss", 
				amount = 1
			}, {
					unit = "strong", 
					amount = 4
				} }, 
			wave_reward = 1000, 
			wave_diff_scale = 4.5
		}, {
--[[46]]		wave = { {
				unit = "tank", 
				amount = 4
			} }, 
			wave_reward = 1000, 
			wave_diff_scale = 4.5
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
			wave_diff_scale = 4.5
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
			wave_diff_scale = 4.5
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
			wave_diff_scale = 5.25
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
			wave_diff_scale = 7.5, 
			boss_wave = true
		}
	}
}





return module
