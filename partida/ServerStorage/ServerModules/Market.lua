

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

local DiscordHook = require(game.ServerStorage.ServerModules.DiscordWebhook)
local PurchaseHook = DiscordHook.new("PurchaseLog")
--local BrawlPassModule = require(game.ReplicatedStorage.BrawlPass)

local GiftToList = {}
local ChatMessage = game.ReplicatedStorage.Events.Client.ChatMessage
local Message = game.ReplicatedStorage.Events.Client.Message
local PassesList = {
	Products = {
		[3221509781] = function(ReceiptInfo, Player)	--Mini Pack
			Player.Gems.Value += 50
			return true
		end,
		[3221510072] = function(ReceiptInfo, Player)	--Small Pack
			Player.Gems.Value += 250
			return true
		end,
		[3221510368] = function(ReceiptInfo, Player)	--Medium Pack
			Player.Gems.Value += 475
			return true
		end,
		[3221510579] = function(ReceiptInfo, Player)	--Large Pack
			Player.Gems.Value += 975
			return true
		end,
		[3221510847] = function(ReceiptInfo, Player)	--Huge Pack
			Player.Gems.Value += 2000
			return true
		end,
		[3221511117] = function(ReceiptInfo, Player)	--Massive Pack
			Player.Gems.Value += 5000
			return true
		end,
		[3221511460] = function(ReceiptInfo, Player)	--Colossal Pack
			Player.Gems.Value += 10000
			return true
		end,

		[3221514046] = function(ReceiptInfo, Player)    --Fortunate Crystal
			Player.Items["Fortunate Crystal"].Value += 1
			return true
		end,
		[3221514284] = function(ReceiptInfo, Player)    --Lucky Crystal
			Player.Items["Lucky Crystal"].Value += 1
			return true
		end,
		[3221515245] = function(ReceiptInfo, Player) -- x1 WillPowers
			Player["TraitPoint"].Value += 1
			return true
		end,
		[3250974753] = function(ReceiptInfo, Player) -- x10 WillPowers
			Player["TraitPoint"].Value += 10
			return true
		end,
		[3250975033] = function(ReceiptInfo, Player) -- x25 WillPowers
			Player["TraitPoint"].Value += 25
			return true
		end,
		[3250975313] = function(ReceiptInfo, Player) -- x50 WillPowers
			Player["TraitPoint"].Value += 50
			return true
		end,
		[3250976109] = function(ReceiptInfo, Player) -- x100 WillPowers
			Player["TraitPoint"].Value += 100
			return true
		end,
		[2659785711] = function(ReceiptInfo, Player) --Starter Pack
			if Player.OwnGamePasses["Starter Pack"].Value == true then
				return false
			end
			Player.OwnGamePasses["Starter Pack"].Value = true
			Player["TraitPoint"].Value += 5
			Player["Gems"].Value += 500
			_G.createTower(Player.OwnedTowers,"Frenk")
			return true
		end,
		--[2671779391] = function(ReceiptInfo, Player) -- Brawl Pass
		--	if Player.BrawlPass[game.ReplicatedStorage.CurrentPassName.Value].Premium.Value == false then
		--		Player.BrawlPass[game.ReplicatedStorage.CurrentPassName.Value].Premium.Value = true
		--		return true
		--	else
		--		return false
		--	end
		--end,
		--[2671780357] = function(ReceiptInfo, Player) -- Skip 1 level
		--	local level = 0
		--	local previousRequiredExp = 0
		--	local requiredExp = nil
		--	local BrawlPassStats = Player:WaitForChild("BrawlPass"):WaitForChild(game.ReplicatedStorage.CurrentPassName.Value)
		--	for i, v in BrawlPassModule.FreePass do
		--		if BrawlPassStats.Exp.Value >= v.RequiredExp then
		--			level = i
		--			previousRequiredExp = v.RequiredExp
		--		else
		--			requiredExp = v.RequiredExp
		--			break
		--		end
		--	end
		--	if requiredExp == nil then
		--		return false
		--	end
		--	BrawlPassStats.Exp.Value += requiredExp-previousRequiredExp
		--	return true
		--end,
		--[2671780106] = function(ReceiptInfo, Player) -- Skip 10 levels
		--	local levels = 0
		--	for i = 1, 10 do
		--		local level = 0
		--		local previousRequiredExp = 0
		--		local requiredExp = nil
		--		local BrawlPassStats = Player:WaitForChild("BrawlPass"):WaitForChild(game.ReplicatedStorage.CurrentPassName.Value)
		--		for i, v in BrawlPassModule.FreePass do
		--			if BrawlPassStats.Exp.Value >= v.RequiredExp then
		--				level = i
		--				previousRequiredExp = v.RequiredExp
		--			else
		--				requiredExp = v.RequiredExp
		--				break
		--			end
		--		end
		--		if requiredExp == nil then
		--			break
		--		end
		--		BrawlPassStats.Exp.Value += requiredExp-previousRequiredExp
		--		levels += 1
		--	end
		--	if levels == 0 then
		--		return false
		--	end
		--	return true
		--end,
		[3250033230] = function(ReceiptInfo, Player)	--2x Coin Boost [1HR]
			local item = Player.Items:FindFirstChild("2x Coins")
			item.Value += 1
			return true
		end,
		[3250040699] = function(ReceiptInfo, Player)	--2x Gem Boost [1HR]
			local item = Player.Items:FindFirstChild("2x Gems")
			item.Value += 1
			return true
		end,
		[3250657727] = function(ReceiptInfo, Player)	--2x XP Boost [1HR]
			local item = Player.Items:FindFirstChild("2x XP")
			item.Value += 1
			return true
		end
	},
	GamePasses = {
		
		[1073932053] = function(Player)	--Extra Storage
			Player.OwnGamePasses["Extra Storage"].Value = true
			Player.MaxUnits.Value = 200
			return true
		end,
		[1075876861] = function(Player)	--VIP
			Player.OwnGamePasses["VIP"].Value = true
			
			local character = Player.Character
			local overhead = character and character.Head:FindFirstChild("_overhead") or false
			if overhead and Player.OwnGamePasses["Ultra VIP"] == false then
				overhead.Frame.Tag_Frame.Visible = true
				overhead.Frame.Tag_Frame.Tag_Text.VIP_Gradient.Enabled = true
				overhead.Frame.Tag_Frame.Tag_Text.Text = `[VIP]`
				overhead.Frame.Name_Frame.Name_Text.VIP_Gradient.Enabled = true
			end
			
			return true
		end,
		[1124382194] = function(Player)	--Shiny Hunter
			Player.OwnGamePasses["Shiny Hunter"].Value = true
			return true
		end,
		[1076274359] = function(Player)	--Display 3 Units
			Player.OwnGamePasses["Display 3 Units"].Value = true
			return true
		end,
		[1073834237] = function(Player)	--x2 gems
			Player.OwnGamePasses["x2 Gems"].Value = true
			return true
		end,
		[1129844558] = function(Player) -- Ultra VIP
			print("Run")
			Player.OwnGamePasses["Ultra VIP"].Value = true

			local character = Player.Character
			local overhead = character and character.Head:FindFirstChild("_overhead") or false
			if overhead then
				overhead.Frame.Tag_Frame.Visible = true
				overhead.Frame.Tag_Frame.Tag_Text.UltraVIP_Gradient.Enabled = true
				overhead.Frame.Tag_Frame.Tag_Text.Text = `[ULTRA VIP]`
				overhead.Frame.Name_Frame.Name_Text.UltraVIP_Gradient.Enabled = true
			end

			return true
		end,
		[1131208944] = function(Player) --2x Player XP
			Player.OwnGamePasses["2x Player XP"].Value = true
			return true
		end,
		[1130276690] = function(Player) --2x Speed
			Player.OwnGamePasses["2x Speed"].Value = true
			return true
		end,
		[1131922338] = function(Player) --2x Speed
			Player.OwnGamePasses["3x Speed"].Value = true
			return true
		end
	},
	Information = {
		["2x Speed"] = {
			Id = 1130276690,
			GiftId = 3250930885,
			IsGamePass = true
		},
		["3x Speed"] = {
			Id = 1131922338,
			GiftId = 3250931174,
			IsGamePass = true
		},
		["2x Player XP"] = {
			Id = 1131208944,
			GiftId = 3250425539,
			IsGamePass = true
		},
		["2x Gems Boost [1HR]"] = {
			Id = 3250040699,
			GiftId = 3250424523,
			IsGamePass = false
		},
		["2x Coins Boost [1HR]"] = {
			Id = 3250033230,
			GiftId = 3250425057,
			IsGamePass = false
		},
		["2x XP Boost [1HR]"] = {
			Id = 3250657727,
			GiftId = 3250658664,
			IsGamePass = false
		},
		["Extra Storage"] = {
			Id = 1073932053,
			GiftId = 3221502849,
			IsGamePass = true
		},
		["VIP"] = {
			Id = 1075876861,
			GiftId = 3221502483,
			IsGamePass = true
		},
		["Ultra VIP"] = {
			Id = 1129844558,
			GiftId = 3250370990,
			IsGamePass = true
		},
		["Shiny Hunter"] = {
			Id = 1124382194,
			GiftId = 3249453567,
			IsGamePass = true
		},
		["Display 3 Units"] = {
			Id = 1076274359,
			GiftId = 3221504033,
			IsGamePass = true
		},
		["Mini Pack"] = {
			Id = 3221509781,
			GiftId = 3221509872,
			IsGamePass = false
		},
		["Small Pack"] = {
			Id = 3221510072,
			GiftId = 3221510177,
			IsGamePass = false
		},
		["Medium Pack"] = {
			Id = 3221510368,
			GiftId = 3221510457,
			IsGamePass = false
		},
		["Large Pack"] = {
			Id = 3221510579,
			GiftId = 3221510734,
			IsGamePass = false
		},
		["Huge Pack"] = {
			Id = 3221510847,
			GiftId = 3221510962,
			IsGamePass = false
		},
		["Massive Pack"] = {
			Id = 3221511117,
			GiftId = 3221511235,
			IsGamePass = false
		},
		["Colossal Pack"] = {
			Id = 3221511460,
			GiftId = 3221511561,
			IsGamePass = false
		},
		["Huge Winter Bundle"] = {
			Id = 2675907803,
			GiftId = 2675907933,
			IsGamePass = false
		},
		["Large Winter Bundle"] = {
			Id = 2678784918,
			GiftId = 2678785105,
			IsGamePass = false
		},
		["Medium Winter Bundle"] = {
			Id = 2678786531,
			GiftId = 2678786670,
			IsGamePass = false
		},
		["Small Winter Bundle"] = {
			Id = 2678798950,
			GiftId = 2678799339,
			IsGamePass = false
		},
		["Fortunate Crystal"] = {
			Id = 3221514046,
			GiftId = 3221514154,
			IsGamePass = false
		},
		["Lucky Crystal"] = {
			Id = 3221514284,
			GiftId = 3221514395,
			IsGamePass = false
		},
		["RobuxTraitPoint"] = {
			Id = 3221515245,
			IsGamePass = false
		},
		["x10 WillPowers"] = {
			Id = 3250974753,
			GiftId = 3250974889,
			IsGamePass = false
		},
		["x25 WillPowers"] = {
			Id = 3250975033,
			GiftId = 3250975142,
			IsGamePass = false
		},
		["x50 WillPowers"] = {
			Id = 3250975313,
			GiftId = 3250975577,
			IsGamePass = false
		},
		["x100 WillPowers"] = {
			Id = 3250976109,
			GiftId = 3250976527,
			IsGamePass = false
		},
		["Starter Pack"] = {
			Id = 2659785711,
			GiftId = 2659791350,
			IsGamePass = false,
			OneTimePurchase = true,
		},
		["Buy Brawl Pass"] = {
			Id = 2671779391,
			GiftId = 2671779646,
			IsGamePass = false,
			OneTimePurchase = true,
		},
		["x2 Gems"] = {
			Id = 1073834237,
			GiftId = 3221507404,
			IsGamePass = true
		},
		["Skip1Lvl"] = {
			Id = 2671780357,
			GiftId = 2671780492,
			IsGamePass = false
		},
		["Skip10Lvl"] = {
			Id = 2671780106,
			GiftId = 2671780224,
			IsGamePass = false
		},
	}
}

