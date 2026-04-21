local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RaidShopPurchase = ReplicatedStorage.Remotes.Raid.RaidShopPurchase
local CreditsChanged = ReplicatedStorage.Remotes.Raid.CreditsChanged
local LoadingData = require(ReplicatedStorage.Modules.LoadingRaidShopData)
local ShopSystem = require(ReplicatedStorage.ShopSystem)


local ShopItems = {
	["Killer Helmet"] = {Quantity = 1, Price = 200, Type = "Item", Currency = "Credits"},
	["TraitPoint"] = {Quantity = 25, Price = 50, Type = "Currency", Currency = "Credits"},
	["Gems"] = {Quantity = 2500, Price = 50, Type = "Currency", Currency = "Credits"},
	["x2 Buff"] = {Quantity = 1, Price = 30, Type = "Buff", Currency = "Credits"},
	["x3 Buff"] = {Quantity = 1, Price = 50, Type = "Buff", Currency = "Credits"},
	["Lucky Crystal"] = {Quantity = 1, Price = 15, Type = "Item", Currency = "Credits"},
	["Fortunate Crystal"] = {Quantity = 1, Price = 30, Type = "Item", Currency = "Credits"},
	["2x Coins"] = {Quantity = 1, Price = 20, Type = "Item", Currency = "Credits"},
	["2x Gems"] = {Quantity = 1, Price = 50, Type = "Item", Currency = "Credits"},
	["2x XP"] = {Quantity = 1, Price = 25, Type = "Item", Currency = "Credits"},
	["RaidsRefresh"] = {Quantity = 1, Price = 100, Type = "Currency", Currency = "Credits"},
	["Junk Offering"] = {Quantity = 1, Price = 200, Type = "Item", Currency = "Credits"},
	
	
	-- Add Junk Offering
	-- Raids Refresh
}


CreditsChanged.OnServerEvent:Connect(function(player)
	local credits = player:FindFirstChild("RaidData") and player.RaidData:FindFirstChild("Credits")
	if credits then
		CreditsChanged:FireClient(player, credits.Value)
	end
end)


RaidShopPurchase.OnServerEvent:Connect(function(player, itemName)
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
		RaidShopPurchase:FireClient(player, givenType, givenName, givenQuantity)
	end
end)
