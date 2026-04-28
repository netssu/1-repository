-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- CONSTANTS
local LOCK_IMAGE = "rbxassetid://116387490078387"

-- VARIABLES
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local movingEvent = ReplicatedStorage.Events:WaitForChild("MovingElevator")
local elevatorEvent = ReplicatedStorage.Events:WaitForChild("Elevator")
local ownerLeavesElevator = ReplicatedStorage.Events:WaitForChild("OwnerLeavesElevator")

local PlayerGui = player:WaitForChild("PlayerGui")
local NewUI = PlayerGui:WaitForChild("NewUI")
local StoryModeUI = NewUI:WaitForChild("StoryFrame")

local Body = StoryModeUI:WaitForChild("Body")
local Main = Body:WaitForChild("Main")
local Buttons = Main:WaitForChild("Buttons")
local Left_Panel = Main:WaitForChild("Left_Panel")
local LeftSection = StoryModeUI:WaitForChild("LeftSection")

local JoinBtn = Buttons:WaitForChild("Join"):WaitForChild("Btn")
local FriendOnlyBtn = Buttons:WaitForChild("FriendOnly"):WaitForChild("Check"):WaitForChild("Btn")
local FriendOnlyTick = Buttons:WaitForChild("FriendOnly"):WaitForChild("Check"):WaitForChild("Tick")
local CloseBtn = Body:WaitForChild("Closebtn"):WaitForChild("Btn")
local QuitBtn = LeftSection:WaitForChild("Quit"):WaitForChild("Btn")

local ViewPortModule = require(ReplicatedStorage.Modules:WaitForChild("ViewPortModule"))
local StoryModeStats = require(ReplicatedStorage:WaitForChild("StoryModeStats"))
local Simplebar = require(ReplicatedStorage.Modules.Client:WaitForChild("Simplebar"))
local UIHandler = require(ReplicatedStorage.Modules.Client:WaitForChild("UIHandler"))
local ActLoader = require(script:WaitForChild("ActLoader"))

local currentElevator = nil
local selectedStoryWorld = nil
local selectedStoryActIndex = nil
local selectedStoryMode = nil

-- FUNCTIONS
local function setSimplebarVisible(state)
	Simplebar.toggleSimplebar(state)
end

local function restoreCamera()
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function notunlocked()
	UIHandler.PlaySound("Error")
	if _G.Message then
		_G.Message("Not unlocked!", Color3.new(0.776471, 0.239216, 0.239216))
	end
end

local function leaveStoryElevator()
	UIHandler.PlaySound("Close")
	UIHandler.EnableAllButtons()
	setSimplebarVisible(true)

	StoryModeUI.Visible = false
	restoreCamera()
	elevatorEvent:FireServer()
end

local function startStoryQuickStart()
	local elevator = currentElevator
	if not elevator or elevator.Owner.Value ~= player.Name then
		return
	end

	currentElevator = nil
	StoryModeUI.Visible = false
	elevator.ElevatorServer.QuickStart:FireServer()
end

local function isActUnlocked(world, act)
	local WorldStats = player:WaitForChild("WorldStats")
	if world == "Naboo Planet" and (act == "1" or act == "Act1") then
		return true
	end

	local worldOrder = StoryModeStats.Worlds
	local previousWorldCleared = false

	for _, raidMap in ipairs(worldOrder) do
		if raidMap == world then
			local actNumber = tonumber(string.match(tostring(act), "(%d+)"))
			if actNumber == 1 and previousWorldCleared then
				return true
			end
			if actNumber and actNumber > 1 then
				local previousActClears = WorldStats[world].LevelStats["Act" .. tostring(actNumber - 1)].Clears.Value
				return previousActClears > 0
			end
			return false
		end

		local allCleared = true
		for levelIndex = 1, #StoryModeStats.LevelName[raidMap] do
			if WorldStats[raidMap].LevelStats["Act" .. tostring(levelIndex)].Clears.Value == 0 then
				allCleared = false
				break
			end
		end
		previousWorldCleared = allCleared
	end
	return false
end

local function unlockedActsCount(world)
	local count = 0
	for _, levelStat in ipairs(player.WorldStats[world].LevelStats:GetChildren()) do
		if levelStat.Clears.Value ~= 0 then
			count += 1
		end
	end
	return count
end

