------------------//SERVICES
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local MEGA_EGG_KEY = "Mega Cupcake Egg"
local MEGA_EGG_ANIM_NAME = "Cupcake Egg"

local POGO_GAMEPASSES = {
	["GuidingStar"] = "GuidingStar",
	["NeonArc"] = "NeonArc",
	["PoisonVine"] = "PoisonVine",
}

------------------//MODULES
local ProductsData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("ProductsData"))
local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local EggData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("EggData"))
local PetsData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PetsData"))
local RaritysData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("RaritysData"))

------------------//VARIABLES
local processingPurchases = {}
local megaEggRemote

------------------//FUNCTIONS
local function setupMegaEggRemote()
	local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
	megaEggRemote = remotesFolder:FindFirstChild("MegaEggQueueRemote")

	if not megaEggRemote then
		megaEggRemote = Instance.new("RemoteEvent")
		megaEggRemote.Name = "MegaEggQueueRemote"
		megaEggRemote.Parent = remotesFolder
	end
end

local function giveCoins(player: Player, amount: number)
	local currentCoins = DataUtility.server.get(player, "Coins") or 0
	DataUtility.server.set(player, "Coins", currentCoins + amount)
	print("[SHOP] " .. player.Name .. " recebeu " .. amount .. " moedas")
end

local function givePotion(player: Player, potionId: string)
	local potions = DataUtility.server.get(player, "Potions") or {}
	local currentAmount = potions[potionId] or 0
	potions[potionId] = currentAmount + 1
	DataUtility.server.set(player, "Potions", potions)

	print("[SHOP] " .. player.Name .. " recebeu poção: " .. potionId .. " (total: " .. potions[potionId] .. ")")
end

local function giveBoost(player: Player, boostType: string)
	DataUtility.server.set(player, "Boosts." .. boostType, true)
	print("[SHOP] " .. player.Name .. " recebeu boost: " .. boostType)
end

local function giveGamepassReward(player: Player, dataPath: string)
	DataUtility.server.set(player, dataPath, true)
	print("[SHOP] " .. player.Name .. " recebeu gamepass/path: " .. dataPath)
end

local function givePogo(player: Player, pogoId: string)
	local ownedPogos = DataUtility.server.get(player, "OwnedPogos") or {}

	if not ownedPogos[pogoId] then
		ownedPogos[pogoId] = true
		DataUtility.server.set(player, "OwnedPogos", ownedPogos)
		print("[SHOP] " .. player.Name .. " recebeu pogo: " .. pogoId)
	end
end

local function getRarityTier(rarityName: string): number
	local rarityData = RaritysData[rarityName]
	return rarityData and rarityData.Tier or 0
end

local function applyLuckyBoost(weights: {[string]: number}, luckyMultiplier: number): {[string]: number}
	if luckyMultiplier <= 1 then
		return weights
	end

	local boostedWeights = {}
	local allPets = PetsData.GetAllPets()

	for petName, baseWeight in pairs(weights) do
		local petData = allPets[petName]

		if petData then
			local rarityTier = getRarityTier(petData.Raritys)
			local boostFactor = 1 + (rarityTier * 0.2 * (luckyMultiplier - 1))
			boostedWeights[petName] = baseWeight * boostFactor
		else
			boostedWeights[petName] = baseWeight
		end
	end

	return boostedWeights
end

local function pickWeightedRandomPet(weights: {[string]: number}, luckyMultiplier: number): string
	local weightsToUse = applyLuckyBoost(weights or {}, luckyMultiplier or 1)

	local totalWeight = 0
	local weightedTable = {}

	for petName, weight in pairs(weightsToUse) do
		totalWeight += weight
		table.insert(weightedTable, {
			Name = petName,
			Weight = weight,
			CumulativeWeight = totalWeight,
		})
	end

	if totalWeight <= 0 then
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

