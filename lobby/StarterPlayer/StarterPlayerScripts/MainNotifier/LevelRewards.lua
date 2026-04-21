local module = {}

function module.GiveRewardsValueChanged(player)
	-- Server Side
	local level = player:FindFirstChild("PlayerLevel")
	local LevelRewardsClaimed = player:FindFirstChild("LevelRewards")
	-- When the value changes

	level.Changed:Connect(function()
		if level % 10 == 0 and LevelRewardsClaimed.Value ~= level / 10 then
			local Gems = player:FindFirstChild("Gems")
			local reward = (level / 10) * 100
			Gems.Value += reward
			LevelRewardsClaimed.Value = level / 10
		end
	end)
	
	
	
end


function module.GiveRewardsLoadedIn(player)
	
	repeat task.wait() until player:FindFirstChild("DataLoaded")
	
	local level = player:FindFirstChild("PlayerLevel")
	local LevelRewardsClaimed = player:FindFirstChild("LevelRewards")

	local looptime = level / 10

	for i = 1, looptime do
		local total = 0
		if level % 10 == 0 and LevelRewardsClaimed.Value < level / 10 then
			local Gems = player:FindFirstChild("Gems")
			local reward = (level / 10) * 100
			Gems.Value = Gems.Value + reward
			total += reward
			LevelRewardsClaimed.Value = level / 10
		end
		if total ~= 0 then

		end
	end
end

return module
