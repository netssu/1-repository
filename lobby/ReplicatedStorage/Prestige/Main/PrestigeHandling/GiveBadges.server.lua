local PrestigeHandling = require(script.Parent)



game:GetService("Players").PlayerAdded:Connect(function(player)
	repeat task.wait(.5) until player:FindFirstChild("DataLoaded")
	local Prestige = player.Prestige.Value
	local BadgeService = game:GetService("BadgeService")
	if Prestige >= 1 and not BadgeService:UserHasBadgeAsync(player.UserId, PrestigeHandling.Badges[Prestige]) then
		for i = 0, Prestige do
			BadgeService:AwardBadge(player.UserId, PrestigeHandling.Badges[i])
		end
	end	
end)