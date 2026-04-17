local BadgeService = game:GetService("BadgeService")
game:GetService("Players").PlayerAdded:Connect(function(player)
	repeat task.wait() until player:FindFirstChild("DataLoaded")
	
	local MedalKills = player:FindFirstChild("MedalKills")
	
	if not BadgeService:UserHasBadgeAsync(player.UserId, 3230798871362424) and MedalKills.Value >= 5000 then
		warn("Giving Badge")
		BadgeService:AwardBadge(player.UserId, 3230798871362424)
	end
	
	MedalKills.Changed:Connect(function()
		warn("Giving Badge")
		if not BadgeService:UserHasBadgeAsync(player.UserId, 3230798871362424) and MedalKills.Value >= 5000 then
			BadgeService:AwardBadge(player.UserId, 3230798871362424)
		end
	end)
end)