local RS = game:GetService("ReplicatedStorage")

local Upgrades = require(RS.Upgrades)
local InfoModule = require(RS.Modules.SellAndFuse).RarityRewards

local Message = RS:WaitForChild("Events").Client:WaitForChild("Message")

return function(player, ClaimUnits)
	local UnitsIndex = player:WaitForChild("Index"):WaitForChild("Units Index")
	
	local TotalClaimed = 0
	
	for _, unit in UnitsIndex:GetChildren() do
		if unit.Value == false then
			if not Upgrades[unit.Name] then
				warn("No upgrades for unit: " .. unit.Name)
				return 
			end
			
			unit.Value = true
			local GemsReward = InfoModule[Upgrades[unit.Name].Rarity]
			player:WaitForChild("Gems").Value += GemsReward
			TotalClaimed += GemsReward
		end
	end
	
	Message:FireClient(player,"Claimed " .. TotalClaimed .. " Gems!",Color3.new(0.207843, 1, 0.117647),nil,"ClaimReward")
	
end