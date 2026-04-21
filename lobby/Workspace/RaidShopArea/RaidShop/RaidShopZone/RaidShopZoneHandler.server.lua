local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopZone = ReplicatedStorage.Remotes.Raid.RaidShopLoading
local Zone = require(ReplicatedStorage.Modules.Zone)
local container = script.Parent
local zone = Zone.new(container)


zone.playerEntered:Connect(function(plr)
	if plr.Character:FindFirstChild('Humanoid') and plr ~= nil then	
		ShopZone:FireClient(plr, true)
	end
end)


zone.playerExited:Connect(function(plr)
	if plr.Character and plr.Character:FindFirstChild('Humanoid') and plr ~= nil then 
		ShopZone:FireClient(plr, false)
	end
end)