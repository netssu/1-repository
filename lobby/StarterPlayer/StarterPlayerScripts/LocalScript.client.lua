local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Upgrades = require(ReplicatedStorage.Upgrades)
local ViewModule = require(ReplicatedStorage.Modules.ViewModule)
local Event = ReplicatedStorage.Remotes.ShopUnit

Event.OnClientEvent:Connect(function(towerName, isShiny)
	for _, rarityFolder in ipairs(ReplicatedStorage.Towers:GetChildren()) do
		if rarityFolder:IsA("Folder") then
			for _, tower in ipairs(rarityFolder:GetChildren()) do
				if tower.Name == towerName then
					ViewModule.Hatch({
						Upgrades[towerName],
						tower,
						nil,
						isShiny
					})
					break
				end
			end
		end
	end	
end)
