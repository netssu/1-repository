local tweenService = game:GetService('TweenService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local Player = Players.LocalPlayer
local Zone = require(ReplicatedStorage.Modules.Zone)

repeat task.wait() until Player:FindFirstChild('DataLoaded')



-- down: {0.5, 0},{0.1, 0}
-- up: 0.5, -0.2

local conn = nil

-- Raids Available  <font color="#51E851">5/5</font>
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

local ProgressBar = script.Parent.Frame.Internal.Front
local Daily_Timer = script.Parent.Frame.Internal.Daily_Timer

local function start()
    local RaidCount = Player:WaitForChild('RaidLimitData'):WaitForChild('Attempts').Value

    if not conn then
        task.spawn(function()
			while true do
				task.wait(1)
				local timeRemaining = math.max(14400 - (os.time() - Player.RaidLimitData.OldReset.Value), 0) 
				ProgressBar.Size = UDim2.fromScale(timeRemaining/14400, 1) -- its out of 6 hours in total
                Daily_Timer.Text = numbertotime(timeRemaining)
            end
        end)
    end
end

start()