------------------//CONSTANTS
local QuestConfig = {
	QUESTS_PER_DAY = 4,
	RESET_HOUR = 0,

	TYPES = {
		["Jump"] = {
			Title = "Jumper",
			Description = "Perform <font color='#FFFFFF'><b>%s</b></font> Jumps",
			ImageId = "rbxassetid://107760716240538",
			WatchPath = "Stats.TotalJumps",
			InteractionType = "Increment",
			Range = NumberRange.new(20, 100),
			RewardPerUnit = 100
		},

		["BuyPogo"] = {
			Title = "Pogo Collector",
			Description = "Buy <font color='#FFFFFF'><b>%s</b></font> Pogo(s)",
			ImageId = "rbxassetid://71733197014336",
			WatchPath = "OwnedPogos",
			InteractionType = "TableCount",
			Range = NumberRange.new(1, 3),
			RewardPerUnit = 2000
		},

		["Combo"] = {
			Title = "Combo Master",
			Description = "Reach a <font color='#FFFFFF'><b>%s</b></font>x Combo",
			ImageId = "rbxassetid://91594332851556",
			WatchPath = "Stats.HighestCombo",
			InteractionType = "Threshold",
			Range = NumberRange.new(5, 20),
			RewardPerUnit = 1000
		},

		["CollectCoins"] = {
			Title = "Coin Collector",
			Description = "Collect <font color='#FFFFFF'><b>%s</b></font> Coins",
			ImageId = "rbxassetid://82346463581106",
			WatchPath = "Coins",
			InteractionType = "Increment",
			Range = NumberRange.new(500, 5000),
			RewardPerUnit = 10
		},

		["PlayTime"] = {
			Title = "Active Player",
			Description = "Play for <font color='#FFFFFF'><b>%s</b></font> minutes",
			ImageId = "rbxassetid://84875607425216",
			WatchPath = "Stats.PlayTime",
			InteractionType = "Threshold",
			Range = NumberRange.new(5, 30),
			RewardPerUnit = 1000
		},
	}
}

return QuestConfig