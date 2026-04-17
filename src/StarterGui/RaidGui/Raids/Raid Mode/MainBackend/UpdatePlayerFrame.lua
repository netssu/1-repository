local module = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RaidModeStats = require(ReplicatedStorage.RaidModeStats)
local ProgressBarConnection = require(script.ProgressBarConnection)

local Players = game:GetService('Players')
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local informationFrame = script.Parent.Parent.Frame

local gui = script.Parent.Parent
local currentElevator = nil

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

function module.init(elevator)
	--local playersStorage = script.Parent.PlayersFrame.StoryImage.Players
	if elevator then
		currentElevator = elevator
		local elevatorInformationFrame = elevator.Door.Surface.Frame.InformationFrame
		
		--script.Parent.PlayersFrame.Visible = true

		local totalPlayer

		local function updateInfo()
			if not RaidModeStats.Images[elevatorInformationFrame["Story Name"].Text] then return end
			
			
			informationFrame.Right_Panel.Contents.Title.Contents.Stage.Text = 'Raid: ' .. elevatorInformationFrame['Story Name'].Text -- Raid: Naboo Planet
			informationFrame.Right_Panel.Contents.Title.Contents.Act.Text = elevatorInformationFrame.ActName.Text
			
			ProgressBarConnection.init(elevatorInformationFrame["Story Name"].Text)
			
			informationFrame.Right_Panel.Map_Bg.Image = RaidModeStats.Images[elevatorInformationFrame["Story Name"].Text]
			
			local actData = player:WaitForChild('RaidActData'):WaitForChild(elevatorInformationFrame["Story Name"].Text):WaitForChild('Act' .. elevator:WaitForChild('Level').Value)
			local clearTime = actData:WaitForChild('ClearTime').Value
			local totalClears = actData:WaitForChild('TotalClears').Value
			
			informationFrame.Right_Panel.Contents.Times.Contents.Total_Clears.Text = 'Total Clears: <font color="#51E851">' .. totalClears .. '</font>' -- Total Clears: <font color="#51E851">0</font>
			informationFrame.Right_Panel.Contents.Times.Contents.TextLabel.Text = 'Clear Time: <font color="#51E851">' .. numbertotime(clearTime) .. '</font>' --Clear Time: <font color="#51E851">00:00:00</font>
		end

		repeat updateInfo() task.wait() until not currentElevator
	else
		gui.Visible = false
		currentElevator = nil
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = player.Character.Humanoid
	end
end

return module