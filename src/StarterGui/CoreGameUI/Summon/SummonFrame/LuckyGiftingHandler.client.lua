local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Button = script.Parent.Lucky_Summons
local Players = game:GetService('Players')
local LuckySummonsFrame = script.Parent.Parent.Parent.LuckySummons.LuckySummonsFrame
local PassesList = require(ReplicatedStorage.Modules.PassesList)
local BuyEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Buy")

local SelectedGiftId = script.Parent.Parent.Parent:WaitForChild("Gift"):WaitForChild("SelectedGiftId")
local GiftFrame = script.Parent.Parent.Parent.Gift.GiftFrame

Button.Activated:Connect(function()
    if not LuckySummonsFrame.Visible then
        _G.CloseAll('LuckySummonsFrame')
    --else
        --_G.CloseAll('SummonFrame')
    end
end)

LuckySummonsFrame.Frame.X_Close.Activated:Connect(function()
    _G.CloseAll('SummonFrame')
end)

for i,v in pairs(LuckySummonsFrame.Frame.Purchaseables.main_bg:GetChildren()) do
    if v:IsA('Frame') then
        v.Low_Spins.Activated:Connect(function()
            local id = PassesList.Information[v.Name].Id
            BuyEvent:FireServer(id)
        end)
        
        v.Low_Spins.Container.Gift.Activated:Connect(function()
            local id = PassesList.Information[v.Name].GiftId
            SelectedGiftId.Value = id
            GiftFrame.Visible = true
        end)
    end
end