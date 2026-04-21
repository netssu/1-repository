if game:GetService('RunService'):IsStudio() then
	_G.GameLoaded = true
	_G.LoadingScreenComplete = true
	script:Destroy()
	return
end

local StarterGui = game:GetService('StarterGui')

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TeleportService = game:GetService("TeleportService")
local ContentProvider = game:GetService("ContentProvider")

--StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)

local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local LoadingGui = TeleportService:GetArrivingTeleportGui() or script:WaitForChild("LoadingGui")
local WorldImage = LoadingGui:WaitForChild("WorldImage")
local Main = WorldImage:WaitForChild("Main")
local TeleportInfo = Main:WaitForChild("TeleportInfo")
local LoadingTextLabel = WorldImage:WaitForChild("LoadingText")

local ForceLoad = false

function LoadIntoGame()
	local UIHander = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIHandler"))
	UIHander.Transition()
	game.Debris:AddItem(LoadingGui, 2)

	print('Setting loaded as true!')
	_G.LoadingScreenComplete = true
end

task.spawn( function()	--Allow user to skip after 10 second if game not loaded
	task.wait(10)
	if LoadingGui.Parent == nil then return end
	LoadingGui.WorldImage.SkipButton.Visible = true
	local connection = LoadingGui.WorldImage.SkipButton.MouseButton1Down:Connect(function()
		ForceLoad = true
        LoadIntoGame()
        --StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
	end)
end)

task.delay(10, function()
    --StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
end)

LoadingGui.Parent = PlayerGui
local dotCounter = 1
local dots = {
	".",
	"..",
	"..."
}
--if not game:IsLoaded() then
task.spawn(function()
	repeat 
	LoadingTextLabel.Text = `Loading{dots[dotCounter]}`
	dotCounter = dotCounter < 3 and dotCounter + 1 or 1
	task.wait(2) 
    until game:IsLoaded() and Player:FindFirstChild("DataLoaded") or ForceLoad
    
    task.wait(6)
    
	if ForceLoad then return end
	LoadIntoGame()
	--StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
end)

_G.GameLoaded = true

ContentProvider:PreloadAsync(LoadingGui:GetDescendants())
task.wait()
ReplicatedFirst:RemoveDefaultLoadingScreen()
ContentProvider:PreloadAsync(workspace:GetDescendants())




--end



--LoadingGui:Destroy()


