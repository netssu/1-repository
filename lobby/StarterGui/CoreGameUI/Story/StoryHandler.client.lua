local ReplicatedStorage = game:GetService("ReplicatedStorage")

local movingEvent = ReplicatedStorage.Events:WaitForChild("MovingElevator")
local elevatorEvent = ReplicatedStorage.Events:WaitForChild("Elevator")
local ownerLeavesElevator = ReplicatedStorage.Events:WaitForChild("OwnerLeavesElevator")
local gui = script.Parent.StoryFrame.Frame
local exitBtn = gui.Parent.Exit
local playBtn = gui.Bottom_Bar.Bottom_Bar.Play
local quickStart = gui.Parent.QuickStart
local camera = workspace.CurrentCamera


local player = game.Players.LocalPlayer
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local UIMapLoadingScreen = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIMapLoadingScreen"))
local StoryModeStats = require(game.ReplicatedStorage.StoryModeStats)
local Simplebar = require(ReplicatedStorage.Modules.Client.Simplebar)


local UIHandler = require(game.ReplicatedStorage.Modules.Client.UIHandler)
local hasChoose = false

local ActLoader = require(script.ActLoader)

--script.Parent.StoryFrame.Visible = false

ActLoader.setActs('Naboo Planet')
ActLoader.attachConnections()

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
	for i, v in game.Workspace.StoryElevators:GetChildren() do
		if v:IsA('Model') then
			if v.Players:FindFirstChild(game.Players.LocalPlayer.Name) then
				return v
			end
		end
	end
end

local function visfalse()
	for i, v in gui.WorldDetails:GetChildren() do
		if v:IsA("Frame") then
			v.Visible = false
		end
	end
end
local informationFrame = script.Parent.PlayersFrame.StoryImage.InformationFrame


local currentElevator = nil
local function UpdatePlayerFrame(elevator)

	local playersStorage = script.Parent.PlayersFrame.StoryImage.Players
    if elevator then
		currentElevator = elevator
		local elevatorInformationFrame = elevator.Door.Surface.Frame.InformationFrame

		--script.Parent.PlayersFrame.Visible = true

		local totalPlayer

		local function updateInfo()
			informationFrame.Status.Players.Text = elevatorInformationFrame.Status.Players.Text
			informationFrame.ActName.Text = elevatorInformationFrame.ActName.Text
			informationFrame["Story Name"].Text = elevatorInformationFrame["Story Name"].Text
			informationFrame.Status.Bar.Size = elevatorInformationFrame.Status.Bar.Size
			--print(StoryModeStats.Images[elevatorInformationFrame.WorldName])
			--script.Parent.PlayersFrame.StoryImage.Image = StoryModeStats.Images[elevatorInformationFrame["Story Name"].Text]

			if elevator.Mode.Value == 1 then
				informationFrame["Mode Text"].Text = "Normal"
				informationFrame["Mode Text"].HardGradient.Enabled = false
				informationFrame["Mode Text"].NormalGradient.Enabled = true
			else
				informationFrame["Mode Text"].Text = "Hard"
				informationFrame["Mode Text"].NormalGradient.Enabled = false
				informationFrame["Mode Text"].HardGradient.Enabled = true
			end


			for _,ui in playersStorage:GetChildren() do
				if (not ui:IsA("ImageLabel") or not ui.Visible)  then continue end
				if elevator.Players:FindFirstChild(ui.Name) then continue end
				ui:Destroy()
			end

			for _,playerValue in elevator.Players:GetChildren() do
				local player = game.Players:FindFirstChild(playerValue.Name)
				if not player or playersStorage:FindFirstChild(playerValue.Name) then continue end


				local clonePlayerImage = playersStorage.TemplatePlayerImage:Clone()
				task.spawn(function()
					local playerHeadshot = game.Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
					clonePlayerImage.Image = playerHeadshot
				end)
				clonePlayerImage.Name = player.Name
				clonePlayerImage.Visible = true
				clonePlayerImage.Parent = playersStorage

			end


		end

		repeat updateInfo() task.wait() until not currentElevator

		--updateInfo()


	else
		gui.Visible = false
		currentElevator = nil
		script.Parent.PlayersFrame.Visible = false
		--exitBtn.Visible = false

		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = player.Character.Humanoid
	end
end

movingEvent.OnClientEvent:Connect(function()
	gui.Visible = false
	--UIMapLoadingScreen.DisplayLoadingScreenWorld(currentElevator.World.Value, currentElevator.Level.Value)
end)

elevatorEvent.OnClientEvent:Connect(function(elevator, gamemode)
	_G.CloseAll()
	UIHandler.DisableAllButtons()
	exitBtn.Visible = false
	quickStart.Visible = false
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = elevator.Camera.CFrame

    gui.Parent.Visible = true
    gui.Visible = elevator.Owner.Value == game.Players.LocalPlayer.Name
    
    if elevator.Owner.Value == game.Players.LocalPlayer.Name then
        -- we own the elevator
        ActLoader.setActs('Naboo Planet')
        ActLoader.selectAct('Act1')
        
    end
    
    script.Parent.PlayersFrame.Visible = true

    exitBtn.Visible = true
    
    UpdatePlayerFrame(elevator)

    repeat task.wait() until not gui.Visible
	
	--task.spawn(function()
	--	UpdatePlayerFrame(elevator)
	--end)


	if elevator:FindFirstChild("Players") then
        if elevator.Players:FindFirstChild(game.Players.LocalPlayer.Name) then
            gui.Parent.Visible = false
			exitBtn.Visible = true
			quickStart.Visible = elevator.Owner.Value == game.Players.LocalPlayer.Name
		end
	else
		exitBtn.Visible = true
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = player.Character.Humanoid
	end

end)

