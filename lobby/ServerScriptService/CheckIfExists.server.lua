local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CheckIfExists = ReplicatedStorage.Functions.BuyNowWP

CheckIfExists.OnServerInvoke = function(player, value)
	if player:FindFirstChild(value).Value >= 1 then
		return true
	else
		return false
	end
end