local ReplicatedStorage = game:GetService('ReplicatedStorage')
local movingEvent = ReplicatedStorage.Events:WaitForChild("MovingElevator")
local RaidElevator = ReplicatedStorage.Events.RaidElevator
local UIHandler = require(ReplicatedStorage.Modules.Client.UIHandler)
local UpdatePlayerFrame = require(script.UpdatePlayerFrame)
local ownerLeavesElevator = ReplicatedStorage.Events:WaitForChild("OwnerLeavesElevator")
local ActLoader = require(script.ActLoader)

local camera = workspace.CurrentCamera
local player = game.Players.LocalPlayer
local BottomBar = script.Parent.Frame.Bottom_Bar.Bottom_Bar

local infiniteBtn = BottomBar.Infinite
local exitBtn = BottomBar.Leave
local playBtn = BottomBar.Play

infiniteBtn.Play.UIGradient.Color = script.Red.Color
infiniteBtn.Play.Lines.UIGradient.Color = script.Red.Color

local gui = script.Parent

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

local function findPlayer()
	for i, v in workspace.RaidElevators:GetChildren() do
		if v.Players:FindFirstChild(game.Players.LocalPlayer.Name) then
			return v
		end
	end
end

RaidElevator.OnClientEvent:Connect(function(elevator)
    _G.CloseAll()
	UIHandler.DisableAllButtons()

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = elevator.Camera.CFrame
	
    ActLoader.setActs(ReplicatedStorage.States.RaidMap.Value)
	ActLoader.attachConnections()
	
	script.Parent.Visible = true
end)

movingEvent.OnClientEvent:Connect(function()
	gui.Visible = false
	--UIMapLoadingScreen.DisplayLoadingScreenWorld(currentElevator.World.Value, currentElevator.Level.Value)
end)

exitBtn.Activated:Connect(function()
	local player = game.Players.LocalPlayer
	UIHandler.PlaySound("Close")
	UIHandler.EnableAllButtons()
	gui.Visible = false
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = player.Character.Humanoid

	RaidElevator:FireServer()
	UpdatePlayerFrame.init()
end)

playBtn.Activated:Connect(function()
	--gui.QuickStart.Visible = false
	--gui.Exit.Visible = false
	gui.Visible = false
	local elevator = findPlayer()
	print(elevator)
	elevator.RaidElevatorServer.QuickStart:FireServer()
end)

infiniteBtn.Activated:Connect(function()
	--gui.Visible = false
	local elevator = findPlayer()
	print(elevator)
	
	infiniteBtn.ActiveState.Value = not infiniteBtn.ActiveState.Value
	
	if infiniteBtn.ActiveState.Value then
		infiniteBtn.Play.UIGradient.Color = script.Green.Color
		infiniteBtn.Play.Lines.UIGradient.Color = script.Green.Color
	else
		infiniteBtn.Play.UIGradient.Color = script.Red.Color
		infiniteBtn.Play.Lines.UIGradient.Color = script.Red.Color
	end
	
	elevator.RaidElevatorServer.ChangeStory:FireServer('Infinite', infiniteBtn.ActiveState.Value)
end)

ownerLeavesElevator.OnClientEvent:Connect(function()
	UpdatePlayerFrame.init()
end)

local Checkmark = BottomBar.Friends_Only.Contents.Check["Contents "].Checkmark

BottomBar.Friends_Only.Activated:Connect(function()
	Checkmark.Visible = not Checkmark.Visible
	local elevator = findPlayer()
	elevator.RaidElevatorServer.FriendsOnly:FireServer(Checkmark.Visible)
end)

RaidElevator.OnClientEvent:Connect(function(elevator)

	_G.CloseAll()
	UIHandler.DisableAllButtons()
	--exitBtn.Visible = false
	--quickStart.Visible = false
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = elevator.Camera.CFrame
	--wait(1)
	gui.Visible = true
	ActLoader.selectAct('Act1')
	
	infiniteBtn.Play.UIGradient.Color = script.Red.Color
	infiniteBtn.Play.Lines.UIGradient.Color = script.Red.Color
	infiniteBtn.ActiveState.Value = false
	
	--gui.WorldDetails.Visible = elevator.Owner.Value == game.Players.LocalPlayer.Name
	--gui.WorldsFrame.Visible = elevator.Owner.Value == game.Players.LocalPlayer.Name
	--gui.Frame.Visible = elevator.Owner.Value == game.Players.LocalPlayer.Name
	--visfalse()
	--gui.WorldDetails["Naboo Planet"].Visible = true
	----gui.WorldDetails.FriendsOnly.Image = ""
	--task.delay(0,function()
	--	exitBtn.Visible = true
	--end)
	--repeat task.wait() until gui.WorldDetails.Visible == false or gui.WorldsFrame.Visible == false
	--wait()

	--script.Parent.PlayersFrame.Visible = true
	task.spawn(function()
		UpdatePlayerFrame.init(elevator)
	end)


	--print(elevator:FindFirstChild("Players"),elevator.Owner.Value)
	if elevator:FindFirstChild("Players") then
		if elevator.Players:FindFirstChild(game.Players.LocalPlayer.Name) then
			exitBtn.Visible = true
			playBtn.Visible = elevator.Owner.Value == game.Players.LocalPlayer.Name
			print("Starting")
		end
	else
		exitBtn.Visible = true
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = player.Character.Humanoid
	end
end)


-- Left_Panel Act Loader:
ActLoader.setActs(ReplicatedStorage.States.RaidMap.Value)
ActLoader.attachConnections()


local Left_Panel = script.Parent.Frame.Left_Panel
local Location = Left_Panel.Contents.Location.Bg

local green = '<font color="#51E851">'
local yellow = '<font color="#e8d451">'
local red = '<font color="#e85b51">'


-- Raid Acts Cleared: <font color="#E03D40">  0/6</font>
for i,v in pairs(Location:GetChildren()) do
    if not v:IsA('ImageButton') then continue end
    
    -- v.Name
    local count = 0
    
    for i,v in pairs(player.RaidActData[v.Name]:GetChildren()) do
        if v.Completed.Value then
            count += 1
        end
    end
    
    local col = ''
    
    if count == 0 then
        col = red
    elseif count == 25 then
        col = green
    else
        col = yellow
    end
    
    v.Contents.Text_Container.Acts_Cleared.Text = 'Raid Acts Completed:  ' .. col .. count .. '/5</font>'
end