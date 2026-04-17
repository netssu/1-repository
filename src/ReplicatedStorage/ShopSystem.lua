local module = {}

module.TypeOfItems = {
	["Currency"] = {"Gems", "TraitPoint", "Coins", "Credits", "Eggs", "LuckySpins", "RaidsRefresh", "LuckyWillpower", "GoldenRepubliCredits", "Event Double Luck"},
	["Item"] = {"Milk","Crystal (Pink)" },
	["Units"] = {"Scout"},
	["Buff"] = {"x2 Buff", "x3 Buff"},
	["Gamepasses"] = {}
}




CurrencyLocation = {
	[1] = "RaidData"
}


local ServerScriptService = game:GetService('ServerScriptService')
local Players = game:GetService('Players')



local x2Buff = {Buff = "RaidLuck2x",
	StartTime = os.time(),
	Duration = 21600,
	Multiplier= 2,
	BuffType= "RaidLuck2x"
}

local x3Buff = {Buff = "RaidLuck3x",
	StartTime = os.time(),
	Duration = 21600, 
	Multiplier= 3,
	BuffType= "RaidLuck3x"
}

module.GiveItem = function(player, ItemName, Quantity, price, TypeOfItem, PaidCurrency, Shiny)
	warn(TypeOfItem)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ItemStats = ReplicatedStorage:WaitForChild("ItemStats")
	local ShopUnit = ReplicatedStorage.Remotes.ShopUnit
	local Currency = nil
	local Unit = nil
	local Items = nil
	local Buff = nil
	local Gamepasses = nil
	local UnitsFolder = require(ReplicatedStorage.Upgrades)
	-- Populate item lists if not already populated
	for _, rarityFolder in ipairs(ItemStats:GetChildren()) do
		if rarityFolder:IsA("Folder") then
			for _, item in ipairs(rarityFolder:GetChildren()) do
				table.insert(module.TypeOfItems["Item"], item.Name)
			end
		end
	end
	
	local isShiny
	if TypeOfItem == "Units" then
		isShiny = false

		if string.find(ItemName:lower(), "shiny") then
			isShiny = true
			ItemName = string.gsub(ItemName, "Shiny ", "")
		end
	end
	

	for _, GamePass in ipairs(player:FindFirstChild("OwnGamePasses"):GetChildren()) do
		if GamePass:IsA("Instance") then
			table.insert(module.TypeOfItems.Gamepasses, GamePass.Name)
		end
	end

	
	for _, Rarity in ReplicatedStorage.Towers:GetChildren() do
		if Rarity:IsA("Folder") then
			for _, unit in ipairs(Rarity:GetChildren()) do
				table.insert(module.TypeOfItems.Units, unit.Name)
			end
		end
	end
	
	warn(module.TypeOfItems.Units)

	if Quantity < 1 then
		Quantity = 1
	end

	for itemType, itemList in pairs(module.TypeOfItems) do
		warn(itemType)
		if itemType == TypeOfItem then
			warn("Working this one")
			for _, itemName in ipairs(itemList) do
				warn("Working this two")
				warn(itemName, ItemName)
				if itemName == ItemName then
					warn("Working this three")
					warn(itemType)
					if itemType == "Currency" then
						Currency = player:FindFirstChild(ItemName)
						if ItemName == "Credits" then
							Currency = player:FindFirstChild("RaidData"):FindFirstChild("Credits")
						end
						if ItemName == "Eggs" then
							Currency = player:FindFirstChild("EventData"):FindFirstChild("Easter"):FindFirstChild("Eggs")
						end
					elseif itemType == "Units" then
						Unit = ItemName
					elseif itemType == "Item" then
						print("Working Here")
						Items = player:FindFirstChild("Items"):FindFirstChild(ItemName)
					elseif itemType == "Buff" then
						if ItemName == "x2 Buff" then
							Buff = x2Buff
						else
							Buff = x3Buff
						end
					elseif itemType == "Gamepasses" then
						print(ItemName)
						Gamepasses = player:FindFirstChild("OwnGamePasses"):FindFirstChild(ItemName)
					end
					break
				end
			end
			break
		end
	end

	if Buff and Buff.StartTime then
		Buff.StartTime = os.time()
	end

	local PlayerCurrencyValue = player:FindFirstChild(PaidCurrency)

	if PlayerCurrencyValue == nil then
		if PaidCurrency == "Credits" then
			PlayerCurrencyValue = player:FindFirstChild("RaidData"):FindFirstChild("Credits")
		end
		if PaidCurrency == "Eggs" then
			PlayerCurrencyValue = player:FindFirstChild("EventData"):FindFirstChild("Easter"):FindFirstChild("Eggs")
		end
	end

	print(Buff)
	print(module.TypeOfItems.GamePasses)
	warn(Currency)
	warn(Unit)


	if PlayerCurrencyValue.Value >= price then
		PlayerCurrencyValue.Value -= price

		if Currency ~= nil then
			Currency.Value += Quantity
			return "Currency", Currency, Quantity
		end

		if Unit ~= nil then
			local towerName = Unit

			local playerTowers = game.Players[player.Name].OwnedTowers
			local NewUnit = _G.createTower(playerTowers, towerName, nil, {Shiny = isShiny})

			local Upgrades = require(ReplicatedStorage.Upgrades)
			local ViewModule = require(ReplicatedStorage.Modules.ViewModule)
			local Event = ReplicatedStorage.Remotes.ShopUnit
			Event:FireClient(player, towerName, isShiny)
			


			return "Unit", NewUnit
		end


		if Items ~= nil then
			Items.Value += Quantity
			print(player.Items[ItemName].Value)
			return "Item", ItemName, Quantity
		end

		if Buff ~= nil then
			ServerScriptService.ProfileServiceMain.Main.ApplyBuff:Fire(player, Buff)
			return "Buff", ItemName, Quantity
		end

		if Gamepasses ~= nil then
			print(Gamepasses.Value, Gamepasses.Name)
			if Gamepasses.Value == false then
				Gamepasses.Value = true
				return "GamePass", ItemName, 1
			else
				PlayerCurrencyValue.Value += price
				return "Gamepass", false, false
			end
		end

		return false, false, false
	end
end



function module.CheckCurrency(PlayerCurrency, CurrencyRequired)
	if PlayerCurrency.Value >= CurrencyRequired then
		return true
	else
		return false
	end
end



return module  