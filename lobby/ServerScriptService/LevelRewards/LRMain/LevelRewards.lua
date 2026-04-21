local module = {}

local PrestigeModule = require(game:GetService("ReplicatedStorage").Prestige.Main.PrestigeHandling)


function module.GiveRewardsValueChanged(player)
	local level = player:FindFirstChild("PlayerLevel")
	local Prestige = player:FindFirstChild("Prestige")
	
	if level.Value > PrestigeModule.PrestigeRequirements[Prestige.Value + 1] then
		return 0, 0 
	end
	
	
	local LevelRewardsClaimed = player:FindFirstChild("LevelRewards")
	local gems = player:FindFirstChild("Gems")
	local traitPointsStat = player:FindFirstChild("TraitPoint")

	local total = 0
	local TraitPoint = 0

	local currentLevel = level.Value
	local claimedMilestone = LevelRewardsClaimed.Value
	local highestMilestone = math.floor(currentLevel / 10)

	for milestone = claimedMilestone + 1, highestMilestone do
		local reward = milestone * 500
		gems.Value += reward
		traitPointsStat.Value += 3
		total += reward
		TraitPoint += 3
	end

	LevelRewardsClaimed.Value = highestMilestone
	return total, TraitPoint
end


function module.GiveRewardsLoadedIn(player)
	repeat task.wait() until player:FindFirstChild("DataLoaded")
	local level = player:WaitForChild("PlayerLevel") -- aded waitforchild just to see if it fixes, ace
	local LevelRewardsClaimed = player:FindFirstChild("LevelRewards")
	local Prestige = player:FindFirstChild("Prestige")
	local total = 0
	local TraitPoint = 0
	
	if level.Value > PrestigeModule.PrestigeRequirements[Prestige.Value + 1] then
		--print("Returning 0")
		return 0,0
	end
	
	for i = LevelRewardsClaimed.Value + 1, level.Value / 10 do
		if i * 10 <= level.Value then
			local Gems = player:FindFirstChild("Gems")
			local reward = i * 500
			Gems.Value = Gems.Value + reward
			player:FindFirstChild("TraitPoint").Value += 3
			TraitPoint += 3
			print("Giving "..reward)
			total = total + reward
			LevelRewardsClaimed.Value = i
		end
	end

	task.wait(0.2)

	if total > 0 then
		print(total, TraitPoint)
		return total, TraitPoint
	end

end

return module

