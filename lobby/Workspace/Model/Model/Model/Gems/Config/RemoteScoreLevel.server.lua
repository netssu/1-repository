local score = game:GetService("DataStoreService"):GetOrderedDataStore("GemsLeaderboard", 2)
function script.UploadScore.OnServerInvoke(player)
	repeat task.wait() until not player.Parent or player:FindFirstChild(script.Score.Value)

	if player.Parent then	
		score:SetAsync(player.UserId, player:WaitForChild(script.Score.Value).Value)
	end
end