local function UpdatePlayerFrame(elevator)
	if elevator then
		currentElevator = elevator
		local elevatorInformationFrame = elevator.Door.Surface.Frame.InformationFrame
		local playersStorage = LeftSection.PlayerList
		local maxPlayersValue = elevator:FindFirstChild("MaxPlayers") and elevator.MaxPlayers.Value or 4

		local function updateInfo()
			local currentPlayers = #elevator.Players:GetChildren()
			LeftSection.Queu.Bar.Title.Text = "waiting for players.. " .. tostring(currentPlayers) .. "/" .. tostring(maxPlayersValue)

			local targetSize = elevatorInformationFrame.Status.Bar.Size
			TweenService:Create(LeftSection.Queu.Bar.Bg.Fill, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {Size = targetSize}):Play()

			for _, ui in ipairs(playersStorage:GetChildren()) do
				if ui:IsA("ImageLabel") and ui.Name ~= "PlayerProfile" then
					if not elevator.Players:FindFirstChild(ui.Name) then
						ui:Destroy()
					end
				end
			end

			local templateProfile = playersStorage:FindFirstChild("PlayerProfile")
			if templateProfile then
				templateProfile.Visible = false
				for _, playerValue in ipairs(elevator.Players:GetChildren()) do
					local targetPlayer = Players:FindFirstChild(playerValue.Name)
					if not targetPlayer or playersStorage:FindFirstChild(playerValue.Name) then
						continue
					end

					local clonePlayerImage = templateProfile:Clone()
					task.spawn(function()
						local ok, image = pcall(function()
							return Players:GetUserThumbnailAsync(targetPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
						end)
						if ok then
							clonePlayerImage.Image = image
						end
					end)
					clonePlayerImage.Name = targetPlayer.Name
					clonePlayerImage.Visible = true
					clonePlayerImage.Parent = playersStorage
				end
			end
		end

		repeat
			updateInfo()
			task.wait(0.5)
		until currentElevator ~= elevator
	else
		StoryModeUI.Visible = false
		currentElevator = nil
		selectedStoryWorld = nil
		selectedStoryActIndex = nil
		selectedStoryMode = nil
		restoreCamera()
	end
end

-- INIT
movingEvent.OnClientEvent:Connect(function()
	currentElevator = nil
	StoryModeUI.Visible = false
end)

elevatorEvent.OnClientEvent:Connect(function(elevator, gamemode)
	if _G.CloseAll then _G.CloseAll() end
	UIHandler.DisableAllButtons()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = elevator.Camera.CFrame

	StoryModeUI.Visible = true
	Main.Visible = (elevator.Owner.Value == player.Name)
	FriendOnlyTick.ImageTransparency = elevator.FriendsOnly.Value and 0 or 1

	if elevator.Owner.Value == player.Name then
		selectedStoryWorld = "Naboo Planet"
		selectedStoryActIndex = 1
		selectedStoryMode = 1
		ActLoader.setActs("Naboo Planet")
		ActLoader.selectAct("Act1")
	end

	task.spawn(function()
		UpdatePlayerFrame(elevator)
	end)
end)

ownerLeavesElevator.OnClientEvent:Connect(function()
	UIHandler.PlaySound("Close")
	UIHandler.EnableAllButtons()
	UpdatePlayerFrame()
end)

CloseBtn.Activated:Connect(leaveStoryElevator)
QuitBtn.Activated:Connect(leaveStoryElevator)

JoinBtn.Activated:Connect(function()
	startStoryQuickStart()
end)

FriendOnlyBtn.Activated:Connect(function()
	local elevator = currentElevator
	if not elevator then return end

	local isCurrentlyFriendsOnly = (FriendOnlyTick.ImageTransparency == 0)
	local newState = not isCurrentlyFriendsOnly

	FriendOnlyTick.ImageTransparency = newState and 0 or 1

	elevator.ElevatorServer.FriendsOnly:FireServer(newState)
end)

for _, worldButton in ipairs(Left_Panel.Contents.Location.Bg:GetChildren()) do
	if worldButton:IsA("ImageButton") or worldButton:IsA("GuiButton") then
		worldButton.Activated:Connect(function()
			local worldUnlocked = isActUnlocked(worldButton.Name, "1")
			if worldUnlocked then
				ActLoader.setActs(worldButton.Name)
				ActLoader.attachConnections()
				selectedStoryWorld = worldButton.Name
				selectedStoryActIndex = 1
			else
				notunlocked()
			end
		end)

		local worldUnlocked = isActUnlocked(worldButton.Name, "1")
		if not worldUnlocked then
			if worldButton:FindFirstChild("Contents") and worldButton.Contents:FindFirstChild("Locked") then
				worldButton.Contents.Locked.Visible = true
			end
		else
			if worldButton:FindFirstChild("Contents") and worldButton.Contents:FindFirstChild("Text_Container") and worldButton.Contents.Text_Container:FindFirstChild("Acts_Cleared") then
				worldButton.Contents.Text_Container.Acts_Cleared.Text = string.format("Acts Cleared: <font color=\"#E03DAF\">  %d/%d</font>", unlockedActsCount(worldButton.Name), 5)
			end
		end
	end
end