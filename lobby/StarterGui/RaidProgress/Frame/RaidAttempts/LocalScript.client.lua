local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local Player = Players.LocalPlayer

repeat task.wait() until Player:FindFirstChild('DataLoaded')

local val = Player.RaidLimitData.Attempts
local TotalRaidAttempts = ReplicatedStorage.States.TotalRaidAttempts

local function update()
	script.Parent.Text = `Raid Attempts: {val.Value}/{TotalRaidAttempts.Value}`
end

update()
val.Changed:Connect(update)