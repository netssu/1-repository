

--[[
1913168618 - vip gift 
1913168865 - Display 3 Units (Gift)
1913169131 - Extra Storage (Gift)
1913169455 - Lucky Crystal Potion (Gift)
1913169715 - Fortunate Crystal Potion (Gift)
1913169971 - Mini Pack (Gift)
1913170217 - Small Pack (Gift)
1913170450 - Medium Pack (Gift)
1913170646 - Large Pack (Gift)
1913170928 - Huge Pack (Gift)

897069123 Extra storage
896871562 vip
834202957 dispaly  3 units
]]

local Players = game:GetService("Players")
local MarketPlaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local PurchaseLog = DataStoreService:GetDataStore("PurchaseLog")
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local DiscordHook = require(game.ServerStorage.ServerModules.DiscordWebhook)
local PurchaseHook = DiscordHook.new("PurchaseLog")
--local BrawlPassModule = require(game.ReplicatedStorage.BrawlPass)
local GameAnalytics = require(ReplicatedStorage.GameAnalytics)

local GiftToList = {}
local ChatMessage = game.ReplicatedStorage.Events.Client.ChatMessage
local Message = game.ReplicatedStorage.Events.Client.Message
local PassesList = require(ReplicatedStorage.Modules.PassesList)

game:GetService('Players').PlayerAdded:Connect(function(player)
	repeat task.wait() until not player or player:FindFirstChild('DataLoaded')
	if player and player.Parent then -- hasnt left
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
	local Player = Players:GetPlayerByUserId(PlayerId)
	if not Player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local ProductName, ProductInfo = module.GetInfoById(ProductId)

	local RunFunction
	local IsGamePass
	local IsGift, GiftPlayer
	local PlayerProductKey = `{ReceiptInfo.PlayerId}_{ReceiptInfo.PurchaseId}`

	print('product info:')
	print(ProductInfo)

	if ProductInfo.Id == ProductId then
		print('Normal Product')
		if ProductInfo.IsGamePass then
			print('A')
			RunFunction = PassesList.GamePasses[ProductInfo.Id]  --(Player)
			print(RunFunction)
			print(ProductInfo.Id)
			IsGamePass = true
		else
			print('B')
			RunFunction = PassesList.Products[ProductInfo.Id]  --(ReceiptInfo, Player)
			print(RunFunction)
			print(ProductInfo.Id)

			IsGamePass = false
		end
	elseif ProductInfo.GiftId == ProductId then -- checking if the product is a gift
		GiftPlayer = GiftToList[Player]
		if GiftPlayer == nil or not GiftPlayer:FindFirstChild("DataLoaded") then return Enum.ProductPurchaseDecision.NotProcessedYet end
		IsGift = true
		--GiftPlayer = GiftPlayer
		if ProductInfo.IsGamePass then
			RunFunction = PassesList.GamePasses[ProductInfo.Id]  --(GiftPlayer)

			IsGamePass = true
		else
			RunFunction = PassesList.Products[ProductInfo.Id]  --(ReceiptInfo, GiftPlayer)


			IsGamePass = false
		end
		ChatMessage:FireAllClients(`<font color="rgb(0, 255, 238)"><font face="SourceSans"><i>{Player.DisplayName}</i> has bestowed a generous gift(<b>{ProductName}</b>) upon <i>{GiftPlayer.DisplayName}</i>.</font></font>`)
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	--print( ProductInfo.Id , PassesList.GamePasses[ProductInfo.Id] , RunFunction )

	local success, isPurchaseRecorded = pcall(function()
		return PurchaseLog:UpdateAsync(PlayerProductKey, function(AlreadyPurchased)
			warn(AlreadyPurchased)
			if AlreadyPurchased then return true end

			local success, result 

			if IsGift then
				if GiftPlayer.Parent == nil or not GiftPlayer:FindFirstChild("DataLoaded") then return nil end
				if IsGamePass then
					success, result = pcall(RunFunction, GiftPlayer)
				else
					success, result = pcall(RunFunction, ReceiptInfo, GiftPlayer)
				end
			else
				if Player.Parent == nil or not Player:FindFirstChild("DataLoaded") then return nil end
				if IsGamePass then
					success, result = pcall(RunFunction, Player)
				else

					-- dev products(non gift)
					--warn(RunFunction,ReceiptInfo, Player)
					success, result = pcall(RunFunction, ReceiptInfo, Player)
					print("normal product")
				end
			end
			if not success or not result then
				warn(`Purchase Fail Result: {result}`)
				



				--warn(`PurchaseFail: PurchaseId({ReceiptInfo.PurchaseId}) | PlayerName:{Player.Name} | ProductID: {ProductInfo.Id}`)
				--warn(`Reason: {result}`)
				return false
			else

				local marketplaceInfo = MarketPlaceService:GetProductInfo(ReceiptInfo.ProductId,  Enum.InfoType.Product)
				local priceInRobux = marketplaceInfo and marketplaceInfo.PriceInRobux
				--print(marketplaceInfo, ReceiptInfo)
				if priceInRobux and Player:FindFirstChild("RobuxSpent") then
					Player.RobuxSpent.Value += priceInRobux
				end

				--local PurchaseMessenger = PurchaseHook:NewMessage()
				--local msg = PurchaseMessenger:NewEmbed()
				--msg:SetTitle(`PlayerName: {Player.Name} | PlayerId: {PlayerId}`)
				--msg:AppendLine(IsGift and `Gifted: Yes | GiftedPlayerName: {GiftPlayer.Name} | GiftedPlayerId: {GiftPlayer.UserId}` or `Gifted: No`)
				--msg:AppendLine(`Purchased: {ProductName} | PurchasedId: {ReceiptInfo.PurchaseId}`)
				--msg:AppendLine(`TimeStamp: {DateTime.now():ToIsoDate()}`)
				--PurchaseMessenger:Send()
				--print(`Product Purchase Success: {success} | result: {result}`)
			end
			if Player.Parent == nil or not Player:FindFirstChild("DataLoaded") then return nil end
			return true
		end)
	end)

	warn('is the boy succesful:')
	print(success, isPurchaseRecorded)


	if success and isPurchaseRecorded then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

end

function module.PromptGamePassPurchaseFinished(Player, GamePassId,wasPurhcased)
	warn('gamepass purchased')

	if not wasPurhcased then return end
	warn(wasPurhcased)
	warn(GamePassId)
	warn(Player)

	local marketplaceInfo = MarketPlaceService:GetProductInfo(GamePassId, Enum.InfoType.GamePass)
	local priceInRobux = marketplaceInfo and marketplaceInfo.PriceInRobux
	if priceInRobux and Player:FindFirstChild("RobuxSpent") then
		Player.RobuxSpent.Value += priceInRobux
	end
	
	PassesList.GamePasses[GamePassId](Player)
end
function module.GetInfoById(Id)
	for name, element in PassesList.Information do
		if element.GiftId == Id or element.Id == Id then
			return name, element
		end
	end

	warn('nillll')

	return nil
end

function module.Gift(FromPlayer, ToPlayer, ProductId) -- scrap this, it just gifts another product?????????
	GiftToList[FromPlayer] = ToPlayer

	--local GiftID = module.getGiftID(ProductId)

	local ProductName, ProductInfo = module.GetInfoById(ProductId)
	if not ProductInfo or ProductInfo.GiftId ~= ProductId then return end

	if (ToPlayer.OwnGamePasses:FindFirstChild(ProductName) and ToPlayer.OwnGamePasses[ProductName].Value) and (ProductInfo.IsGamePass or ProductInfo.OneTimePurchase) then
		return 
	end
	if ToPlayer.Parent == nil then return end
	warn('prompting::')
	MarketPlaceService:PromptProductPurchase(FromPlayer, ProductId)
end

function module.GetInfoByName(Name)
	return PassesList.Information[Name]
end

function module.Buy(Player, Id)
	warn('buy')
	local Name, Info = module.GetInfoById(Id)
	if not Info then warn("no info for buy") return end
	if Info.IsGamePass and Player.OwnGamePasses[Name].Value == true then
		warn("user owns gamepass")
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
	if MarketPlaceService:UserOwnsGamePassAsync(UserId,GamePass.Id) then return true end
	repeat task.wait() until Player:FindFirstChild("DataLoaded") --wait for data to load incase someone gifted gamepass

	if Player.OwnGamePasses[GamePassName].Value == true then
		return true
	else
		return false
	end
end

function module.UpdateOwnGamePasses(player)
	for passName, passInfo in PassesList.Information do
		if passInfo.IsGamePass == false then continue end
		local ownGamepass = MarketPlaceService:UserOwnsGamePassAsync(player.UserId, passInfo.Id)
		if not ownGamepass or player.OwnGamePasses[passName].Value then continue end
		PassesList.GamePasses[passInfo.Id](player)
	end
end

MarketPlaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, waspurchased)
	module.PromptGamePassPurchaseFinished(player, id, waspurchased)
end)

return module








