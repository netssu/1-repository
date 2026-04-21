local Players = game:GetService('Players')
local Player = Players.LocalPlayer

repeat task.wait() until Player:FindFirstChild('DataLoaded')

local function update()
    script.Parent.Text = Player.LuckySpins.Value
end

update()

Player.LuckySpins.Changed:Connect(update)