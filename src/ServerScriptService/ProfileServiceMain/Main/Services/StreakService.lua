local ReplicatedStorage = game:GetService("ReplicatedStorage")

local module = {}

--OldStreak = 0,
--Streak = 0,
--StreakIncreasesIn = os.clock() + 86400,
--StreakRestoreExpiresIn = os.clock() + 86400 * 3,
--PlayStreakAnimation = false

ReplicatedStorage.Events.ResetStreakAnimation.OnServerEvent:Connect(function(plr)
	plr.PlayStreakAnimation.Value = false
end)











return module