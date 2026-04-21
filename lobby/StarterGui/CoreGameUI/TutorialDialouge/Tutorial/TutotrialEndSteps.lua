local module = {
	{
		text = "Good job winning your first game! You've gotten some gems in your balance now. Click on 'Summon' to get your second unit!",
		waitFor = "Summon2",
		index = 1,
	},
	{
		text = "Okay! Now, click on the 'Summon 1X' and let's see what unit you got!",
		waitFor = "SummonUnit2",
		index = 2,
	},
	{
		text = "Great! With these units now, you'll be able to tackle this game with no problem! That concludes our tutorial.",
		waitFor = "Finished",
		index = 3
	},
}

return module
