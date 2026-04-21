local module = {
	{
		text = "Welcome to Galaxy Defenders! Before joining the fight you need someone on your team.",
		waitFor = "Continue",
		index = 1,
	},
	{
		text = "Click on summon to get someone to join your team!",
		waitFor = "SummonButton",
		index = 2,
	},
	{
		text = "Click Summon 10x to see who you get!",
		waitFor = "SummonUnit",
		index = 3
	},
	{
		text = '',
		waitFor = "ExitSummonArea",
		index = 4,
	},
	{
		text = "Now equip your new units and add them to the team!",
		waitFor = "EquipUnit",
		index = 5
	},
	{
		text = "Select the unit you want to equip and click equip!",
		waitFor = 'WaitForEquipUnit',
		index = 6,
	},
	{
		text = "Close your inventory!",
		waitFor = 'CloseMenu',
		index = 7
	},
	{
		text = "Press the PLAY button to join the fight",
		waitFor = "PlayButton",
		index = 8
	},
	{
		text = "Walk into the entry in front of you",
		waitFor = "Elevator",
		index = 9
	},
	{
		text = "Press play and wait for the fight to start!",
		waitFor = "FinalPlay",
		index = 10
	},
	{
		text = "Now you just wait a few seconds to start your adventure, or you could press Quick Start if you don't want to wait!",
		waitFor = "Finished",
		index = 11
	}
}

return module
