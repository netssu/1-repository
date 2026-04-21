local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ResetStreakAnimation = ReplicatedStorage.Events.ResetStreakAnimation

--[[

OldStreak = 0,
Streak = 0,
StreakIncreasesIn = os.clock() + 86400,
StreakRestoreExpiresIn = os.clock() + 86400 * 3,
PlayStreakAnimation = false
StreakLastUpdated = os.clock()

--]]


ResetStreakAnimation.OnServerEvent:Connect(function(plr)
	plr.PlayStreakAnimation.Value = false
end)

Players.PlayerAdded:Connect(function(plr)
	repeat task.wait() until not plr.Parent or plr:FindFirstChild('DataLoaded')
	
	if plr:FindFirstChild('DataLoaded') then
		while true do
			local StreakLastUpdated = plr.StreakLastUpdated.Value
			
			if StreakLastUpdated + 86400 < time() then
				-- womp womp, EXPIRED!
				plr.OldStreak.Value = plr.Streak.Value
				plr.Streak.Value = 0
				plr.StreakRestoreExpiresIn.Value = time() + 86400 * 3
				plr.StreakLastUpdated.Value = time()
			end
			
			task.wait(1)
		end	
	end
end)