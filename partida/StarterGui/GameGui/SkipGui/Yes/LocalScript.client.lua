-- SERVICES
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- CONSTANTS

-- VARIABLES
local player = Players.LocalPlayer

-- FUNCTIONS

-- INIT
script.Parent.Selectable = true
script.Parent.Active = true

script.Parent.Activated:Connect(function()
	local result = ReplicatedStorage.Functions.VoteForSkip:InvokeServer()

	if typeof(result) == "string" then
		if result == "Cannot skip on the final wave!" then
			script.Parent.Visible = false
		end
		_G.Message(result, Color3.new(0.831373, 0, 0))
	else
		TweenService:Create(script.Parent.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Position = UDim2.new(1.2, 0, 0.34, 0)}):Play()
		task.wait(0.25)
		script.Parent.Parent.Visible = false
	end
end)