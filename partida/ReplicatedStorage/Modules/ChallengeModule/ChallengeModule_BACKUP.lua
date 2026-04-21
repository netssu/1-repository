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
local GetPlayerBoost = require(game.ReplicatedStorage.Modules.GetPlayerBoost)
local GetVipsBoost = require(game.ReplicatedStorage.Modules.GetVipsBoost) 
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
				--Enemies Stats Multiplier
				Speed = 25,
				Health = 0
			}
		},
		{
			Name = "Tank Enemies",
			Description = "Enemies have 25% more health",
			MobStats = {
				--Enemies Stats Multiplier
				Speed = 0,
				Health = 25
			}
		},
		{
			Name = "High Cost",
			Description = "Units cost 50% more",
			UnitStats = {
				Price = 50
			}
		},
	},
	
	["Rewards"] = {
		{
			Name = "AllCrystals",
			Description = "Random Crystals",
			Give = function(player)
	local DoubleEXP = if player.OwnGamePasses["2x Player XP"].Value then 2 else 1
	local doubleGemsmulti = if player.OwnGamePasses["x2 Gems"].Value then 2 else 1
	local receiveReward = {
		["PlayerExp"] = math.round(25 * (GetPlayerBoost(player,"XP") * GetVipsBoost(player) * DoubleEXP) ),
		["Gems"] = 30*doubleGemsmulti,
		["TraitPoint"] = (math.random(1,10) == 1 and math.random(1,2)) or 0,
		Items = {}
	}
	player["PlayerExp"].Value += receiveReward.PlayerExp 
	player["Gems"].Value += receiveReward.Gems
	player["TraitPoint"].Value += receiveReward.TraitPoint

	local ItemRaritiesChance = {	--out of 1/100
		{Rarity = "Mythical", Weight = 3},
		{Rarity = "Legendary", Weight = 33},
		{Rarity = "Epic", Weight = 64 },
	}
	--[[
	{Rarity = "Epic", Weight = 100 },
	{Rarity = "Legendary", Weight = 33},
	{Rarity = "Mythical", Weight = 10}
	]]
	local FruitsItemStats = {}


	for _, itemStats in ItemsStatsModule do
		if itemStats.Itemtype ~= "Fruit" then continue end
		table.insert(FruitsItemStats, itemStats)
	end
	local AlreadyGiveFruitType = {}
	local randomFruitStatsToGive = nil
	for i = 1, math.random(2,3) do

		local chance = math.random(1,10000)/100
		local randomFruitStatsToGive = nil

		local totalWeight = 0
		--Identify what fruit to give
		for _, info in ItemRaritiesChance do
			totalWeight += info.Weight
			if chance > totalWeight or randomFruitStatsToGive then continue end

			local currentRarityFruits = {}

			for _, fruitStats in FruitsItemStats do
				if fruitStats.Rarity ~= info.Rarity then continue end
				table.insert(currentRarityFruits, fruitStats)
			end

			local attemptToGiveDifferentFruit = 0

			randomFruitStatsToGive = currentRarityFruits[math.random(1, #currentRarityFruits)]
			while attemptToGiveDifferentFruit < #currentRarityFruits and table.find(AlreadyGiveFruitType, randomFruitStatsToGive.Name) do
				randomFruitStatsToGive = currentRarityFruits[math.random(1, #currentRarityFruits)]
				if table.find(AlreadyGiveFruitType, randomFruitStatsToGive.Name) then
					attemptToGiveDifferentFruit += 1
				end
			end

			break
		end

		if receiveReward.Items[randomFruitStatsToGive.Name] == nil then
			receiveReward.Items[randomFruitStatsToGive.Name] = 0
		end
		local giveAmount = math.random(1,3)
		player.Items[randomFruitStatsToGive.Name].Value += giveAmount
		receiveReward.Items[randomFruitStatsToGive.Name] += giveAmount
	end
	return receiveReward

end,
		},
		{
			Name = "Guaranteed Celestial",
			Description = "Guaranteed Celestial Crystal",
			Give = function(player)
				local DoubleEXP = if player.OwnGamePasses["2x Player XP"].Value then 2 else 1
				local doubleGemsmulti = if player.OwnGamePasses["x2 Gems"].Value then 2 else 1
				local receiveReward = {
					["PlayerExp"] = math.round(25 * (GetPlayerBoost(player,"XP") * GetVipsBoost(player) * DoubleEXP) ),
					["Gems"] = 30*doubleGemsmulti,
					["TraitPoint"] = (math.random(1,10) == 1 and math.random(1,2)) or 0,
					Items = {
						["Crystal (Celestial)"] = 1
					}
				}
				player["PlayerExp"].Value += receiveReward.PlayerExp 
				player["Gems"].Value += receiveReward.Gems
				player["TraitPoint"].Value += receiveReward.TraitPoint
				player.Items["Crystal (Celestial)"].Value += receiveReward.Items["Crystal (Celestial)"]

				return receiveReward
			end
		},
		{
			Name = "Guaranteed Star",
			Description = "Guaranteed 2-3 Stars",
			Give = function(player)
				local DoubleEXP = if player.OwnGamePasses["2x Player XP"].Value then 2 else 1
				local doubleGemsmulti = if player.OwnGamePasses["x2 Gems"].Value then 2 else 1
				local receiveReward = {
					["PlayerExp"] = math.round(25 * (GetPlayerBoost(player,"XP") * GetVipsBoost(player) * DoubleEXP) ),
					["Gems"] = 30*doubleGemsmulti,
					["TraitPoint"] = (math.random(1,3) == 1 and math.random(2,3)) or 2
				}
				player["PlayerExp"].Value += receiveReward.PlayerExp 
				player["Gems"].Value += receiveReward.Gems
				player["TraitPoint"].Value += receiveReward.TraitPoint

				return receiveReward
			end
		},
		--{
		--	Name = "200 Money",
		--	Description = "200 Money",
		--	Give = function(player)
		--		local receiveReward = {
		--			["Coins"] = 200,
		--		}
		--		player["Coins"].Value += receiveReward.Coins

		--		return receiveReward
		--	end
		--}
	}
}

function Challenge.GetCurrent()
	--Return a list of 3 possibles challenges

	--local currentHour = math.floor(os.time()/3600)
	local halfAnHour = math.floor(os.time()/1800)
	local fixedRNG = Random.new(halfAnHour)

	local totalWorld, lastWorldTotalLevel = 0,0
	for world, levelList in StoryModeStats.LevelName do
		totalWorld += 1
		lastWorldTotalLevel = 0
		for _,_ in levelList do
			lastWorldTotalLevel += 1
		end
	end
	totalWorld = #StoryModeStats.Worlds
	--local list = {}
	--for i = 1, 3 do
	local randomChallengeNumber = fixedRNG:NextInteger(1, #Challenge.Data)
	local randomChallengeRewardNumber = fixedRNG:NextInteger(1, #Challenge.Rewards)
	local randomWorld, randomLevel = fixedRNG:NextInteger(1, totalWorld), fixedRNG:NextInteger(1, lastWorldTotalLevel)
	local newTable = copyDictionary(Challenge.Data[ randomChallengeNumber ])
	newTable["World"] = randomWorld
	newTable["Level"] = randomLevel
	newTable["ChallengeNumber"] = randomChallengeNumber
	newTable["ChallengeRewardNumber"] = randomChallengeRewardNumber
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