game.Players.PlayerAdded:Connect(function(player)
	player:WaitForChild("DataLoaded")
	for i, v in PassesList.Information do
		if v.IsGamePass then
			if MarketPlaceService:UserOwnsGamePassAsync(player.UserId,v.Id) and player.OwnGamePasses:FindFirstChild(i) then
				player.OwnGamePasses[i].Value = true
			end
		end
	end
end)

local module = {}

function module.ProcessReceipt(ReceiptInfo)

	local PlayerId = ReceiptInfo.PlayerId
	local ProductId = ReceiptInfo.ProductId
	local Player = Players:GetPlayerByUserId(PlayerId)
	if not Player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local ProductName, ProductInfo = module.GetInfoById(ProductId)

	local RunFunction
	local IsGamePass
	local IsGift, GiftPlayer
	local PlayerProductKey = `{ReceiptInfo.PlayerId}_{ReceiptInfo.PurchaseId}`

	if ProductInfo.Id == ProductId then
		if ProductInfo.IsGamePass then
			RunFunction = PassesList.GamePasses[ProductInfo.Id]  --(Player)
			IsGamePass = true
		else
			RunFunction = PassesList.Products[ProductInfo.Id]  --(ReceiptInfo, Player)
			IsGamePass = false
		end
	elseif ProductInfo.GiftId == ProductId then
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

	local success, isPurchaseRecorded = pcall(function()
		return PurchaseLog:UpdateAsync(PlayerProductKey, function(AlreadyPurchased)
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
					success, result = pcall(RunFunction, ReceiptInfo, Player)
				end
			end
			if not success or not result then
				--warn(`Purchase Fail Result: {result}`)
				
				
				
				warn(`PurchaseFail: PurchaseId({ReceiptInfo.PurchaseId}) | PlayerName:{Player.Name}`)
				warn(`Reason: {result}`)
				return false
			else
				
				local marketplaceInfo = MarketPlaceService:GetProductInfo(ReceiptInfo.ProductId,  Enum.InfoType.Product)
				local priceInRobux = marketplaceInfo and marketplaceInfo.PriceInRobux
				print(marketplaceInfo, ReceiptInfo)
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


	print(success, isPurchaseRecorded)

	if success and isPurchaseRecorded then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end


end

function module.PromptGamePassPurchaseFinished(Player, GamePassId,wasPurhcased)

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

	return nil

end

function module.Gift(FromPlayer, ToPlayer, ProductId)
	GiftToList[FromPlayer] = ToPlayer

	local ProductName, ProductInfo = module.GetInfoById(ProductId)
	if not ProductInfo or ProductInfo.GiftId ~= ProductId then return end
	if ProductInfo.IsGamePass and ToPlayer.OwnGamePasses[ProductName].Value == true then
		return 
	end
	if ToPlayer.Parent == nil then return end
	MarketPlaceService:PromptProductPurchase(FromPlayer, ProductId)
end

function module.GetInfoByName(Name)
	return PassesList.Information[Name]
end

function module.Buy(Player, Id)

	local Name, Info = module.GetInfoById(Id)
	
	if not Info then return end
	if Info.IsGamePass and Player.OwnGamePasses[Name].Value == true then
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

return module








