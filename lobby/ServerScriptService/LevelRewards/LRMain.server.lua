local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelRewardRemote = ReplicatedStorage.Remotes.LevelRewards.LevelReward
local module = require(script.LevelRewards)
local total = 0
local traits = 0 

game:GetService("Players").PlayerAdded:Connect(function(player)
	total, traits = module.GiveRewardsLoadedIn(player)
	
	--print(total)
	
	if total ~= 0 then
		pcall(function()
			LevelRewardRemote:InvokeClient(player, total, traits)
		end)
	end
end)



LevelRewardRemote.OnServerInvoke = function(player)
	local GemTotal, TraitPoints = module.GiveRewardsValueChanged(player)
	--print(GemTotal, TraitPoints)
	return GemTotal, TraitPoints
end