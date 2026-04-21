local GlobalFunctions = require(game.ReplicatedStorage.Modules.GlobalFunctions)

local module = {}

local Traits = require(script.Parent.Traits)

module.TraitPercents = {
	["Cosmic Crusader"] = 0.05,
	Mandalorian = 0.1,
	Merchant = 0.3,
	Lord = 0.4,
	Padawan = 0.5,
	["Star Killer"] = 0.7,
	Lightspeed = 1.1,
	Experience = 9.99,
	["Nimble I"] = 27.75,
	["Range I"] = 28.75,
	["Strong I"] = 30.5,
}

module.chooseRandomTrait = function()
	local randomNumber = (math.random(1,10000))/100
	local counter = 0

	for trait, weight in module.TraitPercents do
		counter = counter + weight
		if randomNumber <= counter then
			if string.sub(trait,string.len(trait)-1,string.len(trait)) == " I" then
				local newLevel = ""
				for i = 1, math.random(1,3) do
					newLevel ..= "I"
				end
				trait = string.sub(trait,1,string.len(trait)-1)..newLevel
			end
			return trait
		end
	end
end

local UpgradesModule = require(game.ReplicatedStorage.Upgrades)
local ItemsModule = require(game.ReplicatedStorage.ItemStats)


module.updateBanner = function()
	local currentUnits = {}
	local unitRaritiesCopy = {
		["Rare"] = {table.unpack(module.UnitRarities["Rare"])},
		["Epic"] = {table.unpack(module.UnitRarities["Epic"])},
		["Legendary"] = {table.unpack(module.UnitRarities["Legendary"])},
		["Mythical"] = {table.unpack(module.UnitRarities["Mythical"])},
		["Secret"] = {table.unpack(module.UnitRarities["Secret"])}
	}
	local mythicalsToChoose = unitRaritiesCopy["Mythical"]
	local legendaresToChoose = unitRaritiesCopy["Legendary"]
	local epicesToChoose = unitRaritiesCopy["Epic"]
	local raresToChoose = unitRaritiesCopy["Rare"]
	
	-- Random Mythical Selection
	local seed = ((math.floor(os.time()/1800) )+1)
	local RNG = Random.new(seed)
	local randomMythicalNumber = RNG:NextInteger(1, #mythicalsToChoose)
	local chosenMythical = mythicalsToChoose[randomMythicalNumber]
	table.insert(currentUnits, chosenMythical)
	table.remove(mythicalsToChoose, table.find(mythicalsToChoose, chosenMythical))

	-- Random Legendary Selection
	local randomLegendaryNumber = RNG:NextInteger(1, #legendaresToChoose)
	local chosenLegendary = legendaresToChoose[randomLegendaryNumber]
	table.insert(currentUnits, chosenLegendary)
	table.remove(legendaresToChoose, table.find(legendaresToChoose, chosenLegendary))

	-- Random Epic Selection
	local randomEpicNumber = RNG:NextInteger(1, #epicesToChoose)
	local chosenEpic = epicesToChoose[randomEpicNumber]
	table.insert(currentUnits, chosenEpic)
	table.remove(epicesToChoose, table.find(epicesToChoose, chosenEpic))

	-- Random Rare Selection
	for i = 1, 3 do
		local randomRareNumber = RNG:NextInteger(1, #raresToChoose)
		local chosenRare = raresToChoose[randomRareNumber]
		table.insert(currentUnits, chosenRare)
		table.remove(raresToChoose, table.find(raresToChoose, chosenRare))
	end
	
	
	return currentUnits
end

module.UnitPercents ={
	{Rarity = "Secret", Weight = 0.025}, --0.025
	{Rarity = "Mythical", Weight = 0.1},
	{Rarity = "Magic Token", Weight = 1},--1
	{Rarity = "Legendary", Weight = 1},
	{Rarity = "Epic", Weight = 14.6},
	{Rarity = "Rare", Weight = 83.275}
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

module.chooseRandomUnit = function(player)
	local currentMythicals = {
		game.Workspace.CurrentHour:GetAttribute("Mythical")
	}
	local currentLegendares = {
		game.Workspace.CurrentHour:GetAttribute("Legendary")
	}
	local currentEpics = {
		game.Workspace.CurrentHour:GetAttribute("Epic")
	}
	local currentRares = {
		game.Workspace.CurrentHour:GetAttribute("Rare1"),
		game.Workspace.CurrentHour:GetAttribute("Rare2"),
		game.Workspace.CurrentHour:GetAttribute("Rare3")
	}

	local randomNumber = (math.random(1,10000))/100
	local counter = 0
	local luckMultiplier = if player.Buffs:FindFirstChild("UltraLuck") and player.Buffs:FindFirstChild("LuckyCrystal") then 2.25 elseif
		player.Buffs:FindFirstChild("UltraLuck") then 2 elseif player.Buffs:FindFirstChild("LuckyCrystal") then 1.5 else 1


	for _, info in module.UnitPercents do
		local rarity = info.Rarity
		local weight = info.Weight
		local currentWeight = if table.find({"Secret","Mythical","Legendary"},rarity) then weight * luckMultiplier else weight
		counter = counter + currentWeight

		if randomNumber <= counter then
			local newUnit

			if rarity == "Magic Token" then
				player["TraitPoint"].Value += 1
				return player["TraitPoint"]
			else
				if player.MythicalPity.Value >= 400 or player.LegendaryPity.Value >= 200 then

					if player.MythicalPity.Value >= 400 then
						player.MythicalPity.Value = 0
						newUnit = currentMythicals[1]
						if player.LegendaryPity.Value < 200 then
							player.LegendaryPity.Value += 1
						end
					else
						player.LegendaryPity.Value = 0
						newUnit = currentLegendares[1]
						player.MythicalPity.Value += 1
					end

				else
					if rarity == "Mythical" then
						player.MythicalPity.Value = 0
						newUnit = currentMythicals[1]
					else
						player.MythicalPity.Value += 1
					end
					if rarity == "Legendary" then
						player.LegendaryPity.Value = 0
						newUnit = currentLegendares[1]
					else
						player.LegendaryPity.Value += 1
					end
					if rarity == "Epic" then
						newUnit = currentEpics[1]
					end
					if rarity == "Rare" then
						local Rand = math.random(1,3)
						newUnit = currentRares[Rand]
					end
				end

				if not newUnit then
					newUnit = module.UnitRarities[rarity][math.random(1,#module.UnitRarities[rarity])]
					warn("HERE")
				end
				local trait = ""
				if math.random(1,20) == 1 then
					trait = module.chooseRandomTrait()
				end
				return _G.createTower(player.OwnedTowers,newUnit,trait)
			end


		end
	end
end

return module