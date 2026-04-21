local GlobalFunctions = require(game.ReplicatedStorage.Modules.GlobalFunctions)
local GetUnitModel = require(game.ReplicatedStorage.Modules.GetUnitModel)
local module = {}
-- Test Settings
--local FORCE_RARITY = "Mythical"
--local FORCE_SHINY = false
--local FORCE_TRAITS = nil

local Traits = require(script.Parent.Modules.Traits)

module.TraitPercents = {
	["Waders Will"] = 0.05,
	["Cosmic Crusader"] = 0.05,
	Mandalorian = 0.4,
	Merchant = 0.3,
	Lord = 0.65,
	Padawan = 0.5,
	["Apprentice"] = 0.7,
	["Tyrant's Wrath"] = 0.17,
	["Precision Protocol"] = 1,
	["Arms Dealer"] = 2,
	["Tyrant's Damage"] = 0.5,
	["Star Killer"] = 1.2,
	Lightspeed = 12.75,
	Experience = 12.5,
	["Nimble I"] = 22.5,
	["Range I"] = 22.5,
	["Strong I"] = 22.5,
}

module.LuckyRoll = {
	["Waders Will"] = 1.5,
	["Cosmic Crusader"] = 1.5,
	["Mandalorian"] = 4,
	["Merchant"] = 6,
	["Lord"] = 6,
	["Padawan"] = 4,
	["Apprentice"] = 1.6,
	["Tyrant's Wrath"] = 1.4,
	["Star Killer"] = 12,
	["Precision Protocol"] = 18,
	["Arms Dealer"] = 18,
	["Tyrant's Damage"] = 20,
	["Lightspeed"] = 3,
	["Experience"] = 3,
}

module.chooseRandomTrait = function(player, isluckyRoll)

	if isluckyRoll then
		local traitPool = {}
		for trait, weight in module.LuckyRoll do
			traitPool[trait] = weight
		end
		local totalWeight = 0
		for _, weight in traitPool do
			totalWeight += weight
		end
		local roll = math.random() * totalWeight
		local cumulative = 0
		for trait, weight in traitPool do
			cumulative += weight
			if roll <= cumulative then
				return trait
			end
		end
	end

	local hasDoubleLuck = false
	local passes = player:WaitForChild("OwnGamePasses")
	if passes and passes:FindFirstChild("2x Willpower Luck") and passes["2x Willpower Luck"].Value == true then
		hasDoubleLuck = true
	elseif player:FindFirstChild("Buffs") and player:FindFirstChild("Buffs"):FindFirstChild("WillpowerLuckyCrystal") then
		hasDoubleLuck = true
	end

	local traitPool = {}
	for trait, weight in module.TraitPercents do
		local adjustedWeight = weight
		if hasDoubleLuck and weight <= 5 then 
			adjustedWeight = weight * 2
		end
		traitPool[trait] = adjustedWeight
	end

	local totalWeight = 0
	for _, weight in traitPool do
		totalWeight += weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for trait, weight in traitPool do
		cumulative += weight
		if roll <= cumulative then
			if string.sub(trait, -2) == " I" then
				local baseName = string.sub(trait, 1, string.len(trait) - 1)
				local newLevel = string.rep("I", math.random(1, 3))
				return baseName .. newLevel
			end
			return trait
		end
	end
end

local UpgradesModule = require(game.ReplicatedStorage.Upgrades)
local ItemsModule = require(game.ReplicatedStorage.ItemStats)

module.Mythicals = {}

for i, v in UpgradesModule do
	if v["Rarity"] then
		if v["Rarity"] == "Mythical" and not v["NotInBanner"] then
			table.insert(module.Mythicals,i)
		end
	end
end

