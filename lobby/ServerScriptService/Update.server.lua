local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage.Events.Client.UpdateFirstTime.OnServerEvent:Connect(function(player)
	local firstTime = player:FindFirstChild("FirstTime")
	local tutorialMode = player:FindFirstChild("TutorialModeCompleted")
	if not firstTime then
		firstTime = player:FindFirstChild("FirstTime")
		repeat task.wait(.1) warn("Retrying") until firstTime
	end
	if not tutorialMode then
		tutorialMode = player:FindFirstChild("TutorialMode")
		repeat task.wait(.1) warn("Retrying") until tutorialMode
	end

	firstTime.Value = false
	tutorialMode.Value = true
end)

ReplicatedStorage.Events.Client.RewardGems.OnServerEvent:Connect(function(player: Player) 
	if player:FindFirstChild('DataLoaded') and not player.TutorialLossGemsClaimed.Value then
		local tutorialCompleted = player:FindFirstChild("TutorialCompleted")
		local gems = player:FindFirstChild("Gems")
		if gems then
			gems.Value += 250
		end

		tutorialCompleted.Value = true
		player.TutorialLossGemsClaimed.Value = true -- fixed a stupid vuln mathrix did
	end
end)

ReplicatedStorage.Events.Client.UpdatePoints.OnServerEvent:Connect(function(player, combinedPoints: number, action)
	local points = player:FindFirstChild("JunkTraderPoints")
	if not points then
		repeat task.wait(.1) warn("Retrying") until points
	end

	if action == "add" then
		points.Value += combinedPoints
	elseif action == "subtract" then
		points.Value -= combinedPoints
	end
	
end)