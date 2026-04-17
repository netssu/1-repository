local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GemModule = require(script.GemModule)
local ClientDataLoaded = require(ReplicatedStorage.Modules.ClientDataLoaded)
local plrData = ClientDataLoaded.getPlayerData()

local gemCount = plrData.Gems.Value
local goldCount = plrData.Coins.Value

plrData.Gems.Changed:Connect(function(amount)
	if gemCount < amount then
		GemModule.castEffect('Gems')
	end
	
	gemCount = amount
end)

plrData.Coins.Changed:Connect(function(amount)
	if goldCount < amount then
		GemModule.castEffect('Gold')
	end

	goldCount = amount
end)


return {}