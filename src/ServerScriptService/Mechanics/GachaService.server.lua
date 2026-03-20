------------------// SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

------------------// CONSTANTS
local DATA_UTILITY        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local PETS_DATA_MODULE    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PetsData"))
local EGGS_DATA_MODULE    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("EggData"))
local RARITYS_DATA_MODULE = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("RaritysData"))

local REMOTE_NAME             = "EggGachaRemote"
local CHECK_FUNDS_REMOTE_NAME = "CheckEggFundsRemote"

local MAX_EGG_QUANTITY = 10

------------------// VARIABLES
local gachaRemote      = nil
local checkFundsRemote = nil
local playerDebounce   = {}

------------------// FUNCTIONS
local function setupRemotes()
	local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")

	gachaRemote = remotesFolder:FindFirstChild(REMOTE_NAME)
	if not gachaRemote then
		gachaRemote = Instance.new("RemoteFunction")
		gachaRemote.Name = REMOTE_NAME
		gachaRemote.Parent = remotesFolder
	end

	checkFundsRemote = remotesFolder:FindFirstChild(CHECK_FUNDS_REMOTE_NAME)
	if not checkFundsRemote then
		checkFundsRemote = Instance.new("RemoteFunction")
		checkFundsRemote.Name = CHECK_FUNDS_REMOTE_NAME
		checkFundsRemote.Parent = remotesFolder
	end
end

local function getRarityTier(rarityName)
	local rarityData = RARITYS_DATA_MODULE[rarityName]
	return rarityData and rarityData.Tier or 0
end

local function applyLuckyBoost(weights, luckyMultiplier)
	if luckyMultiplier <= 1 then
		return weights
	end

	local boostedWeights = {}
	local allPets = PETS_DATA_MODULE.GetAllPets()

	for petName, baseWeight in pairs(weights) do
		local petData = allPets[petName]
		if petData then
			local rarityTier  = getRarityTier(petData.Raritys)
			local boostFactor = 1 + (rarityTier * 0.2 * (luckyMultiplier - 1))
			boostedWeights[petName] = baseWeight * boostFactor
		else
			boostedWeights[petName] = baseWeight
		end
	end

	return boostedWeights
end

local function pickWeightedRandomPet(eggSpecificWeights, luckyMultiplier)
	local weightsToUse = applyLuckyBoost(eggSpecificWeights or {}, luckyMultiplier or 1)

	local totalWeight   = 0
	local weightedTable = {}

	for petName, weight in pairs(weightsToUse) do
		totalWeight = totalWeight + weight
		table.insert(weightedTable, {
			Name             = petName,
			Weight           = weight,
			CumulativeWeight = totalWeight,
		})
	end

	if totalWeight == 0 then
		warn("Total weight is 0, returning default pet")
		return "Cat"
	end

	local randomValue = math.random() * totalWeight

	for _, entry in ipairs(weightedTable) do
		if randomValue <= entry.CumulativeWeight then
			return entry.Name
		end
	end

	return weightedTable[1].Name
end

local function checkCanOpenEgg(player, eggName, quantity)
	quantity = math.clamp(math.floor(tonumber(quantity) or 1), 1, MAX_EGG_QUANTITY)

	if not player or not player:IsDescendantOf(game.Players) then
		return { success = false, reason = "Invalid player" }
	end

	if playerDebounce[player.UserId] then
		return { success = false, reason = "AlreadyOpening" }
	end

	if not eggName or type(eggName) ~= "string" then
		return { success = false, reason = "Invalid egg name" }
	end

	local eggInfo = EGGS_DATA_MODULE[eggName]
	if not eggInfo then
		return { success = false, reason = "Egg not found" }
	end

	local totalHatched = DATA_UTILITY.server.get(player, "Stats.TotalHatched") or 0
	local isFirstFree  = (eggName == "Common Egg" and totalHatched == 0)

	-- Calcula o custo total (Preço x Quantidade que o player pediu)
	local totalCost = eggInfo.Price * quantity

	-- Se ele pediu apenas 1 ovo E é o primeiro, o custo fica zero
	if isFirstFree and quantity == 1 then
		totalCost = 0
	end

	if totalCost > 0 then
		local currencyKey    = eggInfo.Currency
		local currentBalance = DATA_UTILITY.server.get(player, currencyKey) or 0

		if currentBalance < totalCost then
			return {
				success = false,
				reason  = "InsufficientFunds",
				details = {
					required = totalCost,
					current  = currentBalance,
					currency = currencyKey,
				},
			}
		end
	end

	return { success = true }
