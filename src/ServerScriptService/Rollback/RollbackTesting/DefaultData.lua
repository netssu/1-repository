


return {
	RaidReset = '1',
	FirstTime = true,
	ActiveBoosts = {},
	["Day"] = 1,
	["TimeAtLastClaim"] = 0,
	["Codes"] = {},
	["Coins"] = 0,
	["Gems"] = 350,
	["TraitPoint"] = 0,
	["MaxUnits"] = 100,
	["ClaimedGroupReward"] = false,
	["UpdateVersion"] = "",
	CurrentDay = 1,
	CurrentWeek = 0,
	DailyStats = {
		["Damage"] = 0,
		["Waves"] = 0,
		["Kills"] = 0,
		StoryQuest = 0,
		["InfReachWaves"] = 0,
	},
	WeeklyStats = {
		["SummonWeekly"] = 0,
		["KillsWeekly"] = 0,
	},
	RaidData = require(script.RaidConfig), -- Raid Data,
	EventData = require(script.EventConfig),
	QuestsData = {
		UniqueQuestsCompleted = {},	--use QuestID
		Quests = {},
		LastDailyQuestTime = 0,
		LastWeeklyQuestTime = 0
	},
	AchievementsData = {
		Achievements = {},
		Themes = {}
	},
	Buffs = {},
	StoryProgress = {
		World = 1,
		Level = 1
	},
	WorldStats = {},
	["PlayerExp"] = 0,
	["PlayerLevel"] = 1,
	["Prestige"] = 0,
	["PrestigeTokens"] = 0,
	["LuckBoost"] = 0,
	["OwnedTowers"] = {},
	MythicalPity = 0,
	LegendaryPity = 0,
	LastOnlineHour = 0,

	Items = {},
	PlayerStats = {
		InfiniteWave = 0,
	},
	EventStats = {
		Halloween2023 = {
			Pumpkins = 0,
		},
	},
	AFKStats = {
		--InChamber = false,
		TimeInChamber = 0,
		GemsEarnedInChamber = 0
	},
	BoughtFromTravelingMerchant = {
		MerchantLeavingTime = 0,	--TravelingMerchant script will take care of this dictionary
		ItemsBought = {}	--hold names
	},
	Settings = {
		MusicVolume = 0.5,
		SummonSkip = false,
		DamageIndicator = true,
		VFX = true,
		AutoSkip = false,
		GameVolume = 0.5,
		UIVolume = 0.5,
		ReduceMotion = false,
	},
	CosmeticEquipped = "",
	CosmeticUniqueID = "",
	AutoSell = {
		Rare = false,
		Epic = false,
		Legendary = false,
	},
	LastChallengeCompletedUniqueId = 0,
	TeamPresets = {
		["1"] = {},
		["2"] = {},
		["3"] = {}
	},
	OwnGamePasses = {
		["VIP"] = false,
		["Extra Storage"] = false,
		["Display 3 Units"] = false,
		["x2 Gems"] = false,
		["Shiny Hunter"] = false,
		["Starter Pack"] = false,
		["Ultra VIP"] = false,
		["2x Player XP"] = false,
		["2x Speed"] = false,
		["3x Speed"] = false,
		
		["Starter Bundle"] = false,
		["Supreme Bundle"] = false
	},
	DailyRewards = {
		LastClaimTime = 0,
		NextClaim = 1
	},
	LeaderboardStats = {
		EASYWins = 0,
		MEDIUMWins = 0,
		HARDWins = 0,
		INSANEWins = 0,
	},
	Index = {
		["Units Index"] = {},
		["Boss Beaten"] = {}
	},
	DataTransferFromOldData = false,
	SelectedVersion = "",
	TimeSpent = 0,
	RobuxSpent = 0,
	Speed = 1, -- for 1.5x & 3x speed
	
	
	-- Raids Data
	RaidActData = {},
	RaidLimitData = {
		Attempts = 5,
        NextReset = 0,
        OldReset = 0,
	}
	
	
	--[[
	['Map'] = {
		['Act1'] = {
			Completed = false,
			
			
		}
	}
	
	
	--]]
	
	
}