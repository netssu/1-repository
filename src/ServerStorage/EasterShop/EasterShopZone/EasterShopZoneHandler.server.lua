local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EasterShopZone = ReplicatedStorage.Remotes.Easter.EasterShop
local Zone = require(ReplicatedStorage.Modules.Zone)
local container = script.Parent
local zone = Zone.new(container)


zone.playerEntered:Connect(function(plr)
	if plr.Character:FindFirstChild('Humanoid') and plr ~= nil then
		EasterShopZone:FireClient(plr, true)
	end
end)


zone.playerExited:Connect(function(plr)
	if plr.Character and plr.Character:FindFirstChild('Humanoid') and plr ~= nil then
		EasterShopZone:FireClient(plr, false)
	end
end)