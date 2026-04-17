local TeleportService = game:GetService("TeleportService")

local EventsFolder = game.ReplicatedStorage.Events
local FunctionsFolder = game.ReplicatedStorage.Functions

local ChallengeModule = require(game.ReplicatedStorage.Modules.ChallengeModule)
local StoryModeStats = require(game.ReplicatedStorage.StoryModeStats)
local UIMapLoadingScreen = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIMapLoadingScreen"))

local ChallengeElevatorsFolder = workspace:WaitForChild("ChallengeElevators")
local OriginDataFolder = ChallengeElevatorsFolder:WaitForChild("Data")


local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

Player:WaitForChild("DataLoaded")
local ViewPortModule = require(game.ReplicatedStorage.Modules.ViewPortModule)
local ChallengeFrame = script.Parent.ChallengeFrame
local ExitButton = ChallengeFrame.Exit
local QuickStartButton = ChallengeFrame.QuickStart

local Player = game.Players.LocalPlayer
local lastChallengeRecordedNumberForSurfaceGui = {}

local function hasNumber(str)
    return string.find(str, "%d") ~= nil
end

local function extractNumber(str)
    local digits = str:gsub("%D", "")
    if digits == "" then
        return nil
    end
    return tonumber(digits)
end

local function getTimeUntil(nextMinutes)
    local now = os.time()
    local refreshInterval = 30 * 60 -- 30 minutes in seconds
    local secondsUntilNext = nextMinutes * 60
    return secondsUntilNext - (now % (90 * 60)) -- assuming 1.5hr cycle
end

local function formatCountdown(seconds)
    local minutes = math.floor(seconds / 60)
    return "In " .. minutes .. " minutes"
end

function UpdateDisplay(SurfaceGui)
    pcall(function()
        if not SurfaceGui.Adornee then
            SurfaceGui.Adornee = workspace.Display[SurfaceGui.Name].Screen
        end
    end)
    
    local DataFolder = nil
    
    if hasNumber(SurfaceGui.Name) then
        DataFolder = ChallengeElevatorsFolder:WaitForChild(SurfaceGui.Name)
    else
        DataFolder = OriginDataFolder
    end

    
	local ChallengeNumber = DataFolder.ChallengeNumber.Value
	local ChallengeRewardNumber = DataFolder.ChallengeRewardNumber.Value
	local World = DataFolder.World.Value
	local Level = DataFolder.Level.Value
	local RefreshingAt = DataFolder.RefreshingAt.Value

	local ChallengeData = ChallengeModule.Data[ChallengeNumber]
	local ChallengeRewardData= ChallengeModule.Rewards[ChallengeData.Difficulty]
	local WorldName = StoryModeStats.Worlds[World]
	local BossName = StoryModeStats.LevelName[WorldName][Level]
	local WorldImageURL = StoryModeStats.Images[World]
	
	
	local InformationFrame = SurfaceGui:WaitForChild("WorldDetails"):WaitForChild("Information")
	local StatusFrame = SurfaceGui:WaitForChild("WorldDetails"):WaitForChild("Status")
	local BossFrame = SurfaceGui:WaitForChild("WorldDetails"):WaitForChild("BossFrame")
	local WorldImage = SurfaceGui:WaitForChild("WorldDetails"):WaitForChild("WorldImage")
	
	
	
	InformationFrame["Story Name"].Text = `{WorldName}`
	InformationFrame.ActName.Text = `Act {Level} - {BossName}`
	InformationFrame.Challenge.Text = `{ChallengeData.Name}`
	InformationFrame.Description.Text = `{ChallengeData.Description}`
	InformationFrame.Reward.Text =  "Rewards: " .. ChallengeRewardData.Description
	
	local TimeRemainingInSeconds = RefreshingAt - os.time()
	local halfAnHour = (TimeRemainingInSeconds%1800) --in seconds
    local minutes, seconds = math.floor(halfAnHour / 60), math.floor(halfAnHour % 60)
    
    if not hasNumber(SurfaceGui.Name) then
        StatusFrame.Timer.Text = `{string.format("%.2i", minutes)}:{string.format("%.2i", seconds)}`
        StatusFrame.Bar.Size = UDim2.new(minutes / 30, 0, 1, 0)
        SurfaceGui.WorldDetails.Status.TextLabel.Text = 'Time Remaining:'
    else
		local val = extractNumber(SurfaceGui.Name) * 30
		local challengeOffset = val * 60 -- 30, 60, or 90 minutes
		local now = os.time()

		local cycleLength = 90 * 60
		local cycleStart = now - (now % cycleLength)
		local targetTime = cycleStart + challengeOffset

		-- If we're past the target time in the current cycle, move to the next
		if targetTime < now then
			targetTime = targetTime + cycleLength
			cycleStart = cycleStart + cycleLength
		end

		local secondsRemaining = math.max(targetTime - now, 0)
		local countdownText = "In " .. math.ceil(secondsRemaining / 60) .. " minutes"

		-- Progress bar shows how far we are into the full 90-minute cycle
		local elapsedInCycle = now - (cycleStart - cycleLength)
		local progressRatio = math.clamp(elapsedInCycle / cycleLength, 0, 1)

		StatusFrame.Timer.Text = ""
		SurfaceGui.WorldDetails.Status.TextLabel.Text = countdownText
		StatusFrame.Bar.Size = UDim2.fromScale(math.ceil(secondsRemaining / 60)/90, 1)


    end

	
	
	if lastChallengeRecordedNumberForSurfaceGui[SurfaceGui] and lastChallengeRecordedNumberForSurfaceGui[SurfaceGui] == ChallengeNumber then return end
	lastChallengeRecordedNumberForSurfaceGui[SurfaceGui] = ChallengeNumber
	local oldBossViewport = BossFrame:FindFirstChildWhichIsA("ViewportFrame")
	if oldBossViewport then oldBossViewport:Destroy() end
	
	--print(BossName)
	local bossViewport = ViewPortModule.CreateViewPort(BossName)
	if not bossViewport then return end
	bossViewport.Size = UDim2.new(1,0,1,0)
	--print(bossViewport)
	local newBossViewport = bossViewport:Clone()
	newBossViewport.Parent = BossFrame
	
