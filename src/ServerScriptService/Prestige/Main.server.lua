local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PrestigeHandling = require(ReplicatedStorage.Prestige.Main.PrestigeHandling)
local PrestigeCalculate = ReplicatedStorage.Remotes.Prestige.PrestigeCalculate
local PrestigeReset = ReplicatedStorage.Remotes.Prestige.PrestigeReset
local ShopModule = require(ReplicatedStorage.ShopSystem)
local ShopUnit = ReplicatedStorage.Remotes.ShopUnit
local PrestigeTokenChanged = ReplicatedStorage.Remotes.Prestige.PrestigeTokenChanged
PrestigeCalculate.OnServerEvent:Connect(function(LocalPlayer)
	print("Working PRestige")
	PrestigeHandling.CalculatePrestige(LocalPlayer)
end)

PrestigeReset.OnServerEvent:Connect(function(LocalPlayer)
	local Prestige = LocalPlayer:FindFirstChild("Prestige")
	PrestigeHandling.Reset(LocalPlayer.Character, LocalPlayer:FindFirstChild("PlayerLevel").Value, Prestige.Value)
end)


local ShopItems = {
	["TraitPoint"] = {Quantity = 25, Price = 1, Type = "Currency", Currency = "PrestigeTokens"},
	["LuckySpins"] = {Quantity = 10, Price = 5, Type = "Currency", Currency = "PrestigeTokens"},
	["LuckyWillpower"] = {Quantity = 5, Price = 10, Type = "Currency", Currency = "PrestigeTokens"},
	["VIP"] = {Quantity = 1, Price = 20, Type = "Gamepasses", Currency = "PrestigeTokens"},
	["2x Speed"] = {Quantity = 1, Price = 12, Type = "Gamepasses", Currency = "PrestigeTokens"},
	["3x Speed"] = {Quantity = 1, Price = 30, Type = "Gamepasses", Currency = "PrestigeTokens"},
	["Extra Storage"] = {Quantity = 1, Price = 8, Type = "Gamepasses", Currency = "PrestigeTokens"},
	["Display 3 Units"] = {Quantity = 1, Price = 10, Type = "Gamepasses", Currency = "PrestigeTokens"},
	["Dart Wader Maskless"] = {Quantity = 1, Price = 50, Type = "Units", Currency = "PrestigeTokens"},
	["Shiny Dart Wader Maskless"] = {Quantity = 1, Price = 75, Type = "Units", Currency = "PrestigeTokens", Shiny = true},
}




ShopUnit.OnServerEvent:Connect(function(player, itemName)
	
	local itemInfo = ShopItems[itemName]
	if not itemInfo then
		warn(player.Name .. " attempted to buy an invalid item: " .. tostring(itemName))
		return
	end

	
	local playerCurrency = player:FindFirstChild("PrestigeTokens")
	if not playerCurrency then
		warn(player.Name .. " does not have 'PrestigeTokens'.")
		return
	end

	
	if playerCurrency.Value >= itemInfo.Price then
		

		local givenType, givenName, givenQuantity = ShopModule.GiveItem(player, itemName, itemInfo.Quantity, itemInfo.Price, itemInfo.Type, itemInfo.Currency)

		
		ShopUnit:FireClient(player, givenType, givenName, givenQuantity)

		
		PrestigeTokenChanged:FireClient(player, playerCurrency.Value)
	else
		
		warn(player.Name .. " doesn't have enough 'PrestigeTokens' to buy " .. itemName)
	end
end)

PrestigeTokenChanged.OnServerEvent:Connect(function(Player)
	print(Player)
	local Value = Player:FindFirstChild("PrestigeTokens").Value
	PrestigeTokenChanged:FireClient(Player, Value)
end)