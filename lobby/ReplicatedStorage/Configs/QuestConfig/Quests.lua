return  {
	--General

	ClearWaves = {
		Group = {"Daily", "Weekly", "Battlepass"},
		Name = "Clear Waves",
		Desc = "Clear a number of waves in any game mode.",
		GoalRange = {
			Daily = {min = 25, max = 50},
			Weekly = {min = 100, max = 150},
			Battlepass = {min = 25, max = 50},
		},
		RewardMultiplier = {
			Daily = 1,
			Weekly = 1.5,
			Battlepass = 1,
		},
		RewardCalc = function(goal, multiplier, group)
			multiplier = multiplier or 1
			local rewards = {
				Gems = goal * 4 * multiplier,
			}
			
			local expFormula = goal * 4 * multiplier

			if group == "Battlepass" then
				rewards.Exp = expFormula
			else
				rewards.PlayerExp = expFormula
			end

			return rewards
		end,
	},


	ClearWavesMultiplayer = {
		Group = {"Daily", "Weekly", "Battlepass"},
		Name = "Clear Waves Multiplayer",
		Desc = "Clear a number of waves in any game mode with a friend.",
		GoalRange = {
			Daily = {min = 15, max = 30},
			Weekly = {min = 75, max = 100},
			Battlepass = {min = 15, max = 30},
		},
		RewardMultiplier = {
			Daily = 1,
			Weekly = 2,
			Battlepass = 1,
		},
		RewardCalc = function(goal, multiplier, group)
			multiplier = multiplier or 1
			local rewards = {
				Gems = goal * 5 * multiplier,
			}
			
			local expFormula = goal * 5 * multiplier
			
			if group == "Battlepass" then
				rewards.Exp = expFormula
			else
				rewards.PlayerExp = expFormula
			end

			return rewards
		end,
	},

	InfiniteWaves = {
		Group = {"Daily", "Weekly", "Battlepass"},
		Name = "Complete Infinite Waves",
		Desc = "Survive waves in Infinite Mode.",
		GoalRange = {
			Daily = {min = 25, max = 100},
			Weekly = {min = 100, max = 200},
			Battlepass = {min = 25, max = 100},
		},
		RewardMultiplier = {
			Daily = 1,
			Weekly = 2,
			Battlepass = 1,
		},
		RewardCalc = function(goal, multiplier, group)
			multiplier = multiplier or 1
			local rewards = {
				Gems = goal * 5 * multiplier,
			}

			local expFormula = goal * 5 * multiplier

			if group == "Battlepass" then
				rewards.Exp = expFormula
			else
				rewards.PlayerExp = expFormula
			end

			return rewards
		end,
	},

	KillEnemies = {
		Group = {"Daily", "Weekly", "Battlepass"},
		Name = "Defeat Enemies",
		Desc = "Defeat enemies of any kind.",
		GoalRange = {
			Daily = {min = 1500, max = 5000},
			Weekly = {min = 10000, max = 20000},
			Battlepass = {min = 1500, max = 5000},
		},
		RewardMultiplier = {
			Daily = 1,
			Weekly = 2,
			Battlepass = 1,
		},
		RewardCalc = function(goal, multiplier, group)
			multiplier = multiplier or 1
			local rewards = {
				Gems = math.floor((goal / 7.5) * multiplier),
			}

			local expFormula = math.floor((goal / 8) * multiplier)

			if group == "Battlepass" then
				rewards.Exp = expFormula
			else
				rewards.PlayerExp = expFormula
			end

			return rewards
		end,
	},

	ClearActs = {
		Group = {"Daily", "Weekly", "Battlepass"},
		Name = "Clear Acts",
		Desc = "Successfully clear any act(s) of your choice.",
		GoalRange = {
			Daily = {min = 5, max = 15},
			Weekly = {min = 25, max = 40},
			Battlepass = {min = 5, max = 15},
		},
		RewardMultiplier = {
			Daily = 1,
			Weekly = 2,
			Battlepass = 1,
		},
		RewardCalc = function(goal, multiplier, group)
			multiplier = multiplier or 1
			local rewards = {
				Gems = goal * 6 * multiplier,
			}

			local expFormula = goal * 6 * multiplier

			if group == "Battlepass" then
				rewards.Exp = expFormula
			else
				rewards.PlayerExp = expFormula
			end

			return rewards
		end,
	},

	PlaceUnits = {
		Group = {"Daily", "Weekly", "Battlepass"},
		Name = "Place Units",
		Desc = "Place any unit of your choice.",
		GoalRange = {
			Daily = {min = 25, max = 75},
			Weekly = {min = 150, max = 200},
			Battlepass = {min = 25, max = 75},
		},
		RewardMultiplier = {
			Daily = 1,
			Weekly = 2,
			Battlepass = 1,
		},
		RewardCalc = function(goal, multiplier, group)
			multiplier = multiplier or 1
			local rewards = {
				Gems = goal * 6 * multiplier,
			}

			local expFormula = math.floor(goal * 3 * multiplier)

			if group == "Battlepass" then
				rewards.Exp = expFormula
			else
				rewards.PlayerExp = expFormula
			end

			return rewards
		end,
	},

	KillStoryBosses = {
		Group = {"Daily", "Weekly", "Battlepass"},
		Name = "Defeat Bosses",
		Desc = "Defeat bosses from STORY.",
		GoalRange = {
			Daily = {min = 5, max = 10},
			Weekly = {min = 75, max = 100},
			Battlepass = {min = 5, max = 10},
		},
		RewardMultiplier = {
			Daily = 1,
			Weekly = 2,
			Battlepass = 1,
		},
		RewardCalc = function(goal, multiplier, group)
			multiplier = multiplier or 1
			local rewards = {
				Gems = goal * 6 * multiplier,
			}

			local expFormula = goal * 6 * multiplier

			if group == "Battlepass" then
				rewards.Exp = expFormula
			else
				rewards.PlayerExp = expFormula
			end

			return rewards
		end,
	},

	--Story

	ClearWorldsEasyQuestline = {
		Part = 1,
		Group = {"Story"},
		Name = "Clear Worlds",
		Desc = "Progress through the story by clearing different worlds on easy mode.",
		Parts = {
			[1] = {
				Name = "Clear World 1 (Easy)",
				Goal = 5,
				RewardCalc = function()
					return {
						PlayerExp = 250,
						Gems = 100,
					}
				end,
			},
			[2] = {
				Name = "Clear World 2 (Easy)",
				Goal = 3,
				RewardCalc = function()
					return {
						PlayerExp = 500,
						Gems = 200,
					}
				end,
			},
			[3] = {
				Name = "Clear World 3 (Easy)",
				Goal = 5,
				RewardCalc = function()
					return {
						PlayerExp = 750,
						Gems = 300,
					}
				end,
			},
		},
	},

	-- Infinite
	
	ClearInfinite = {
		Name = "Clear Infinite Waves",
		Group = {"Infinite"},
		Desc = "Clear waves in infinite game mode (any map)",
		GoalIncrement = 5,
		Goal = 5,
		RewardCalc = function(goal)
			return {
				PlayerExp = goal * 6,
				Gems = goal * 6,
			}
		end,
	}
}
