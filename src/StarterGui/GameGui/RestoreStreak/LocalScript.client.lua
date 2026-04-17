local Players = game:GetService("Players")
local Player = Players.LocalPlayer

repeat task.wait() until Player:FindFirstChild('DataLoaded')


--[[

OldStreak = 0,
Streak = 0,
StreakIncreasesIn = os.clock() + 86400,
StreakRestoreExpiresIn = os.clock() + 86400 * 3,
PlayStreakAnimation = false

--]]

local function numbertotime(number)
	local Hours = math.floor(number / 60 / 60)
	local Mintus = math.floor(number / 60) %60
	local Seconds = math.floor(number % 60)

	if Mintus < 10 and Hours > 0 then
		Mintus = "0"..Mintus
	end

	if Seconds < 10 then
		Seconds = "0"..Seconds
	end

	if Hours > 0 then
		return `{Hours}:{Mintus}:{Seconds}`
	else
		return `{Mintus}:{Seconds}`
	end
end

local function update()
	local diff = Player.StreakRestoreExpiresIn.Value - os.clock()
	
	if diff < 0 then
		script.Parent.Visible = false
	else
		script.Parent.Visible = true
		script.Parent.Internal.Countdown.Text = numbertotime(diff)
	end
end

update()

script.Parent.Activated:Connect(function()
	print('Button activated! prompt dev product')
end)

while true do
	task.wait(1)
	update()
end