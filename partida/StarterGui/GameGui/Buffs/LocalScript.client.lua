local player = game.Players.LocalPlayer
repeat task.wait() until player:FindFirstChild("DataLoaded")

local Main = script.Parent.Main

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

function DisplayBuff(buff)
	local ui = buff and Main:FindFirstChild(buff.Name)
	if not ui then return end

	ui.Visible = true

	local function UpdateTimer()
		local duration = numbertotime(math.max((buff.StartTime.Value + buff.Duration.Value) - os.time(),0))
		ui.BuffText.Text = `x{buff.Multiplier.Value}: {duration}`
	end

	task.spawn(function()
		while task.wait() do
			if buff.Parent == nil then 
				ui.Visible = false
				UpdateAvailableRaidLuck() 
				break 
			end
			UpdateTimer()
		end
	end)

end

function UpdateAvailableRaidLuck()
	if player.Buffs:FindFirstChild("RaidLuck3x") then
		DisplayBuff(player.Buffs["RaidLuck3x"])
	elseif player.Buffs:FindFirstChild("RaidLuck2x") then
		DisplayBuff(player.Buffs["RaidLuck2x"])
	end
end

if not workspace.Info.Raid.Value then return end

UpdateAvailableRaidLuck()
