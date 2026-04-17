local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local States = ReplicatedStorage.States
local VersionVal = States.Version
local frameCount = 0
local timeAccumulator = 0
local updateInterval = 0.5  -- seconds
local lastTime = os.clock()
local PingFunction = ReplicatedStorage.Functions.GetPing

if VersionVal.Value < 5 and not RunService:IsStudio() then
	script.Parent.Enabled = false
end

local MainFrame = script.Parent.MainFrame

-- Display stats:

-- FPS:
local FPSLabel = MainFrame.FPS.TextLabel
RunService.RenderStepped:Connect(function()
	local currentTime = os.clock()
	local deltaTime = currentTime - lastTime
	lastTime = currentTime

	frameCount += 1
	timeAccumulator += deltaTime

	if timeAccumulator >= updateInterval then
		local averageFps = frameCount / timeAccumulator
		--script.Parent.Text = "FPS: " .. math.floor(averageFps + 0.5)
		FPSLabel.Text = `{math.floor(averageFps + 0.5)} FPS`
		
		frameCount = 0
		timeAccumulator = 0
	end
end)

-- UserId:
MainFrame.UserId.TextLabel.Text = Player.UserId

-- Ping:
while true do
	local startTime = os.clock()
	PingFunction:InvokeServer()
	local endTime = os.clock()

	local roundTrip = endTime - startTime
	local pingMs = math.floor((roundTrip * 0.5) * 1000)

	MainFrame.Ping.TextLabel.Text = `{pingMs}ms`

	task.wait(2)
end