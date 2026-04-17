local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PrestigeZone = ReplicatedStorage.Remotes.Prestige.PrestigeShop
local Zone = require(ReplicatedStorage.Modules.Zone)
local container = workspace:WaitForChild('PrestigeShop'):WaitForChild('PrestigeShopZone')
local zone = Zone.new(container)

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local module = {}

zone.playerEntered:Connect(function(plr)
	if plr == Player then
		--ShopZone:FireClient(plr, true)
		PrestigeZone:Fire(true)
	end
end)


zone.playerExited:Connect(function(plr)
	if plr == Player then
		PrestigeZone:Fire(false)
	end
end)

return module