end


EventsFolder.ChallengeStarting.OnClientEvent:Connect(function()
    TeleportService:SetTeleportGui(UIMapLoadingScreen.CreateLoadingGui("Game", OriginDataFolder.World.Value, OriginDataFolder.Level.Value, 2))
    print(UIMapLoadingScreen.CreateLoadingGui("Game", OriginDataFolder.World.Value, OriginDataFolder.Level.Value, 2))
	--UIMapLoadingScreen.DisplayLoadingScreenWorld(DataFolder.World.Value, DataFolder.Level.Value)
end)

EventsFolder.PlayerJoinChallenge.OnClientEvent:Connect(function(hasJoin, Elevator, hostPlayer)
	ChallengeFrame.Visible = hasJoin
	if hasJoin then 
		Camera.CameraType = Enum.CameraType.Scriptable
		Camera.CFrame = Elevator.Camera.CFrame
		
	else
		Camera.CameraType = Enum.CameraType.Custom
		return
	end
	if hostPlayer == Player then
		ExitButton.Visible = true
		QuickStartButton.Visible = true
	else
		ExitButton.Visible = true
		QuickStartButton.Visible = false
	end
end)

QuickStartButton.Activated:Connect(function()
	local valid = FunctionsFolder.RequestChallengeStart:InvokeServer()
	if valid then
		ChallengeFrame.Visible = false
	end
end)
ExitButton.Activated:Connect(function()
	local valid = FunctionsFolder.RequestChallengeLeave:InvokeServer()
	print(valid)
	if valid then
		ChallengeFrame.Visible = false
	end
end)

local ls = {}
local done = false

for _, surfaceGui in PlayerGui:WaitForChild("GameGui"):WaitForChild("Displays"):WaitForChild("Challenge"):GetChildren() do
    if not done then
    	OriginDataFolder.ChallengeNumber:GetPropertyChangedSignal("Value"):Connect(function()
            UpdateDisplay(surfaceGui)
        end)
        done = true
    end

    table.insert(ls, surfaceGui)
	UpdateDisplay(surfaceGui)
end

while true do
    for i,v in ls do
        UpdateDisplay(v)
    end
    
    task.wait(1)
end