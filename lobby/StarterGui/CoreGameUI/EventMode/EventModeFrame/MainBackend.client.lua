 -- disabled by ace


local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local EasterEvent = workspace:WaitForChild('EventMain')
local JoinEvent = EasterEvent:WaitForChild('Main'):WaitForChild('Join')
local LeaveEvent = EasterEvent:WaitForChild('Main'):WaitForChild('Leave')
local PlayersFolder = EasterEvent:WaitForChild('Players')

local Join = script.Parent.Frame.Bottom_Bar.Bottom_Bar.Join
local Leave = script.Parent.Frame.Bottom_Bar.Bottom_Bar.Leave
local Countdown = EasterEvent.Main:WaitForChild('Countdown')
local PlayersFrame = script.Parent.Frame.Left_Panel.Contents.Players.Bg
local PlayerCountLabel = script.Parent.Frame.Left_Panel.Players
local CountdownTextLabel = script.Parent.Frame.Left_Panel.Countdown

Join.Activated:Connect(function()
    JoinEvent:FireServer()
end)

Leave.Activated:Connect(function()
    LeaveEvent:FireServer()
end)

PlayersFolder.ChildAdded:Connect(function(obj)
    PlayerCountLabel.Text = 'Players (' .. #PlayersFolder:GetChildren() .. '/4)'
    
    local PlayerEntry = script.PlayerFrame:Clone()
    
    PlayerEntry.Name = obj.Name
    
    local foundPlr = Players:FindFirstChild(obj.Name)
    
    if foundPlr then
        PlayerEntry.Contents.Text_Container.PlayerName.Text = '@' .. foundPlr.Name
        
        local Icon = Players:GetUserThumbnailAsync(foundPlr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size352x352)
        PlayerEntry.Contents.Text_Container.PlayerIcon.Image = Icon
    else
        PlayerEntry:Destroy()
        return
    end

    PlayerEntry.Parent = PlayersFrame
end)


PlayersFolder.ChildRemoved:Connect(function(obj)
    PlayerCountLabel.Text = 'Players (' .. #PlayersFolder:GetChildren() .. '/4)'
    local foundPlr = PlayersFrame:FindFirstChild(obj.Name)
    
    if foundPlr then
        foundPlr:Destroy()
    end
end)

Countdown.Changed:Connect(function()
    CountdownTextLabel.Text = `Game Starts in {Countdown.Value}s`
end)

-- UI Information
repeat task.wait() until Players.LocalPlayer:FindFirstChild('DataLoaded')
local Attempts = Players.LocalPlayer.FawnEventAttempts
local HighestWave = Players.LocalPlayer.EventData.Easter.HighestWave
local EventWins = Players.LocalPlayer.EventWins
local Right_Panel = script.Parent.Frame.Right_Panel

local AttemptsTextLabel = Right_Panel.Contents.Times.Contents.Attempts -- Total Attempts: <font color="#51E851">0</font>
local HighestWaveTextLabel = Right_Panel.Contents.Times.Contents.HighestWave -- Highest Wave: <font color="#51E851">0</font>

local function updateAttempts()
    AttemptsTextLabel.Text = `Total Attempts: <font color="#51E851">{Attempts.Value}</font>`
end

local function updateHighestWave()
    HighestWaveTextLabel.Text = `Wins: <font color="#51E851">{EventWins.Value}</font>`
end

updateAttempts()
updateHighestWave()

Attempts.Changed:Connect(updateAttempts)
HighestWave.Changed:Connect(updateHighestWave)

-- Event zone
local Zone = require(ReplicatedStorage.Modules.Zone)
local container = Zone.new(workspace:WaitForChild('EventMain'):WaitForChild('EasterMainHitbox'))
warn(container)



container.playerEntered:Connect(function(player)
	if player == Players.LocalPlayer then
		warn("Opening Frame")
		_G.CloseAll('EventModeFrame')
    end
end)

container.playerExited:Connect(function(player)
    if player == Players.LocalPlayer then
        _G.CloseAll()
    end
end)