exitBtn.Activated:Connect(function()
	local player = game.Players.LocalPlayer
	UIHandler.PlaySound("Close")
	UIHandler.EnableAllButtons()
	Simplebar.toggleSimplebar(true)
	
    gui.Visible = false
    UpdatePlayerFrame()
    

    script.Parent.PlayersFrame.Visible = false
    
    
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = player.Character.Humanoid

	elevatorEvent:FireServer()
	
end)

playBtn.Activated:Connect(function()
    gui.Visible = false
    --gui.Parent.QuickStart.Visible = true
    local elevator = findPlayer()
    
    if elevator.Owner.Value == game.Players.LocalPlayer.Name then
        gui.Parent.QuickStart.Visible = true
    end
end)

quickStart.Activated:Connect(function()
    gui.Parent.Parent.PlayersFrame.Visible = false
    gui.Parent.QuickStart.Visible = false
	gui.Parent.Exit.Visible = false
	gui.Visible = false
	findPlayer().ElevatorServer.QuickStart:FireServer()
end)

ownerLeavesElevator.OnClientEvent:Connect(function()

	UIHandler.PlaySound("Close")
	UIHandler.EnableAllButtons()
	UpdatePlayerFrame()
end)

-- temp removed
--gui.WorldDetails.Start.Activated:Connect(function()
--	if not hasChoose then return end
--	gui.WorldDetails.Visible = false
--	gui.WorldsFrame.Visible = false
--	gui.Frame.Visible = false
--	findPlayer().ElevatorServer.Choose:FireServer()
--end)

local function unlockedActsCount(world)
    repeat task.wait() until player:FindFirstChild('DataLoaded')
    local count = 0
    
    for i,v in pairs(player.WorldStats[world].LevelStats:GetChildren()) do
        if v.Clears.Value ~= 0 then
            count += 1
        end
    end
    
    
    return count
end

local Player = player

local function isActUnlocked(world, act)
    local WorldStats = Player:WaitForChild("WorldStats")

    -- Shortcut: first act of the first world is always unlocked
    if world == "Naboo Planet" and act == "1" then
        return true
    end

    local worldOrder = StoryModeStats.Worlds  -- Assumed to be in order
    local previousWorldCleared = false

    for i, RaidMap in ipairs(worldOrder) do
        if RaidMap == world then
            if act == "1" and previousWorldCleared then
                return true
            end

            local actNum = tonumber(act)
            if actNum and actNum > 1 then
                local prevActClears = WorldStats[world].LevelStats["Act" .. tostring(actNum - 1)].Clears.Value
                return prevActClears > 0
            end

            return false
        end

        -- Check if all 5 acts in this world are cleared
        local allCleared = true
        for a = 1, 5 do
            if WorldStats[RaidMap].LevelStats["Act" .. tostring(a)].Clears.Value == 0 then
                allCleared = false
                break
            end
        end

        previousWorldCleared = allCleared
    end

    return false
end


for i, v in gui.Left_Panel.Contents.Location.Bg:GetChildren() do
	--local validWorldIndex = table.find(StoryModeStats.Worlds,v.Name)
	local highestWorldNumber = player:WaitForChild("StoryProgress").World.Value

    if v:IsA("ImageButton") then
        local WorldUnlocked = isActUnlocked(v.Name, '1')
        
        --print('world unlocked for ' .. v.Name)
        --print(WorldUnlocked)
        
        v.Activated:Connect(function()
            
            local WorldUnlocked = isActUnlocked(v.Name, '1')
            
			if WorldUnlocked then
				--visfalse()
                --script.Parent.StoryFrame.WorldDetails[v.Name].Visible = true
                ActLoader.setActs(v.Name)
                ActLoader.attachConnections()
			else
				notunlocked()
			end

        end)
        
        if not WorldUnlocked then
            v.Contents.Locked.Visible = true
        else

            v.Contents.Text_Container.Acts_Cleared.Text = `Acts Cleared: <font color="#E03DAF">  {unlockedActsCount(v.Name)}/5</font>`
        end
	end
end

local CheckMark = gui.Bottom_Bar.Bottom_Bar.Friends_Only.Contents.Check.Contents.Checkmark

gui.Bottom_Bar.Bottom_Bar.Friends_Only.Activated:Connect(function()    
    CheckMark.Image = if CheckMark.Image == "" then "rbxassetid://14189590169" else ""
	local elevator = findPlayer()
    --gui.Bottom_Bar.Bottom_Bar.Friends_Only:FireServer(CheckMark.Image ~= "")
    findPlayer().ElevatorServer.Choose:FireServer("FriendsOnly", CheckMark.Image ~= "")
end)

notunlocked = function()
	UIHandler.PlaySound("Error")
	_G.Message("Not unlocked!",Color3.new(0.776471, 0.239216, 0.239216))
end

local lastActiveButton = nil
local buttonsActivatedConnections = {}


--player:WaitForChild("StoryProgress"):WaitForChild("World"):GetPropertyChangedSignal("Value"):Connect(UpdateWorldDetails)
--player:WaitForChild("StoryProgress"):WaitForChild("Level"):GetPropertyChangedSignal("Value"):Connect(UpdateWorldDetails)

