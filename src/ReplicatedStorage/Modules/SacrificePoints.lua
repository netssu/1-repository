local module = {}

module.SacrificeData = {
	["Legendary"] = {
		Points = 5,
		Shiny = 10,
	},
	["Mythical"] = {
		Points = 25,
		Shiny = 40,
		SummonChance = 78.99
	},
	["Secret"] = {
		Points = 50,
		Shiny = 75,
		SummonChance = 1
	},
	["Exclusive"] = {
		Points = 50,
		Shiny = 75,
		SummonChance = 0
	},
}

module.Traits = {
	["Star Killer"] = 35, 
	["Padawan"] = 25,
	["Lord"] = 21,
	["Merchant"] = 12.5,
	["Mandalorian"] = 5,
	["Cosmic Crusader"] = 1.5,
}

function module.GetRandomRarity(player) : string
	local weightedList = {}
	local totalWeight = 0
	local luckMultiplier = 1	

	if player.Buffs:FindFirstChild('Junk Offering') then
		luckMultiplier += 1
	end

	
	for rarity, data in pairs(module.SacrificeData) do
		local chance = data.SummonChance
		if chance then
			
			if rarity == "Secret" then
				chance *= luckMultiplier
			end

			totalWeight += chance
			table.insert(weightedList, {
				Rarity = rarity,
				Weight = chance
			})
		end
	end
	
	
	local roll = math.random() * totalWeight
	local cumulative = 0

	for _, entry in ipairs(weightedList) do
		cumulative += entry.Weight
		if roll <= cumulative then
			return entry.Rarity
		end
	end

	-- Fallback, shouldn't happen
	return "Mythical"
end

function module.GetRandomTrait(player: Player) : string
	local weightedList = {}
	local totalWeight = 0
	local luckMultiplier = 1

	local luckMultiplier = player.Parent and player.OwnGamePasses['x2 Luck'] and player.OwnGamePasses['x2 Luck'].Value and 2 or 1


	for trait, chance in pairs(module.Traits) do
		if chance then
			local adjustedChance = chance * luckMultiplier

			totalWeight += adjustedChance
			table.insert(weightedList, {
				Trait = trait,
				Weight = adjustedChance
			})
		end
	end

	local roll = math.random() * totalWeight
	local cumulative = 0

	for _, entry in ipairs(weightedList) do
		cumulative += entry.Weight
		if roll <= cumulative then
			return entry.Trait
		end
	end

	-- Fallback, shouldn't happen
	return "Mythical"
end

return module
