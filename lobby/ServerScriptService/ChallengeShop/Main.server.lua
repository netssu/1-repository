local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ChallengePurchase = ReplicatedStorage.Events.Challenges.ChallengePurchase
local CreditsChanged = ReplicatedStorage.Events.Challenges.CheckCurrency
local LoadingData = require(ReplicatedStorage.Modules.LoadingRaidShopData)
local ShopSystem = require(ReplicatedStorage.ShopSystem)


local ShopItems = {
	["Crystal (Red)"] = {Quantity = 1, Price = 6, Type = "Item", Currency = "RepublicCredits"},
	["Crystal (Blue)"] = {Quantity = 1, Price = 6, Type = "Item", Currency = "RepublicCredits"},
	["Crystal (Pink)"] = {Quantity = 1, Price = 6, Type = "Item", Currency = "RepublicCredits"},
	["Crystal (Green)"] = {Quantity = 1, Price = 6, Type = "Item", Currency = "RepublicCredits"},
	["Crystal (Celestial)"] = {Quantity = 1, Price = 7, Type = "Item", Currency = "RepublicCredits"},
	["Crystal"] =  {Quantity = 3, Price = 6, Type = "Item", Currency = "RepublicCredits"},
	["Lucky Crystal"] = {Quantity = 1, Price = 35, Type = "Item", Currency = "RepublicCredits"},
	["Fortunate Crystal"] = {Quantity = 1, Price = 40, Type = "Item", Currency = "RepublicCredits"},
	["Gems"] = {Quantity = 1000, Price = 100, Type = "Currency", Currency = "RepublicCredits"},
	["TraitPoint"] = {Quantity = 5, Price = 60, Type = "Currency", Currency = "RepublicCredits"},
	["Credits"] = {Quantity = 25, Price = 25, Type = "Currency", Currency = "RepublicCredits"},
	["Sixth Brother"] = {Quantity = 1, Price = 1000, Type = "Units", Currency = "RepublicCredits"}
	
	
	-- Raids Refresh
}


CreditsChanged.OnServerInvoke = function (player)
	local credits = player:FindFirstChild("RepublicCredits")
	if credits then
		return credits.Value
	end
end


ChallengePurchase.OnServerEvent:Connect(function(player, itemName)
	warn(itemName)
	local itemInfo = ShopItems[itemName]

	
	if not itemInfo then
		warn(player.Name .. " tried to purchase an invalid item: " .. tostring(itemName))
		return
	end

	local itemType = itemInfo.Type
	local quantity = itemInfo.Quantity
	local price = itemInfo.Price
	local currency = itemInfo.Currency

	print(player, itemName, quantity, price, itemType, currency)
	local givenType, givenName, givenQuantity = ShopSystem.GiveItem(
		player,
		itemName,
		quantity,
		price,
		itemType,
		currency
	)

	
	print(givenType)
	
	if givenType or givenType == nil then
		ChallengePurchase:FireClient(player, givenType, givenName, givenQuantity)
	end
end)
