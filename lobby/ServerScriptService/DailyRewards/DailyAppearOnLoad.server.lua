local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Event  = ReplicatedStorage.Remotes.DisplayFramesOnLoad
local Players = game:GetService("Players")
local DailyRewardModule = require(ReplicatedStorage.Modules.DailyReward)

Players.PlayerAdded:Connect(function(player)
	repeat task.wait(.1) until player:FindFirstChild("DataLoaded")

	if DailyRewardModule.GetTimeUntilClaim(player) <= 0 then
		Event:FireClient(player, "DailyReward")
	end
end)