end

local function handleEggOpen(player, eggName, quantity)
	quantity = math.clamp(math.floor(tonumber(quantity) or 1), 1, MAX_EGG_QUANTITY)

	if not player or not player:IsDescendantOf(game.Players) then
		return nil
	end

	if playerDebounce[player.UserId] then
		return nil
	end

	local eggInfo = EGGS_DATA_MODULE[eggName]
	if not eggInfo then
		return nil
	end

	playerDebounce[player.UserId] = true

	local currencyKey = eggInfo.Currency
	-- Multiplica corretamente o valor pela quantidade
	local totalCost   = eggInfo.Price * quantity

	local totalHatched = DATA_UTILITY.server.get(player, "Stats.TotalHatched") or 0
	local isFirstFree  = (eggName == "Common Egg" and totalHatched == 0)

	-- O Ovo só é grátis se a quantidade comprada for exatamente 1
	if isFirstFree and quantity == 1 then
		totalCost = 0
	end

	if totalCost > 0 then
		local currentBalance = DATA_UTILITY.server.get(player, currencyKey) or 0

		if currentBalance < totalCost then
			playerDebounce[player.UserId] = nil
			return nil
		end

		local newBalance = currentBalance - totalCost
		DATA_UTILITY.server.set(player, currencyKey, newBalance)

		task.wait(0.1)

		local verifyBalance = DATA_UTILITY.server.get(player, currencyKey)
		if verifyBalance ~= newBalance then
			DATA_UTILITY.server.set(player, currencyKey, currentBalance)
			playerDebounce[player.UserId] = nil
			return nil
		end
	end

	local luckyMultiplier = player:GetAttribute("Lucky") or 1
	local ownedUpgrades   = DATA_UTILITY.server.get(player, "OwnedRebirthUpgrades") or {}
	if table.find(ownedUpgrades, "EggLuck") then
		luckyMultiplier = luckyMultiplier + 0.5
	end

	local pickedPets = {}
	local ownedPets  = DATA_UTILITY.server.get(player, "OwnedPets") or {}

	for i = 1, quantity do
		local petName = pickWeightedRandomPet(eggInfo.Weights, luckyMultiplier)

		if not petName then
			if totalCost > 0 then
				local bal = DATA_UTILITY.server.get(player, currencyKey) or 0
				DATA_UTILITY.server.set(player, currencyKey, bal + totalCost)
			end
			playerDebounce[player.UserId] = nil
			return nil
		end

		ownedPets[petName] = true
		table.insert(pickedPets, petName)
	end

	DATA_UTILITY.server.set(player, "OwnedPets", ownedPets)

	local currentHatched = DATA_UTILITY.server.get(player, "Stats.TotalHatched") or 0
	DATA_UTILITY.server.set(player, "Stats.TotalHatched", currentHatched + quantity)

	task.wait(0.3)
	playerDebounce[player.UserId] = nil

	return pickedPets
end

------------------// INIT
setupRemotes()

checkFundsRemote.OnServerInvoke = function(player, eggName, quantity)
	return checkCanOpenEgg(player, eggName, quantity)
end

gachaRemote.OnServerInvoke = handleEggOpen

game.Players.PlayerAdded:Connect(function(player)
	if not player:GetAttribute("Lucky") then
		player:SetAttribute("Lucky", 1)
	end
end)

game.Players.PlayerRemoving:Connect(function(player)
	if playerDebounce[player.UserId] then
		playerDebounce[player.UserId] = nil
	end
end)