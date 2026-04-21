-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Player = game:GetService("Players").LocalPlayer


-- Modules
local ShopModule = require(ReplicatedStorage.ShopSystem)

-- Events
local Remotes = ReplicatedStorage.Remotes
local EasterShop = Remotes.Easter.EasterShop
local EasterEvent = Remotes.Easter.EasterElevator
local EggsChanged = Remotes.Easter.EggsChanged
local ShopPurchased = Remotes.Easter.EasterShopPurchase

-- Shop Items
local ShopItems = {
	["Gems"] = {Quantity = 5000, Price = 500, Type = "Currency", Currency = "GoldenRepublicCredits"},
	["Crystal"] = {Quantity = 5, Price = 5, Type = "Item", Currency = "GoldenRepublicCredits"},
	["Crystal (Blue)"] = {Quantity = 1, Price = 5, Type = "Item", Currency = "GoldenRepublicCredits"},
	["Crystal (Pink)"] = {Quantity = 1, Price = 5, Type = "Item", Currency = "GoldenRepublicCredits"},
	["Crystal (Green)"] = {Quantity = 1, Price = 5, Type = "Item", Currency = "GoldenRepublicCredits"},
	["Crystal (Red)"] = {Quantity = 1, Price = 5, Type = "Item", Currency = "GoldenRepublicCredits"},
	["Crystal (Celestial)"] = {Quantity = 1, Price = 10, Type = "Item", Currency = "GoldenRepublicCredits"},
	["TraitPoint"] = {Quantity = 25, Price = 500, Type = "Currency", Currency = "GoldenRepublicCredits"},
	["Event Double Luck"] = {Quantity = 1, Price = 500, Type = "Currency", Currency = "GoldenRepublicCredits"},
}

local success = nil

ShopPurchased.OnServerEvent:Connect(function(player, itemName)
	local itemInfo = ShopItems[itemName]
	if not itemInfo then
		warn(player.Name .. " attempted to buy an invalid item: " .. tostring(itemName))
		return
	end


	local playerCurrency = player:FindFirstChild("GoldenRepublicCredits")
	if not playerCurrency then
		warn(player.Name .. " does not have Eggs")
		return
	end


	if playerCurrency.Value >= itemInfo.Price then
		local givenType, givenName, givenQuantity = ShopModule.GiveItem(player, itemName, itemInfo.Quantity, itemInfo.Price, itemInfo.Type, itemInfo.Currency)

		if givenType or givenType == nil then
			ShopPurchased:FireClient(player, givenType, givenName, givenQuantity)
			success = true
		end

	else
		warn(player.Name .. " doesn't have enough Golden Republic Credits to buy " .. itemName)
		ShopPurchased:FireClient(player)
	end
end)


EggsChanged.OnServerEvent:Connect(function(plr)
	EasterShop:FireClient(plr, plr:FindFirstChild("GoldenRepublicCurrency").Value)
end)