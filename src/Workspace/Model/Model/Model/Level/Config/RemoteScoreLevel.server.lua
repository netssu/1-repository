wait(1)
local score = game:GetService("DataStoreService"):GetOrderedDataStore("LevelLeaderboard", 2)
function script.UploadScore.OnServerInvoke(player)
	repeat task.wait() until not player.Parent or player:FindFirstChild('PlayerLevel')
	score:SetAsync(player.UserId, player:WaitForChild("PlayerLevel").Value)
end