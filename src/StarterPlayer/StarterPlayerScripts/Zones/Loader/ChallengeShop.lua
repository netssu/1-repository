local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopZone = ReplicatedStorage.Events.Challenges.ChallengeShopLoading
local Zone = require(ReplicatedStorage.Modules.Zone)
local container = workspace:WaitForChild('Challenge'):WaitForChild('ChallengeShopZone')
local zone = Zone.new(container)

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local module = {}

zone.playerEntered:Connect(function(plr)
	if plr == Player then
		--ShopZone:FireClient(plr, true)
		--ShopZone:Fire(true)
		_G.CloseAll('ChallengeShop')
	end
end)


zone.playerExited:Connect(function(plr)
	if plr == Player then
		--ShopZone:Fire(false)
		_G.CloseAll()
	end
end)

return module