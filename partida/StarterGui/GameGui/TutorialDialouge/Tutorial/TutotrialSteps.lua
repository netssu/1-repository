local players = game:GetService('Players')
local repStorage = game:GetService('ReplicatedStorage')

local player = players.LocalPlayer

local trackedTowers = {}

local module = {
	{
		text = "You can vote to start. make the game quicker by pressing Speed: 1x",
		waitFor = "WaveStart",
		index = 1,
	},
	{
		text = "Place 3 units to defend your base",
		waitFor = "TowersPlaced",
		index = 2,
	},
	{
		text = "Upgrade 1 of your units to make them stronger",
		waitFor = "TowerUpgraded",
		index = 3
	},
	{
		text = "You're ready to defend! Get to wave 10!",
		waitFor = "Boss",
		index = 4,
	},
	{
		text = "Now watch your towers decimate the boss!",
		waitFor = "Defeated",
		index = 5,
	},
	{
		text = "Great job in defeating your first round! That concludes our tutorial! Have fun.",
		waitFor = "Finished",
		index = 6
	},
}

return module