local function giveMegaCupcakeEggs(player: Player, amount: number)
	local eggInfo = EggData[MEGA_EGG_KEY]
	if not eggInfo then
		warn("[SHOP] EggData não encontrado para: " .. MEGA_EGG_KEY)
		return
	end

	local luckyMultiplier = player:GetAttribute("Lucky") or 1
	local ownedUpgrades = DataUtility.server.get(player, "OwnedRebirthUpgrades") or {}

	if table.find(ownedUpgrades, "EggLuck") then
		luckyMultiplier += 0.5
	end

	local ownedPets = DataUtility.server.get(player, "OwnedPets") or {}
	local petsToAnimate = {}

	for _ = 1, amount do
		local pickedPet = pickWeightedRandomPet(eggInfo.Weights, luckyMultiplier)

		if pickedPet then
			table.insert(petsToAnimate, pickedPet)

			if not ownedPets[pickedPet] then
				ownedPets[pickedPet] = true
			end

			local currentHatched = DataUtility.server.get(player, "Stats.TotalHatched") or 0
			DataUtility.server.set(player, "Stats.TotalHatched", currentHatched + 1)

			print("[SHOP] " .. player.Name .. " ganhou pet do MegaCupcakeEgg: " .. pickedPet)
		end
	end

	DataUtility.server.set(player, "OwnedPets", ownedPets)

	if megaEggRemote and #petsToAnimate > 0 then
		megaEggRemote:FireClient(player, MEGA_EGG_ANIM_NAME, petsToAnimate)
		print("[SHOP] Remote disparado para " .. player.Name .. " com " .. #petsToAnimate .. " pet(s)")
	end
end

local function giveStarterPack(player: Player)
	local ownedPets = DataUtility.server.get(player, "OwnedPets") or {}
	if not ownedPets["Dragon"] then
		ownedPets["Dragon"] = true
		DataUtility.server.set(player, "OwnedPets", ownedPets)
		print("[SHOP] StarterPack: Dragon entregue para " .. player.Name)
	end

	local ownedPogos = DataUtility.server.get(player, "OwnedPogos") or {}
	if not ownedPogos["GrayGhost"] then
		ownedPogos["GrayGhost"] = true
		DataUtility.server.set(player, "OwnedPogos", ownedPogos)
		print("[SHOP] StarterPack: GrayGhost entregue para " .. player.Name)
	end

	giveCoins(player, 3000)
	givePotion(player, "CoinsPotion")
end

local function processDeveloperProduct(player: Player, productKey: string, productData)
	if not productData or not productData.Rewards then
		warn("[SHOP] Dados de developer product inválidos:", productKey)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local rewards = productData.Rewards
	local grantedSomething = false

	if rewards.Coins then
		giveCoins(player, rewards.Coins)
		grantedSomething = true
	end

	-- Caso seu sistema use Poções
	if rewards.PotionId then
		givePotion(player, rewards.PotionId)
		grantedSomething = true
	end

	-- Caso seu sistema use Boosts.<Tipo> como no segundo script
	if rewards.BoostType and not rewards.PotionId then
		giveBoost(player, rewards.BoostType)
		grantedSomething = true
	end

	if rewards.Egg and rewards.Amount then
		giveMegaCupcakeEggs(player, rewards.Amount)
		grantedSomething = true
	end

	if grantedSomething then
		print("[SHOP] Developer Product processado:", player.Name, "-", productKey)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	warn("[SHOP] Nenhuma recompensa válida encontrada para:", productKey)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function processGamepass(player: Player, gamepassKey: string, gamepassData)
	if not gamepassData then
		warn("[SHOP] Dados de gamepass inválidos:", gamepassKey)
		return
	end

	if gamepassData.DataPath then
		giveGamepassReward(player, gamepassData.DataPath)
	end

	if gamepassKey == "StarterPack" then
		giveStarterPack(player)
	end

	if POGO_GAMEPASSES[gamepassKey] then
		givePogo(player, POGO_GAMEPASSES[gamepassKey])
	end

	print("[SHOP] Gamepass concedido:", player.Name, "-", gamepassKey)
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseKey = tostring(receiptInfo.PlayerId) .. "_" .. tostring(receiptInfo.PurchaseId)
	if processingPurchases[purchaseKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	processingPurchases[purchaseKey] = true

	local productData, productKey = ProductsData.GetProductById(receiptInfo.ProductId)
	if not productData or not productKey then
		warn("[SHOP] Product not found:", receiptInfo.ProductId)
		processingPurchases[purchaseKey] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local result = processDeveloperProduct(player, productKey, productData)

	if result ~= Enum.ProductPurchaseDecision.PurchaseGranted then
		processingPurchases[purchaseKey] = nil
	end

	return result
end

local function onGamepassPurchaseFinished(player: Player, gamepassId: number, wasPurchased: boolean)
	if not wasPurchased then
		return
	end

	local gamepassData, gamepassKey = ProductsData.GetGamepassById(gamepassId)
	if not gamepassData or not gamepassKey then
		warn("[SHOP] Gamepass not found:", gamepassId)
		return
	end

	task.wait(1)

	local success, hasGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)

	if success and hasGamepass then
		processGamepass(player, gamepassKey, gamepassData)
	else
		warn("[SHOP] Falha ao verificar gamepass para", player.Name)
	end
end

local function checkOwnedGamepasses(player: Player)
	task.wait(2)

	for gamepassKey, gamepassData in pairs(ProductsData.Gamepasses) do
		if gamepassData.GamepassId and gamepassData.GamepassId > 0 then
			local success, ownsGamepass = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassData.GamepassId)
			end)

			if success and ownsGamepass then
				local alreadyGranted = false

				if gamepassData.DataPath then
					alreadyGranted = DataUtility.server.get(player, gamepassData.DataPath)
				end

				if not alreadyGranted then
					processGamepass(player, gamepassKey, gamepassData)
				else
					if POGO_GAMEPASSES[gamepassKey] then
						givePogo(player, POGO_GAMEPASSES[gamepassKey])
					end
				end
			end
		end
	end
end

------------------//INIT
setupMegaEggRemote()
DataUtility.server.ensure_remotes()

MarketplaceService.ProcessReceipt = processReceipt
MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamepassPurchaseFinished)

Players.PlayerAdded:Connect(function(player)
	checkOwnedGamepasses(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(checkOwnedGamepasses, player)
end

print("[SHOP] Sistema de produtos inicializado!")