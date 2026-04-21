--[[
	*Examples: 
	-------------------------------------
	APPLY STATS TO MOBS(npc that the game spawn in, and attempt to deal damage toward the player base)
	WORKING STATS BUFF/DEBUFF (Speed, Health)
	{
		Name = "Fast Enemies",
		MobStats = {
			--Enemies Stats Multiplier
			Speed = 25,
			Health = 0
		}
	}
	--------------------------------------
	APPLY STATS TO PLAYER UNIT(npc that the player spawn in, and attempt to protect the player base from mobs)
	WORKING STATS BUFF/DEBUFF (Price)
	{
		Name = "Costly Unit",
		UnitStats = {
			Price = 50
		}
	}
	
	
--]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StoryModeStats = require(game.ReplicatedStorage.StoryModeStats)
local ItemsStatsModule = require(game.ReplicatedStorage.ItemStats)
local AllowWorlds = {"Naboo Planet", "Geonosis Planet", "Kashyyyk Planet", "Death Star"}
local GetPlayerBoost = require(ReplicatedStorage.Modules.GetPlayerBoost)
local GetVipsBoost = require(ReplicatedStorage.Modules.GetVipsBoost) 



local function copyDictionary(Table)
	--Create a completely separate table so that the path arent connected
	local newTable = {}
	for index, element in Table do
		if typeof(element) == "table" then
			newTable[index] = copyDictionary(element)
		else
			newTable[index] = element
		end
	end

	return newTable
end

local Challenge = { 
	["Data"] = {
		{
			Name = "Fast Enemies",
			Description = "Enemies run 25% faster",
			MobStats = {
				Speed = 25,
				Health = 0
			},
			Difficulty = "Easy"
		},
		{
			Name = "Tank Enemies",
			Description = "Enemies have 35% more health",
			MobStats = {
				Speed = 0,
				Health = 25
			},
			Difficulty = "Easy"
		},
		{
			Name = "High Cost",
			Description = "Units cost 50% more",
			UnitStats = {
				Price = 50
			},
			Difficulty = "Easy"
		},
		{
			Name = "Faster Enemies",
			Description = "Enemies run 35% faster",
			MobStats = {
				Speed = 35,
				Health = 0
			},
			Difficulty = "Medium"
		},
		{
			Name = "Tankier Enemies",
			Description = "Enemies have 25% more health",
			MobStats = {
				Speed = 0,
				Health = 35
			},
			Difficulty = "Medium"
		},
		
		{
			Name = "Higher Cost",
			Description = "Units cost 70% more",
			UnitStats = {
				Price = 70
			},
			Difficulty = "Medium"
		},
		
		{
			Name = "Boss Rush",
			Description = "Only Bosses",
			MobStats = nil,
			Difficulty = "Hard"
		},
		
		{
			Name = "Demon Boss",
			Description = "Fight this formidable Foe",
			MobStats = nil,
			Difficulty = "Hard"
		},
		{
			Name = "1 HP!",
			Description = "SURVIVE ON 1HP AGAINST FORMIDABLE ENEMIES",
			MobStats = nil,
			Difficulty = "Hard"
			
		},
		{
			Name = "EXTREME BOSS",
			Description = "SURVIVE AGAINST THIS IMPOSSIBLE FOE AND DO AS MUCH DAMAGE",
			MobStats = nil,
			Difficulty = "EXTREME_BOSS"

		},

		
		
		
		
	},

	["Rewards"] = {
		Easy = {
			Name = "Easy",
			Description = "Easy Difficulty",
			Give = function(player)
				local doubleGems = player.OwnGamePasses["x2 Gems"].Value
				local doubleGemsmulti = doubleGems and 2 or 1
				local PrestigeValue = player:FindFirstChild("Prestige").Value
				local DoubleEXP = player.OwnGamePasses["2x Player XP"].Value and 2 or 1
				local receiveReward = {
					PlayerExp = math.round(15 * (GetPlayerBoost(player, "XP") * GetVipsBoost(player) * DoubleEXP * (1 + (PrestigeValue * 10)/100))),
					RepublicCredits = 6
				}
				player.PlayerExp.Value += receiveReward.PlayerExp
				player.RepublicCredits.Value += receiveReward.RepublicCredits
				return receiveReward
			end
		},

		Medium = {
			Name = "Medium",
			Description = "Medium Difficulty",
			Give = function(player)
				local doubleGems = player.OwnGamePasses["x2 Gems"].Value
				local doubleGemsmulti = doubleGems and 2 or 1
				local PrestigeValue = player:FindFirstChild("Prestige").Value
				local DoubleEXP = player.OwnGamePasses["2x Player XP"].Value and 2 or 1
				local receiveReward = {
					PlayerExp = math.round(20 * (GetPlayerBoost(player, "XP") * GetVipsBoost(player) * DoubleEXP * (1 + (PrestigeValue * 10)/100))),
					RepublicCredits = 10
				}
				player.PlayerExp.Value += receiveReward.PlayerExp
				player.RepublicCredits.Value += receiveReward.RepublicCredits
				return receiveReward
			end
		},

		Hard = {
			Name = "Hard",
			Description = "Hard Difficulty",
			Give = function(player)
				local doubleGems = player.OwnGamePasses["x2 Gems"].Value
				local doubleGemsmulti = doubleGems and 2 or 1
				local PrestigeValue = player:FindFirstChild("Prestige").Value
				local DoubleEXP = player.OwnGamePasses["2x Player XP"].Value and 2 or 1
				local receiveReward = {
					PlayerExp = math.round(30 * (GetPlayerBoost(player, "XP") * GetVipsBoost(player) * DoubleEXP * (1 + (PrestigeValue * 10)/100))),
					RepublicCredits = 12
				}
				player.PlayerExp.Value += receiveReward.PlayerExp
				player.RepublicCredits.Value += receiveReward.RepublicCredits
				return receiveReward
			end
		},
		
		EXTREME_BOSS = {
			Name = "EXTREME_BOSS",
			Description = "GET AS MUCH DAMAGE AS POSSIBLE FOR CRAZY REWARDS",
			Give = function(player)
				local recievedReward = {}

				local PrestigeValue = player:FindFirstChild("Prestige").Value
				local DoubleEXP = player.OwnGamePasses["2x Player XP"].Value and 2 or 1

				local TableFunctions = {
					[100000] = function()
						recievedReward.PlayerExp = math.round(10 * (GetPlayerBoost(player, "XP") * GetVipsBoost(player) * DoubleEXP * (1 + (PrestigeValue * 10) / 100)))
						recievedReward.RepublicCredits = 2
					end,
					[10000000] = function()
						recievedReward.PlayerExp = math.round(20 * (GetPlayerBoost(player, "XP") * GetVipsBoost(player) * DoubleEXP * (1 + (PrestigeValue * 10) / 100)))
						recievedReward.RepublicCredits = 8
					end,
					[25000000] = function()
						recievedReward.PlayerExp = math.round(40 * (GetPlayerBoost(player, "XP") * GetVipsBoost(player) * DoubleEXP * (1 + (PrestigeValue * 10) / 100)))
						recievedReward.RepublicCredits = 13
					end,
				}

				local Damage = player:GetAttribute("RawDamage")
				local thresholds = {25000000, 10000000, 1000000}

				for _, threshold in ipairs(thresholds) do
					if Damage >= threshold then
						local rewardFunc = TableFunctions[threshold]
						if rewardFunc then
							rewardFunc() 
						end
						break 
					end
				end

				return recievedReward
			end

		}
		
		
	}
}

function Challenge.GetCurrent()
	--Return a list of 3 possibles challenges

	--local currentHour = math.floor(os.time()/3600)
	local halfAnHour = math.floor(os.time()/1800)
	local fixedRNG = Random.new(halfAnHour)

	local totalWorld, lastWorldTotalLevel = 0,0
	for world, levelList in AllowWorlds do --StoryModeStats.LevelName
		local worldInfo = StoryModeStats[world]
		if not worldInfo then continue end
		totalWorld += 1
		lastWorldTotalLevel = 0
		for _,_ in worldInfo do
			lastWorldTotalLevel += 1
		end
	end

	totalWorld = #StoryModeStats.Worlds
	--local list = {}
	--for i = 1, 3 do
	local randomChallengeNumber = fixedRNG:NextInteger(1, #Challenge.Data)
	local randomWorld, randomLevel = fixedRNG:NextInteger(1, totalWorld), fixedRNG:NextInteger(1, lastWorldTotalLevel)
	local newTable = copyDictionary(Challenge.Data[ randomChallengeNumber ])
	newTable["World"] = randomWorld
	newTable["Level"] = randomLevel
	newTable["ChallengeNumber"] = randomChallengeNumber
	newTable["Reward"] = newTable.Difficulty
	warn("Challenge" .. newTable["Reward"])
	--table.insert(list, newTable)
	--end
	--string.format("Cost %0.2f", ui.Value)
	--return list
	--print(`Get|| FixedRNGNumber:{halfAnHour} | ChallengeNumber:{newTable.ChallengeNumber} | Leve:{newTable.Level}`)
	return newTable, ((halfAnHour + 1) * 1800) 	--ChallengeData, When its refreshing
end

return Challenge
--local currentHour = math.floor(os.time()/3600)
--