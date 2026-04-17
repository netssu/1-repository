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
local StoryModeStats = require(game.ReplicatedStorage.StoryModeStats)
local ItemsStatsModule = require(game.ReplicatedStorage.ItemStats)
local AllowWorlds = {"Naboo Planet","Geonosis Planet","Kashyyyk Planet","Death Star", "Tatooine", "Mustafar", "Destroyed Kamino"}

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
			Description = "6 Republic Credits"
		},

		Medium = {
			Description = "10 Republic Credits"
		},

		Hard = {
			Description = "12 Republic Credits"
		},
		EXTREME_BOSS = {
			Description = "GET AS MUCH DAMAGE AS POSSIBLE FOR REWARDS"
		}
	}
	
}


--local Challenge = { 
--	["Data"] = {
--		{
--			Name = "Fast Enemies",
--			Description = "Enemies run 25% faster",
--			MobStats = {
--				--Enemies Stats Multiplier
--				Speed = 25,
--				Health = 0
--			}
--		},
--		{
--			Name = "Tank Enemies",
--			Description = "Enemies have 25% more health",
--			MobStats = {
--				--Enemies Stats Multiplier
--				Speed = 0,
--				Health = 25
--			}
--		},
--		{
--			Name = "High Cost",
--			Description = "Units cost 50% more",
--			UnitStats = {
--				Price = 50
--			}
--		},
--	},
	
--	["Rewards"] = {
--		{
--			Name = "AllCrystals",
--			Description = "Random Crystals",
--			Give = function(player)
--				local doubleGems = player.OwnGamePasses["x2 Gems"].Value
--				local doubleGemsmulti = if doubleGems then 2 else 1
--				local receiveReward = {
--					["PlayerExp"] = 25,
--					["Gems"] = 30*doubleGemsmulti,
--					["TraitPoint"] = (math.random(1,10) == 1 and math.random(1,2)) or 0,
--					Items = {}
--				}
--				player["PlayerExp"].Value += receiveReward.PlayerExp 
--				player["Gems"].Value += receiveReward.Gems
--				player["TraitPoint"].Value += receiveReward.TraitPoint

--				local ItemRaritiesChance = {	--out of 1/100
--					{Rarity = "Mythical", Weight = 10},
--					{Rarity = "Legendary", Weight = 30},
--					{Rarity = "Epic", Weight = 60 },
--				}
--				--[[
--				{Rarity = "Epic", Weight = 100 },
--				{Rarity = "Legendary", Weight = 33},
--				{Rarity = "Mythical", Weight = 10}
--				]]
--				local FruitsItemStats = {}


--				for _, itemStats in ItemsStatsModule do
--					if itemStats.Itemtype ~= "Fruit" then continue end
--					table.insert(FruitsItemStats, itemStats)
--				end
--				local AlreadyGiveFruitType = {}
--				local randomFruitStatsToGive = nil
--				for i = 1, math.random(2,3) do

--					local chance = math.random(1,10000)/100
--					local randomFruitStatsToGive = nil

--					local totalWeight = 0
--					--Identify what fruit to give
--					for _, info in ItemRaritiesChance do
--						totalWeight += info.Weight
--						if chance > totalWeight or randomFruitStatsToGive then continue end

--						local currentRarityFruits = {}

--						for _, fruitStats in FruitsItemStats do
--							if fruitStats.Rarity ~= info.Rarity then continue end
--							table.insert(currentRarityFruits, fruitStats)
--						end

--						local attemptToGiveDifferentFruit = 0

--						randomFruitStatsToGive = currentRarityFruits[math.random(1, #currentRarityFruits)]
--						while attemptToGiveDifferentFruit < #currentRarityFruits and table.find(AlreadyGiveFruitType, randomFruitStatsToGive.Name) do
--							randomFruitStatsToGive = currentRarityFruits[math.random(1, #currentRarityFruits)]
--							if table.find(AlreadyGiveFruitType, randomFruitStatsToGive.Name) then
--								attemptToGiveDifferentFruit += 1
--							end

--						end


--						break
--					end

--					if receiveReward.Items[randomFruitStatsToGive.Name] == nil then
--						receiveReward.Items[randomFruitStatsToGive.Name] = 0
--					end
--					local giveAmount = math.random(1,3)
--					player.Items[randomFruitStatsToGive.Name].Value += giveAmount
--					receiveReward.Items[randomFruitStatsToGive.Name] += giveAmount
--				end
--				return receiveReward

--			end,
--		},
--		{
--			Name = "Guaranteed Celestial",
--			Description = "Guaranteed Celestial Crystal",
--			Give = function(player)
--				local doubleGems = player.OwnGamePasses["x2 Gems"].Value
--				local doubleGemsmulti = if doubleGems then 2 else 1
--				local receiveReward = {
--					["PlayerExp"] = 25,
--					["Gems"] = 30*doubleGemsmulti,
--					["TraitPoint"] = (math.random(1,10) == 1 and math.random(1,2)) or 0,
--					Items = {
--						["Crystal (Celestial)"] = 1
--					}
--				}
--				player["PlayerExp"].Value += receiveReward.PlayerExp 
--				player["Gems"].Value += receiveReward.Gems
--				player["TraitPoint"].Value += receiveReward.TraitPoint
--				player.Items["Crystal (Celestial)"].Value += receiveReward.Items["Crystal (Celestial)"]

--				return receiveReward
--			end
--		},
--		{
--			Name = "Guaranteed Star",
--			Description = "Guaranteed 2-3 Stars",
--			Give = function(player)
--				local doubleGems = player.OwnGamePasses["x2 Gems"].Value
--				local doubleGemsmulti = if doubleGems then 2 else 1
--				local receiveReward = {
--					["PlayerExp"] = 25,
--					["Gems"] = 30*doubleGemsmulti,
--					["TraitPoint"] = (math.random(1,3) == 1 and math.random(2,3)) or 2
--				}
--				player["PlayerExp"].Value += receiveReward.PlayerExp 
--				player["Gems"].Value += receiveReward.Gems
--				player["TraitPoint"].Value += receiveReward.TraitPoint

--				return receiveReward
--			end
--		},
--		--{
--		--	Name = "200 Money",
--		--	Description = "200 Money",
--		--	Give = function(player)
--		--		local receiveReward = {
--		--			["Coins"] = 200,
--		--		}
--		--		player["Coins"].Value += receiveReward.Coins

--		--		return receiveReward
--		--	end
--		--}
--	}
--}

function Challenge.GetCurrent()
	--Return a list of 3 possibles challenges

	--local currentHour = math.floor(os.time()/3600)
	local halfAnHour = math.floor(os.time()/1800)
    local fixedRNG = Random.new(halfAnHour)
    
    -- math.floor(os.time() + 3600/1800)
    
    -- halfAnHour + 3600 -- next hour
    -- halfAnHour + (3600 * 2) -- the hour after
    -- halfAnHour + (3600 * 3) -- the hour after the hour after
    
    
    --[[
    > for i = 1, 3 do print(i) end  -  Studio
  21:14:34.451  1  -  Edit
  21:14:34.451  2  -  Edit
  21:14:34.451  3  -  Edit
    --]]
    
	local totalWorld, lastWorldTotalLevel = 0,0
	for world_number, world_name in AllowWorlds do
		
		local worldInfo = StoryModeStats.LevelName[world_name]
		if not worldInfo then continue end
		totalWorld += 1
		lastWorldTotalLevel = 0
		for _,_ in worldInfo do
			lastWorldTotalLevel += 1
		end
	end
	
	--local list = {}
	--for i = 1, 3 do
	
	local List = {}
    local fixedRNGTable = {}
    
    local rngTable = {
        [1] = math.floor(os.time() + 3600 / 1800),
        [2] = math.floor(os.time() + 3600 * 2 / 1800),
        [3] = math.floor(os.time() + 3600 * 3 / 1800)
	}

    for i,v in rngTable do
		fixedRNGTable[i] = Random.new(v)
    end
    
    local storedTables = {}
	
	for i = 1, 3 do
		
        local Hour = Random.new(rngTable[i])
        
		local randomChallengeNumber = Hour:NextInteger(1, #Challenge.Data)
        local randomChallengeRewardNumber = 1
        local randomWorld = table.find(StoryModeStats.Worlds, AllowWorlds[Hour:NextInteger(1, totalWorld)])
        local randomLevel = Hour:NextInteger(1, lastWorldTotalLevel) -- generates a number based on the seed
		local newTable = copyDictionary(Challenge.Data[ randomChallengeNumber ])
		newTable["World"] = randomWorld
		newTable["Level"] = randomLevel
		newTable["ChallengeNumber"] = randomChallengeNumber
        newTable["ChallengeRewardNumber"] = randomChallengeRewardNumber
        
        storedTables[i] = newTable
	end

	local randomChallengeNumber = fixedRNG:NextInteger(1, #Challenge.Data)
	local randomChallengeRewardNumber = 1
	local randomWorld = table.find(StoryModeStats.Worlds, AllowWorlds[fixedRNG:NextInteger(1, totalWorld)])
	local randomLevel = fixedRNG:NextInteger(1, lastWorldTotalLevel) -- generates a number based on the seed
	local newTable = copyDictionary(Challenge.Data[ randomChallengeNumber ])
	newTable["World"] = randomWorld
	newTable["Level"] = randomLevel
	newTable["ChallengeNumber"] = randomChallengeNumber
	newTable["ChallengeRewardNumber"] = randomChallengeRewardNumber
	
	--print(totalWorld, lastWorldTotalLevel)
	--table.insert(list, newTable)
	--end
	--string.format("Cost %0.2f", ui.Value)
	--return list
	--print(`Get|| FixedRNGNumber:{halfAnHour} | ChallengeNumber:{newTable.ChallengeNumber} | Leve:{newTable.Level}`)
	return newTable, ((halfAnHour + 1) * 1800), storedTables 	--ChallengeData, When its refreshing
end

return Challenge
--local currentHour = math.floor(os.time()/3600)
--