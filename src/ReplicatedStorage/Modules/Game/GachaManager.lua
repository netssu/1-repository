local GachaManager = {}

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CONSTANTS
local ENABLE_DEBUG_PRINTS = true

-- VARIABLES
local rng = Random.new()
local DataFolder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data")
local StylesData = require(DataFolder:WaitForChild("StylesData"))
local FlowsData = require(DataFolder:WaitForChild("FlowsData"))

local POOLS = {
	["Style"] = StylesData,
	["Flow"] = FlowsData,
}

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- FUNCTIONS
local function getRarityRank(rarityName: string): number
	for i, name in ipairs(RARITY_ORDER) do
		if name == rarityName then
			return i
		end
	end
	return 0
end

local function calculateTotalWeight(dataPool, minRarityRank: number?)
	local totalWeight = 0
	for _, itemData in pairs(dataPool) do
		local weight = itemData.Weight or (itemData.Rarity and itemData.Rarity.Weight) or 0
		if minRarityRank then
			local itemRank = getRarityRank(itemData.Rarity and itemData.Rarity.Name or "")
			if itemRank < minRarityRank then
				weight = 0
			end
		end
		totalWeight = totalWeight + weight
	end
	return totalWeight
end

function GachaManager.Roll(poolType, options)
	local dataPool = POOLS[poolType]

	if not dataPool then
		warn("GachaManager: Invalid pool -> " .. tostring(poolType))
		return nil, nil
	end

	local minRarityRank = nil
	if options and options.MinRarity then
		minRarityRank = getRarityRank(options.MinRarity)
	end

	local totalWeight = calculateTotalWeight(dataPool, minRarityRank)
	if totalWeight <= 0 then
		return nil, nil
	end

	local randomValue = rng:NextNumber() * totalWeight
	local currentWeight = 0

	for itemId, itemData in pairs(dataPool) do
		local weight = itemData.Weight or (itemData.Rarity and itemData.Rarity.Weight) or 0

		if minRarityRank then
			local itemRank = getRarityRank(itemData.Rarity and itemData.Rarity.Name or "")
			if itemRank < minRarityRank then
				weight = 0
			end
		end

		if weight > 0 then
			currentWeight = currentWeight + weight
			if currentWeight >= randomValue then
				if ENABLE_DEBUG_PRINTS then
					print("Gacha Result [" .. poolType .. "]: " .. itemId)
				end
				return itemId, itemData
			end
		end
	end

	return nil, nil
end

function GachaManager.GetData(poolType, itemId)
	if POOLS[poolType] and POOLS[poolType][itemId] then
		return POOLS[poolType][itemId]
	end
	return nil
end

-- INIT
return GachaManager
