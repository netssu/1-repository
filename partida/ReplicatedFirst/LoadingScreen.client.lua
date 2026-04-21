local ContentProvider = game:GetService("ContentProvider")
local TeleportService = game:GetService("TeleportService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local loadingGui = TeleportService:GetArrivingTeleportGui()

local ForceLoad = false

function LoadIntoGame()
	if loadingGui then
		loadingGui:Destroy()
	end
end

task.spawn( function()	--Allow user to skip after 10 second if game not loaded
	task.wait(10)
	if game:IsLoaded() then LoadIntoGame() return end
	loadingGui.WorldImage.SkipButton.Visible = true
	local connection = loadingGui.WorldImage.SkipButton.MouseButton1Down:Connect(function()
		ForceLoad = true
		LoadIntoGame()
	end)
end)

if loadingGui then 
	loadingGui.Parent = PlayerGui
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end

local assetsToPreload = game:GetDescendants()

if #assetsToPreload > 0 then
	ContentProvider:PreloadAsync(assetsToPreload)
end

local dots = {
	".",
	"..",
	"..."
}

local dotCounter = 1
--if not game:IsLoaded() then
repeat 
	if loadingGui then
		local LoadingTextLabel = loadingGui.WorldImage.LoadingText
		LoadingTextLabel.Text = `Loading{dots[dotCounter]}`
		dotCounter = dotCounter < 3 and dotCounter + 1 or 1
	end

	task.wait(0.5) 
until game:IsLoaded() or ForceLoad
--end

if ForceLoad then return end
LoadIntoGame()