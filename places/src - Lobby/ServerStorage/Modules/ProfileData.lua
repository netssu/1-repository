------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//DEPENDENCIES
local dataModules: Folder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data")
local challengesData = require(dataModules:WaitForChild("ChallengesData"))
local dailyRewardData = require(dataModules:WaitForChild("DailyRewardData"))
local racingPassData = require(dataModules:WaitForChild("RacingPassData"))

------------------//CONSTANTS
local CURRENT_DATA_VERSION: number = 5
local CURRENT_RACING_PASS_SEASON: number = racingPassData.CURRENT_SEASON
local UPGRADE_NAMES: { string } = { "Horsepower", "Battery", "KiloWatt", "XP", "Cash" }
local MAX_UPGRADE_LEVEL: number = 3

------------------//FUNCTIONS
local function clone_value(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, childValue in value do
		copy[key] = clone_value(childValue)
	end

	return copy
end

local function merge_values(target: { [any]: any }, source: { [any]: any }): ()
	for key, value in source do
		if type(value) == "table" and type(target[key]) == "table" then
			merge_values(target[key], value)
		else
			target[key] = clone_value(value)
		end
	end
end

local function create_template(): { [string]: any }
	local normalQuests = challengesData.create_root()
	local premiumQuests = challengesData.create_root()
	return {
		DataVersion = CURRENT_DATA_VERSION,
		Currency = {
			Cash = 100,
			XP = 0,
			RacePassXP = 0,
		},
		Inventory = {
			Equipped = {
				Helmets = "Default",
				Suit = "Default",
				Livery = "Default",
				Underglow = "Default",
				Tiresmoke = "Default",
			},
			Owned = {
				Helmets = { "Default" },
				Suit = { "Default" },
				Livery = { "Default" },
				Underglow = { "Default" },
				Tiresmoke = { "Default" },
			},
			Upgrades = {
				Horsepower = 0,
				Battery = 0,
				KiloWatt = 0,
				XP = 0,
				Cash = 0,
			},
		},
		Profile = {
			Gamepasses = {},
			Codes = {},
			Statistics = {
				Wins = 0,
				Matches = 0,
				Playtime = 0,
				Robux = 0,
				Rank = 0,
			},
			PlaytimeProgress = {
				LastProcessedAt = 0,
			},
			Settings = {
				MusicEnabled = true,
				ShadowsEnabled = true,
				SpeedUnit = "KPH",
				RacingLineEnabled = true,
				CarSoundsEnabled = true,
			},
			Quests = normalQuests,
			Level = 1,
			Boosters = {
				MoneyBoost = 0,
				XPBoost = 0,
			},
			FollowerRewards = {},
			MilestonesClaimed = {},
			FirstRaceDailyReward = {
				LastRaceAt = 0,
				LastRewardAt = 0,
			},
			FirstRacePassUnlockReward = {
				ClaimedAt = 0,
			},
			DailyReward = dailyRewardData.create_state(0),
			RacingPass = {
				RacingpassOwned = false,
				RacingpassLevel = 1,
				Season = CURRENT_RACING_PASS_SEASON,
				Quests = premiumQuests,
				NormalClaim = {},
				PremiumClaim = {},
				ProcessedReceipts = {},
			},
		},
	}
end

local function replace_values(target: { [any]: any }, source: { [any]: any }): ()
	table.clear(target)
	for key, value in source do
		target[key] = value
	end
end

local function migrate_legacy_data(data: { [any]: any }): { [string]: any }
	local migrated = create_template()
	local legacyCurrencyRoot = type(data[2]) == "table" and data[2].Currency
	local legacyInventoryRoot = type(data[3]) == "table" and data[3].Inventory
	local legacyUpgrades = type(data[3]) == "table" and data[3].Upgrades
	local legacyProfileRoot = type(data[4]) == "table" and data[4].Profile

	if type(legacyCurrencyRoot) == "table" then
		merge_values(migrated.Currency, legacyCurrencyRoot)
	end
	if type(legacyInventoryRoot) == "table" then
		merge_values(migrated.Inventory, legacyInventoryRoot)
	end
	if type(legacyUpgrades) == "table" then
		merge_values(migrated.Inventory.Upgrades, legacyUpgrades)
	end
	if type(legacyProfileRoot) == "table" then
		merge_values(migrated.Profile, legacyProfileRoot)
	end

	return migrated
end

local function normalize_profile(data: { [any]: any }): ()
	local profile = data.Profile
	local settings = profile.Settings
	local statistics = profile.Statistics
	local dailyReward = profile.DailyReward
	local racingPass = profile.RacingPass
	local upgrades = data.Inventory.Upgrades

	data.DataVersion = CURRENT_DATA_VERSION
	data.Currency.Cash = tonumber(data.Currency.Cash) or 100
	data.Currency.XP = tonumber(data.Currency.XP) or 0
	data.Currency.RacePassXP = tonumber(data.Currency.RacePassXP) or 0
	if type(racingPass) ~= "table" then
		racingPass = {}
		profile.RacingPass = racingPass
	end
	profile.Quests = challengesData.ensure_root(profile.Quests)
	racingPass.Quests = challengesData.ensure_root(racingPass.Quests)
	racingPass.RacingpassOwned = racingPass.RacingpassOwned == true
	racingPass.RacingpassLevel = math.clamp(
		tonumber(racingPass.RacingpassLevel) or racingPassData.MIN_LEVEL,
		racingPassData.MIN_LEVEL,
		racingPassData.MAX_LEVEL
	)
	racingPass.Season = tonumber(racingPass.Season) or CURRENT_RACING_PASS_SEASON
	if type(racingPass.NormalClaim) ~= "table" then
		racingPass.NormalClaim = {}
	end
	if type(racingPass.PremiumClaim) ~= "table" then
		racingPass.PremiumClaim = {}
	end
	if type(racingPass.ProcessedReceipts) ~= "table" then
		racingPass.ProcessedReceipts = {}
	end
	profile.Level = math.max(1, tonumber(profile.Level) or 1)
	if type(upgrades) ~= "table" then
		upgrades = {}
		data.Inventory.Upgrades = upgrades
	end
	for _, upgradeName in UPGRADE_NAMES do
		upgrades[upgradeName] = math.clamp(tonumber(upgrades[upgradeName]) or 0, 0, MAX_UPGRADE_LEVEL)
	end
	statistics.Wins = tonumber(statistics.Wins) or 0
	statistics.Matches = tonumber(statistics.Matches) or 0
	statistics.Playtime = tonumber(statistics.Playtime) or 0
	statistics.Robux = tonumber(statistics.Robux) or 0
	statistics.Rank = tonumber(statistics.Rank) or 0

	if settings.Music ~= nil then
		settings.MusicEnabled = settings.Music == true
	elseif settings.MusicEnabled == nil then
		settings.MusicEnabled = true
	end
	if settings["Speed Unit"] ~= nil then
		settings.SpeedUnit = settings["Speed Unit"]
	elseif settings.SpeedUnit == nil then
		settings.SpeedUnit = settings["Speed Unit"] or "KPH"
	end
	if settings["Racing Line"] ~= nil then
		settings.RacingLineEnabled = settings["Racing Line"] == true
	elseif settings.RacingLineEnabled == nil then
		settings.RacingLineEnabled = true
	end
	if settings["Car Sounds"] ~= nil then
		settings.CarSoundsEnabled = settings["Car Sounds"] == true
	elseif settings.CarSoundsEnabled == nil then
		settings.CarSoundsEnabled = true
	end

	local normalizedDailyReward = dailyRewardData.normalize_state(dailyReward, os.time())
	profile.DailyReward = normalizedDailyReward

	if tonumber(racingPass.Season) ~= CURRENT_RACING_PASS_SEASON then
		racingPass.NormalClaim = {}
		racingPass.PremiumClaim = {}
		racingPass.Quests = challengesData.create_root()
	racingPass.RacingpassLevel = 1
		racingPass.Season = CURRENT_RACING_PASS_SEASON
	end
end

------------------//MAIN FUNCTIONS
local profileData = {}

function profileData.create_template(): { [string]: any }
	return create_template()
end

function profileData.migrate(data: { [any]: any }): boolean
	if data.DataVersion == CURRENT_DATA_VERSION and type(data.Currency) == "table" and type(data.Profile) == "table" then
		normalize_profile(data)
		return false
	end

	local migrated
	if type(data[2]) == "table" or type(data[4]) == "table" then
		migrated = migrate_legacy_data(data)
	else
		migrated = create_template()
		merge_values(migrated, data)
		if type(data.TimePlayed) == "number" then
			migrated.Profile.Statistics.Playtime = data.TimePlayed
		end
		if type(data.Settings) == "table" then
			merge_values(migrated.Profile.Settings, data.Settings)
		end
		migrated.TimePlayed = nil
		migrated.Settings = nil
	end

	normalize_profile(migrated)
	replace_values(data, migrated)
	return true
end

------------------//INIT
return profileData
