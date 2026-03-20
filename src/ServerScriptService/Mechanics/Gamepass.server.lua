--------------------//SERVICES
--local MarketplaceService = game:GetService("MarketplaceService")
--local Players = game:GetService("Players")
--local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------//CONSTANTS
--local ProductsData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("ProductsData"))
--local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))

--------------------//VARIABLES

--------------------//FUNCTIONS
--local function grantDeveloperProduct(player: Player, productData, productKey: string)
--	if productData.Rewards.Coins then
--		local currentCoins = DataUtility.server.get(player, "Coins") or 0
--		DataUtility.server.set(player, "Coins", currentCoins + productData.Rewards.Coins)
--		return true
--	end

--	if productData.Rewards.BoostType then
--		local boostType = productData.Rewards.BoostType
--		DataUtility.server.set(player, "Boosts." .. boostType, true)
--		return true
--	end

--	return false
--end

--local function grantGamepass(player: Player, gamepassData, gamepassKey: string)
--	if gamepassData.DataPath then
--		DataUtility.server.set(player, gamepassData.DataPath, true)
--		return true
--	end
--	return false
--end

--local function processReceipt(receiptInfo)
--	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
--	if not player then
--		return Enum.ProductPurchaseDecision.NotProcessedYet
--	end

--	local productData, productKey, productType = ProductsData.GetProductById(receiptInfo.ProductId)
--	if not productData then
--		warn("Product not found:", receiptInfo.ProductId)
--		return Enum.ProductPurchaseDecision.NotProcessedYet
--	end

--	local success = grantDeveloperProduct(player, productData, productKey)

--	if success then
--		return Enum.ProductPurchaseDecision.PurchaseGranted
--	else
--		return Enum.ProductPurchaseDecision.NotProcessedYet
--	end
--end

--local function onGamepassPurchase(player: Player, gamepassId: number, wasPurchased: boolean)
--	if not wasPurchased then
--		return
--	end

--	local gamepassData, gamepassKey = ProductsData.GetGamepassById(gamepassId)
--	if not gamepassData then
--		warn("Gamepass not found:", gamepassId)
--		return
--	end

--	grantGamepass(player, gamepassData, gamepassKey)
--end

--local function checkOwnedGamepasses(player: Player)
--	for key, gamepass in pairs(ProductsData.Gamepasses) do
--		if gamepass.GamepassId > 0 then
--			local success, ownsGamepass = pcall(function()
--				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepass.GamepassId)
--			end)

--			if success and ownsGamepass then
--				grantGamepass(player, gamepass, key)
--			end
--		end
--	end
--end

--------------------//INIT
--MarketplaceService.ProcessReceipt = processReceipt
--MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamepassPurchase)

--Players.PlayerAdded:Connect(function(player)
--	task.wait(2)
--	checkOwnedGamepasses(player)
--end)