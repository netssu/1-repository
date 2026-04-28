wait(1)
local score = game:GetService("DataStoreService"):GetOrderedDataStore("RobuxSpentLeaderboard", 2)
function script.UploadScore.OnServerInvoke(player)
	repeat task.wait() until not player.Parent or player:FindFirstChild(script.Score.Value)
	score:SetAsync(player.UserId, player:WaitForChild(script.Score.Value).Value)
end