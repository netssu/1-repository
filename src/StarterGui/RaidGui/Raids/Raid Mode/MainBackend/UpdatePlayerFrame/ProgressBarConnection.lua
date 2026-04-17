local module = {}

local Players = game:GetService('Players')
local Player = Players.LocalPlayer
local conn = nil
local Right_Panel = script.Parent.Parent.Parent.Frame.Right_Panel
local Raids_Available = Right_Panel.Contents["Raids_Available "].Contents
local ProgressBar = Raids_Available['Daily_Bar'].ProgressBar
local Daily_Time = Raids_Available['Daily_Bar'].Contents.Daily_Timer

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

local green = '<font color="#51E851">'
local yellow = '<font color="#e8d451">'
local red = '<font color="#e85b51">'

function module.init(world, act)
	local RaidCount = Player:WaitForChild('RaidLimitData'):WaitForChild('Attempts').Value
	local col = nil
	if RaidCount == 10 then
		col = green
	elseif RaidCount == 0 then
		col = red
	else
		col = yellow
	end
	Raids_Available.Title.Text = 'Raids Available  ' .. col .. RaidCount .. '/10</font>'
	
	if not conn then
		task.spawn(function()
			while task.wait(1) do
				--local timeRemaining = 21600 - (tick() - Player.RaidLimitData.NextReset.Value)
				--print(os.time() - Player.RaidLimitData.OldReset.Value)
                local timeRemaining = math.max(14400 - (os.time() - Player.RaidLimitData.OldReset.Value), 0) 
                ProgressBar.Size = UDim2.fromScale(timeRemaining/14400, 1) -- its out of 6 hours in total
                Daily_Time.Text = numbertotime(timeRemaining)
                
                -- (targetTime - os.time())/targetTime 
                -- 0 - 1
                -- print(os.time())
			end
		end)
	end
end


return module