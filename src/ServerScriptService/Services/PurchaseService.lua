local PurchaseService = {}

-- SERVICES
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

-- CONSTANTS
local RETRY_DELAY = 4

-- VARIABLES
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local ProductsData = require(ReplicatedStorage.Modules.Data.ProductsData)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)

-- FUNCTIONS
local function fulfillProduct(player, productInfo)
	print("PurchaseService: Granting product:", productInfo.Name)

	if productInfo.Action == "Currency" then
		PlayerDataManager:Increment(player, productInfo.RewardPath, productInfo.Amount)
		Packets.PurchaseCompleted:FireClient(player, "Currency", productInfo.Name)
		print("PurchaseService: Currency granted successfully")
		return true
	elseif productInfo.Action == "OpenCard" then
		Packets.PurchaseCompleted:FireClient(player, "OpenCard", productInfo.CardType)

		task.delay(RETRY_DELAY, function()
			local PackService = require(ServerScriptService.Services.PackService)
			local rolledItem, _reason = PackService.RollGacha(player, productInfo.CardType)

			if rolledItem then
				local itemJson = HttpService:JSONEncode(rolledItem)
				Packets.Summon:FireClient(player, "ROBUX|" .. productInfo.CardType .. "|" .. itemJson)
			else
				Packets.PurchaseCompleted:FireClient(player, "Error", "Failed to generate item.")
			end
		end)
		return true
	elseif productInfo.Action == "InventoryItem" then
		local InventoryService = require(ServerScriptService.Services.InventoryService)
		local itemType = productInfo.ItemType
		local itemName = productInfo.ItemName

		if type(itemType) ~= "string" or type(itemName) ~= "string" then
			warn("PurchaseService: Invalid inventory reward for product:", productInfo.Name)
			return false
		end

		local wasGranted = InventoryService:GiveItem(player, itemType, itemName)
		if wasGranted then
			Packets.PurchaseCompleted:FireClient(player, "InventoryItem", itemName)
			print("PurchaseService: Inventory item granted successfully")
		end

		return wasGranted
	elseif productInfo.Action == "InventoryPack" then
		local InventoryService = require(ServerScriptService.Services.InventoryService)
		local items = productInfo.Items

		if type(items) ~= "table" then
			warn("PurchaseService: Invalid inventory pack reward for product:", productInfo.Name)
			return false
		end

		local wasGranted = InventoryService:GiveItems(player, items)
		if wasGranted then
			Packets.PurchaseCompleted:FireClient(player, "InventoryPack", productInfo.Name)
			print("PurchaseService: Inventory pack granted successfully")
		end

		return wasGranted
	elseif productInfo.Action == "UnlockSlot" then
		local SlotService = require(ServerScriptService.Services.SlotService)
		local slotType = productInfo.SlotType

		if type(slotType) ~= "string" or slotType == "" then
			warn("PurchaseService: Invalid slot unlock reward for product:", productInfo.Name)
			return false
		end

		local result = SlotService.GrantNextSlot(player, slotType)
		if result and result.Success then
			Packets.PurchaseCompleted:FireClient(player, "UnlockSlot", productInfo.Name)
			return true
		end

		warn("PurchaseService: Failed to grant slot unlock for product:", productInfo.Name, result and result.ErrorCode)
		return false
	elseif productInfo.Category == "GamePass" then
		local categoryName = productInfo.RewardPath[1]
		local passKey = productInfo.RewardPath[2]

		local gamePassTable = PlayerDataManager:Get(player, { categoryName })

		if gamePassTable then
			gamePassTable[passKey] = true
			PlayerDataManager:Set(player, { categoryName }, gamePassTable)

			print("PurchaseService: GamePass saved in player data ->", passKey)
			Packets.PurchaseCompleted:FireClient(player, "GamePass", productInfo.Name)
			return true
		else
			warn("PurchaseService: Critical error - GamePass table not found in player data.")
		end
	end

	return false
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productInfo = ProductsData.GetProductInfo(receiptInfo.ProductId)
	if not productInfo then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local success, result = pcall(function()
		return fulfillProduct(player, productInfo)
	end)

	if success and result then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

local function onGamePassPurchase(player, gamePassId, wasPurchased)
	if wasPurchased then
		local productInfo = ProductsData.GetProductInfo(gamePassId)
		if productInfo then
			fulfillProduct(player, productInfo)
		end
	else
		Packets.PurchaseCompleted:FireClient(player, "Error", "GamePass purchase canceled")
	end
end

-- INIT
function PurchaseService:Init()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchase)
	print("PurchaseService: Payment system started.")
end

return PurchaseService