module.updateBanner = function()
	local currentMythicals = {}
	local mythicalsToChoose = table.clone(module.Mythicals)

	local now = workspace:GetServerTimeNow()
	local hourSeed = math.floor(now / (3600/2))
	local RNG = Random.new(hourSeed)

	for i = 1, 3 do
		local randomNumber = RNG:NextInteger(1, #mythicalsToChoose)
		local chosenMythical = mythicalsToChoose[randomNumber]
		table.insert(currentMythicals, chosenMythical)
		table.remove(mythicalsToChoose, randomNumber)
	end
	
	

	return currentMythicals
end


module.UnitPercents ={
	{Rarity = "Secret", Weight = 0.025}, --0.025
	{Rarity = "Mythical", Weight = 0.1},	--0.1
	--{Rarity = "Star", Weight = 0.3},--1
	{Rarity = "Legendary", Weight = 1.1},
	{Rarity = "Epic", Weight = 16.6},
	{Rarity = "Rare", Weight = 83.975}
}

module.LuckyUnitPercents = {
    {Rarity = "Secret", Weight = 0.2},
    {Rarity = "Mythical", Weight = 8},
    --{Rarity = "Star", Weight = 3.7},
    {Rarity = "Legendary", Weight = 25},
    {Rarity = "Epic", Weight = 66.8},
    {Rarity = "Rare", Weight = 0}
}


module.UnitRarities = {
	["Rare"] = {},
	["Epic"] = {},
	["Legendary"] = {},
	["Mythical"] = {},
	["Secret"] = {},
}

for i, v in UpgradesModule do
	if v["Rarity"] then
		if module.UnitRarities[v["Rarity"]] and not v["NotInBanner"] then
			table.insert(module.UnitRarities[v["Rarity"]],i)
		end
	end
end

module.chooseRandomUnit = function(player, isLucky)
	local currentMythicals = {
		game.Workspace.CurrentHour:GetAttribute("Mythical1"),
		game.Workspace.CurrentHour:GetAttribute("Mythical2"),
		game.Workspace.CurrentHour:GetAttribute("Mythical3"),
	}

	local randomNumber = (math.random(1,10000))/100
	local counter = 0
	local luckMultiplier = if player.Buffs:FindFirstChild("UltraLuck") and player.Buffs:FindFirstChild("LuckyCrystal") then 2.25 elseif
		player.Buffs:FindFirstChild("UltraLuck") then 2 elseif player.Buffs:FindFirstChild("LuckyCrystal") then 1.5 else 1
	
	local multiplier = (player.Prestige.Value * 0.05)/3
	if multiplier > 0.20 then -- 1.5 = 50%
		multiplier = 0.20
    end
    
    if player.OwnGamePasses['x2 Luck'].Value then
        luckMultiplier += 1
    end
	
	if game.PlaceId == 117137931466956 then
		luckMultiplier += 5
	end

	luckMultiplier += multiplier
    
    local targetTable = module.UnitPercents
    
    if isLucky then
        targetTable = module.LuckyUnitPercents
    end

	for _, info in targetTable do
		local rarity = info.Rarity
		local weight = info.Weight
		local currentWeight = if table.find({"Secret","Mythical","Legendary"},rarity) then weight * luckMultiplier else weight
		counter = counter + currentWeight

		if randomNumber <= counter then
			local newUnit

			if rarity == "Star" then
				player["TraitPoint"].Value += 1
				return player["TraitPoint"]
			end

			if not player.ReceivedLegendary.Value then -- Guaranteed legendary for new players
				player.ReceivedLegendary.Value = true
				rarity = 'Legendary'
			end

			local newUnit
			-- Handle Legendary pity
			if rarity == "Legendary" or player.LegendaryPity.Value >= 100 then
				player.LegendaryPity.Value = 0
				newUnit = module.UnitRarities.Legendary[math.random(1,#module.UnitRarities.Legendary)]
			else
				player.LegendaryPity.Value += 1
			end

			-- Handle Mythical pity
			if rarity == "Mythical" or player.MythicalPity.Value >= 400 then
				player.MythicalPity.Value = 0
				local rand = math.random(1,4)
				rand = math.min(rand,3)
				newUnit = currentMythicals[rand]
			else
				player.MythicalPity.Value += 1
			end

			if not newUnit then
				newUnit = module.UnitRarities[rarity][math.random(1,#module.UnitRarities[rarity])]
			end
			local trait = ""
			if math.random(1,20) == 1 then
				trait = module.chooseRandomTrait(player)
			end

			local shiny = nil
			if GetUnitModel[newUnit] then
				-- Normal shiny logic
				if player.OwnGamePasses["Shiny Hunter"].Value then
					if math.random(1, 100) <= 3 then
						shiny = true
					end
				elseif player.PlayerLevel.Value >= 10 then
					if math.random(1, 100) <= 1 then
						shiny = true
					end
				end
			end
			return _G.createTower(player.OwnedTowers,newUnit,trait,{Shiny = shiny})
		end


	end
end

return module