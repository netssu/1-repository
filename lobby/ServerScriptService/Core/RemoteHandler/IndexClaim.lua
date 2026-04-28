local RS = game:GetService("ReplicatedStorage")

local Upgrades = require(RS.Upgrades)
local InfoModule = require(RS.Modules.SellAndFuse).RarityRewards

local Message = RS:WaitForChild("Events").Client:WaitForChild("Message")

return function(player, ClaimUnits)
	local UnitsIndex = player:WaitForChild("Index"):WaitForChild("Units Index")
	local TotalClaimed = 0

	local unitsToClaim = {}

	if typeof(ClaimUnits) == "string" then
		local unit = UnitsIndex:FindFirstChild(ClaimUnits)
		if unit then
			table.insert(unitsToClaim, unit)
		end
	elseif typeof(ClaimUnits) == "table" then
		for _, unitName in ipairs(ClaimUnits) do
			local unit = UnitsIndex:FindFirstChild(unitName)
			if unit then
				table.insert(unitsToClaim, unit)
			end
		end
	else
		for _, unit in UnitsIndex:GetChildren() do
			table.insert(unitsToClaim, unit)
		end
	end

	for _, unit in unitsToClaim do
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

	if TotalClaimed <= 0 then
		Message:FireClient(player, "No unclaimed unit rewards remaining", Color3.new(1, 0, 0), nil, "Error")
		return
	end

	Message:FireClient(player,"Claimed " .. TotalClaimed .. " Gems!",Color3.new(0.207843, 1, 0.117647),nil,"ClaimReward")
end
