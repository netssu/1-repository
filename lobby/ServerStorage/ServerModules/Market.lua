local Players = game:GetService("Players")
local MarketPlaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local PurchaseLog = DataStoreService:GetDataStore("PurchaseLog")
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local DiscordHook = require(game.ServerStorage.ServerModules.DiscordWebhook)
local PurchaseHook = DiscordHook.new("PurchaseLog")
local GameAnalytics = require(ReplicatedStorage.GameAnalytics)

local GiftToList = {}
local ChatMessage = game.ReplicatedStorage.Events.Client.ChatMessage
local Message = game.ReplicatedStorage.Events.Client.Message
local PassesList = require(ReplicatedStorage.Modules.PassesList)

local ProcessingPurchases = {}

game:GetService('Players').PlayerAdded:Connect(function(player)
	repeat task.wait() until not player or player:FindFirstChild('DataLoaded')
	if player and player.Parent then
		for i, v in PassesList.Information do
			if v.IsGamePass then
				if MarketPlaceService:UserOwnsGamePassAsync(player.UserId,v.Id) and player.OwnGamePasses:FindFirstChild(i) then
					player.OwnGamePasses[i].Value = true
				end
			end
		end
	end
end)

local module = {}

function module.ProcessReceipt(ReceiptInfo)
	warn('devproduct purchased')
	warn(ReceiptInfo)

	local PlayerId = ReceiptInfo.PlayerId
	local ProductId = ReceiptInfo.ProductId
	local PurchaseId = ReceiptInfo.PurchaseId
	local Player = Players:GetPlayerByUserId(PlayerId)

	if not Player then 
		warn("Player not found for purchase")
		return Enum.ProductPurchaseDecision.NotProcessedYet 
	end

	local ProcessingKey = `{PlayerId}_{PurchaseId}`
	if ProcessingPurchases[ProcessingKey] then
		warn("Purchase already being processed:", ProcessingKey)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	ProcessingPurchases[ProcessingKey] = true

	local ProductName, ProductInfo = module.GetInfoById(ProductId)
	if not ProductInfo then
		ProcessingPurchases[ProcessingKey] = nil
		warn("No product info found for ID:", ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local RunFunction
	local IsGamePass
	local IsGift, GiftPlayer
	local PlayerProductKey = `{PlayerId}_{PurchaseId}`

	print('product info:')
	print(ProductInfo)

	if ProductInfo.Id == ProductId then
		print('Normal Product')
		if ProductInfo.IsGamePass then
			RunFunction = PassesList.GamePasses[ProductInfo.Id]
			IsGamePass = true
		else
			RunFunction = PassesList.Products[ProductInfo.Id]
			IsGamePass = false
		end
	elseif ProductInfo.GiftId == ProductId then
		GiftPlayer = GiftToList[Player]
		if GiftPlayer == nil or not GiftPlayer:FindFirstChild("DataLoaded") then 
			ProcessingPurchases[ProcessingKey] = nil
			return Enum.ProductPurchaseDecision.NotProcessedYet 
		end
		IsGift = true
		if ProductInfo.IsGamePass then
			RunFunction = PassesList.GamePasses[ProductInfo.Id]
			IsGamePass = true
		else
			RunFunction = PassesList.Products[ProductInfo.Id]
			IsGamePass = false
		end
		ChatMessage:FireAllClients(`<font color="rgb(0, 255, 238)"><font face="SourceSans"><i>{Player.DisplayName}</i> has bestowed a generous gift(<b>{ProductName}</b>) upon <i>{GiftPlayer.DisplayName}</i>.</font></font>`)
	else
		ProcessingPurchases[ProcessingKey] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local success, isPurchaseRecorded = pcall(function()
		local alreadyProcessed = PurchaseLog:GetAsync(PlayerProductKey)
		if alreadyProcessed then
			warn("Purchase already processed:", PlayerProductKey)
			return true
		end

		if Player.Parent == nil or not Player:FindFirstChild("DataLoaded") then
			warn("Buyer left game during processing")
			return false
		end

		if IsGift and (GiftPlayer.Parent == nil or not GiftPlayer:FindFirstChild("DataLoaded")) then
			warn("Gift recipient left game during processing")
			return false
		end

		--local functionSuccess, functionResult 
		--local targetPlayer = IsGift and GiftPlayer or Player

		--if IsGamePass then
		--	functionSuccess, functionResult = pcall(RunFunction, targetPlayer)
		--else
		--	functionSuccess, functionResult = pcall(RunFunction, ReceiptInfo, targetPlayer)
		--end
		
		
		local functionSuccess, functionResult 
		local targetPlayer = IsGift and GiftPlayer or Player

		if IsGamePass then
			functionSuccess, functionResult = pcall(RunFunction, targetPlayer)
		else
			functionSuccess, functionResult = pcall(RunFunction, ReceiptInfo, targetPlayer)
		end

		if not functionSuccess then
			warn(`Purchase Function Threw Error: {functionResult}`)
			return false
		end

		if not functionResult then
			warn("Reward function didn't explicitly return true — assuming success anyway")
		end

		spawn(function()
			pcall(function()
				PurchaseLog:SetAsync(PlayerProductKey, true)
			end)
		end)

		warn("Purchase processed successfully")
		
		
		

		if not functionSuccess or not functionResult then
			warn(`Purchase Function Failed: {functionResult}`)
			warn(`PurchaseId: {PurchaseId} | PlayerName: {Player.Name} | ProductID: {ProductInfo.Id}`)
			return false
		end

		local marketplaceInfo = MarketPlaceService:GetProductInfo(ProductId, Enum.InfoType.Product)
		local priceInRobux = marketplaceInfo and marketplaceInfo.PriceInRobux
		if priceInRobux and Player:FindFirstChild("RobuxSpent") then
			Player.RobuxSpent.Value += priceInRobux
		end

		spawn(function()
			pcall(function()
				PurchaseLog:SetAsync(PlayerProductKey, true)
			end)
		end)

		warn("Purchase processed successfully")
		return true
	end)

	ProcessingPurchases[ProcessingKey] = nil

	warn('Purchase processing result:')
	print(success, isPurchaseRecorded)

	if success and isPurchaseRecorded then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn(`Purchase processing failed - Success: {success}, Recorded: {isPurchaseRecorded}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

function module.PromptGamePassPurchaseFinished(Player, GamePassId, wasPurchased)
	warn('gamepass purchase finished')

	if not wasPurchased then return end

	if not Player.Parent or not Player:FindFirstChild("DataLoaded") then
		warn("Player left before gamepass could be processed")
		return
	end

	local marketplaceInfo = MarketPlaceService:GetProductInfo(GamePassId, Enum.InfoType.GamePass)
	local priceInRobux = marketplaceInfo and marketplaceInfo.PriceInRobux
	if priceInRobux and Player:FindFirstChild("RobuxSpent") then
		Player.RobuxSpent.Value += priceInRobux
	end

	local gamepassFunction = PassesList.GamePasses[GamePassId]
	if gamepassFunction then
		local success, result = pcall(gamepassFunction, Player)
		if not success then
			warn(`Gamepass function failed: {result}`)
		end
	end
end

function module.GetInfoById(Id)
	for name, element in PassesList.Information do
		if element.GiftId == Id or element.Id == Id then
			return name, element
		end
	end
	warn('Product info not found for ID:', Id)
	return nil, nil
end

function module.Gift(FromPlayer, ToPlayer, ProductId)
	GiftToList[FromPlayer] = ToPlayer

	local ProductName, ProductInfo = module.GetInfoById(ProductId)
	if not ProductInfo or ProductInfo.GiftId ~= ProductId then 
		warn("Invalid gift product ID")
		return 
	end

	if (ToPlayer.OwnGamePasses:FindFirstChild(ProductName) and ToPlayer.OwnGamePasses[ProductName].Value) and (ProductInfo.IsGamePass or ProductInfo.OneTimePurchase) then
		warn("Recipient already owns this item")
		return 
	end

	if ToPlayer.Parent == nil then 
		warn("Gift recipient is not in game")
		return 
	end

	warn('Prompting gift purchase')
	MarketPlaceService:PromptProductPurchase(FromPlayer, ProductId)
end

function module.GetInfoByName(Name)
	return PassesList.Information[Name]
end

function module.Buy(Player, Id)
	warn('Initiating purchase for player:', Player.Name)
	local Name, Info = module.GetInfoById(Id)
	if not Info then 
		warn("No product info found for purchase")
		return 
	end

	if Info.IsGamePass and Player.OwnGamePasses[Name] and Player.OwnGamePasses[Name].Value == true then
		warn("User already owns this gamepass")
		return
	end

	if Info.IsGamePass then
		MarketPlaceService:PromptGamePassPurchase(Player, Id)
	else
		MarketPlaceService:PromptProductPurchase(Player, Id)
	end
end

function module.CheckOwnGamePass(Player, GamePassName)
	local GamePass = PassesList.Information[GamePassName]
	if not GamePass then return nil end
	local UserId = Player.UserId
	if MarketPlaceService:UserOwnsGamePassAsync(UserId, GamePass.Id) then return true end
	repeat task.wait() until Player:FindFirstChild("DataLoaded")

	if Player.OwnGamePasses[GamePassName] and Player.OwnGamePasses[GamePassName].Value == true then
		return true
	else
		return false
	end
end

function module.UpdateOwnGamePasses(player)
	for passName, passInfo in PassesList.Information do
		if passInfo.IsGamePass == false then continue end
		local ownGamepass = MarketPlaceService:UserOwnsGamePassAsync(player.UserId, passInfo.Id)
		if not ownGamepass or (player.OwnGamePasses[passName] and player.OwnGamePasses[passName].Value) then continue end
		local gamepassFunction = PassesList.GamePasses[passInfo.Id]
		if gamepassFunction then
			pcall(gamepassFunction, player)
		end
	end
end

MarketPlaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, waspurchased)
	module.PromptGamePassPurchaseFinished(player, id, waspurchased)
end)

return module