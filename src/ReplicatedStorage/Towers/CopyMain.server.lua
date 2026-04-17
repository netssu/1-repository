local Default = script.Default.MainScript
local Farm = script.Farm.MainScript
local Spawner = script.Spawner.MainScript

local Upgrades = require(game.ReplicatedStorage.Upgrades)
local PlaceData = require(game.ServerStorage.ServerModules.PlaceData)
if game.PlaceId == PlaceData.Game then
	for i,v in script.Parent:GetDescendants() do
		if v:IsA("Model") and v:FindFirstChild("Humanoid") then
			if not Upgrades[v.Name] then continue end
			
			if Upgrades[v.Name] and Upgrades[v.Name].Upgrades[1].Money and not Upgrades[v.Name]["HybridFarm"] then
				local Main = Farm:Clone()
				Main.Parent = v
			elseif Upgrades[v.Name].Upgrades[1].Type == 'Spawner' then
				local Main = Spawner:Clone()
				Main.Parent = v
			elseif Upgrades[v.Name].Upgrades[1].Type == "Hybrid (Farm)" then
				local Main = script["Hybird (Farm)"].MainScript
				Main.Parent = v
			else
				local Main = Default:Clone()
				Main.Parent = v
			end
		end
	end
end
