local RunService = game:GetService("RunService")

if RunService:IsStudio() then
	_G.GameLoaded = true
	_G.LoadingScreenComplete = true
	script:Destroy()
	return
end

local StarterGui = game:GetService("StarterGui")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TeleportService = game:GetService("TeleportService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local LoadingGui = TeleportService:GetArrivingTeleportGui() or script:WaitForChild("LoadingGui")
local WorldImage = LoadingGui:WaitForChild("WorldImage")
local Main = WorldImage:WaitForChild("Main")
local TeleportInfo = Main:WaitForChild("TeleportInfo")
local LoadingTextLabel = WorldImage:WaitForChild("LoadingText")
local SkipButton = WorldImage:WaitForChild("SkipButton")

local ForceLoad = false
local Finished = false
local AssetsLoaded = false

local function SetChatEnabled(enabled)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, enabled)
	end)
end

SetChatEnabled(false)

local function LoadIntoGame()
	if Finished then
		return
	end

	Finished = true

	local UIHandler = require(
		ReplicatedStorage
			:WaitForChild("Modules")
			:WaitForChild("Client")
			:WaitForChild("UIHandler")
	)

	UIHandler.Transition()

	SetChatEnabled(true)

	Debris:AddItem(LoadingGui, 2)

	print("Setting loaded as true!")

	_G.LoadingScreenComplete = true
end

local function PreloadOneByOne(root)
	local assets = root:GetDescendants()
	local totalAssets = #assets

	for index, asset in ipairs(assets) do
		if ForceLoad or Finished then
			return false
		end

		LoadingTextLabel.Text = `Loading Assets {index}/{totalAssets}`

		local success, err = pcall(function()
			ContentProvider:PreloadAsync({ asset })
		end)

		if not success then
			warn("Failed to preload asset:", asset:GetFullName(), err)
		end

		task.wait()
	end

	return true
end

LoadingGui.Parent = PlayerGui
_G.GameLoaded = true

task.spawn(function()
	task.wait(10)

	if Finished or LoadingGui.Parent == nil then
		return
	end

	SkipButton.Visible = true

	SkipButton.MouseButton1Down:Connect(function()
		if Finished then
			return
		end

		ForceLoad = true
		LoadIntoGame()
	end)
end)

task.spawn(function()
	task.wait(10)

	if not Finished then
		SetChatEnabled(true)
	end
end)

PreloadOneByOne(LoadingGui)

task.wait()

ReplicatedFirst:RemoveDefaultLoadingScreen()

PreloadOneByOne(workspace)

AssetsLoaded = true

local dotCounter = 1
local dots = {
	".",
	"..",
	"..."
}

repeat
	LoadingTextLabel.Text = `Loading{dots[dotCounter]}`
	dotCounter = dotCounter < 3 and dotCounter + 1 or 1

	task.wait(0.5)
until ForceLoad or Finished or (
	game:IsLoaded()
		and Player:FindFirstChild("DataLoaded")
		and AssetsLoaded
)

if ForceLoad or Finished then
	return
end

task.wait(6)

if ForceLoad or Finished then
	return
end

LoadIntoGame()