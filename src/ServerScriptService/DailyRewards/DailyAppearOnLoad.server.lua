local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Event  = ReplicatedStorage.Remotes.DisplayFramesOnLoad
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	repeat task.wait(.1) until player:FindFirstChild("DataLoaded")
	local lastClaim = player.DailyRewards.LastClaimTime.Value
	local secondsSinceLastClaim = os.clock() - lastClaim
	
	if secondsSinceLastClaim >= 0 then
		Event:FireClient(player, "DailyReward")
	end
end)



