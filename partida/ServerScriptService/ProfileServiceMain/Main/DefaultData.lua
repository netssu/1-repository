-- hello i am an appel
return {
	RaidReset = '1',
	FirstTime = true,
	receivedScout = false,
	ActiveBoosts = {},
	["Day"] = 1,
	["TimeAtLastClaim"] = 0,
	["Codes"] = {},
	["Coins"] = 0,
	["Gems"] = 500,
	["TraitPoint"] = 0,
	["MaxUnits"] = 150,
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
	
	Quests = {
		DailyQuests = {
			LastRefresh = 0,
			Quests = {},
		},
		
		WeeklyQuests = {
			LastRefresh = 0,
			Quests = {},
		},
		
		StoryQuests = {
			Quests = {},
		},
		
		InfiniteQuests = {
			Quests = {},
		},
		
		EventQuests = {
			Quests = {},
		},
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
	["LevelRewards"] = 0,
	["LuckBoost"] = 0,
	["OwnedTowers"] = {},
	MythicalPity = 0,
	LegendaryPity = 0,
	MythicalPityWP = 0,
	LegendaryPityWP = 0,
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
		DamageIndicator = false,
		VFX = true,
		AutoSkip = false,
		GameVolume = 0.5,
		UIVolume = 0.5,
		ReduceMotion = false,
		Auto3x = false,
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
		['2x Willpower Luck'] = false,

		["Starter Bundle"] = false,
		["Supreme Bundle"] = false,

		['x2 Luck'] = false,
		['x2 Raid Luck'] = false,

		['Premium Season Pass'] = false,
		['Episode 2 Pass'] = false,
		["Season 2"] = false
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
	BattlepassData = {
		Season = 1,
		Tier = 1,
		Exp = 0,
		Premium = false,
		InfiniteRewards = {},
		TiersClaimed = {},
		Quests = {},
		LastRefresh = 0,
		
		OldBpRestore = false,
		OldBpPremiumRestore = false,
	},
	EpisodePass = {
		Episode1XP = 0,
		Premium = false,
		Tasks = {},
		RewardsClaimed = {},
	},
	--BrawlPass = {
	--	Pass1 = {
	--		Exp = 0,
	--		Premium = false,
	--		RewardsClaimed = {}
	--	},
	--},
	DataTransferFromOldData = false,
	SelectedVersion = "",
	TimeSpent = 0,
	RobuxSpent = 0,
	Speed = 1, -- for 1.5x & 3x speed


	-- Raids Data
	RaidActData = {},
	RaidLimitData = {
		Attempts = 10,
		NextReset = 0,
		OldReset = 0,
	},


	--[[
	['Map'] = {
		['Act1'] = {
			Completed = false,
			
			
		}
	}
	
	
	--]]

	ABTesting = {
		Treatment = 1,
		TreatmentSet = false
	},

	LuckySpins = 0,

	Logs = {},
	Stats = {
		Kills = 0,
		YounglingsEnded = 0
	},
	TutorialModeCompleted = false,
	TutorialWin = false,
	TutorialCompleted = false,
	TutorialLossGemsClaimed = false,
	
	JunkTraderPoints = 0,
	JunkPremiumPoints = 0,
	JunkOfferings = 0,
	RaidsRefresh = 0,

	OldStreak = 0,
	Streak = 0,
	StreakIncreasesIn = os.time(),
	StreakRestoreExpiresIn = 0, -- os.clock() + 86400 * 3,
	PlayStreakAnimation = false,
	StreakLastUpdated = os.time(),


	ClanData = require(script.ClansConfig),
	
	Variables = {
		SeenClanSplash = false,
	},

	Clans_Comp = false,
	Premium_Comp = false,
	CompletedAct = {},
	RaidPity = 0,
	EventPity = 0,
	RepublicCredits = 0,
	MedalKills = 0 ,
	ReceivedLegendary = false,
	EventAttempts = 0,
	EventWins = 0,
	
	EquippedAura = 'Nothing',
	OwnedAuras = {'Nothing'},
	
	LuckyWillpower = 0,
	ChallengeData = 0,
	FawnEventAttempts = 0,
	GoldenRepublicCredits = 0,
	["Event Double Luck"] = 0,
	
	
	ELO = 0, -- ranked
	RankedPoints = 0,
	
	QuestsHidden = true,
}