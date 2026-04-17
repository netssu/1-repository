local Players = game:GetService('Players')
local Player = Players.LocalPlayer

repeat task.wait() until Player:FindFirstChild('DataLoaded')

local function update()
	script.Parent.Text = Player.Stats.Kills.Value .. ' Enemy Kills'
end

update()

Player.Stats.Kills.Changed:Connect(update)