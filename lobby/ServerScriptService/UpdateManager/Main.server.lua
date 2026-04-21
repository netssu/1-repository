local MessagingService = game:GetService('MessagingService')
local TeleportService = game:GetService('TeleportService')
local Players = game:GetService('Players')

MessagingService:SubscribeAsync('NewUpdate', function()
    local success = false
    local err = false

    repeat
        success, err = pcall(function()
            TeleportService:TeleportAsync(118144453822471, Players:GetChildren())
        end)
        if not success then
            warn(err)
        end
        
        task.wait(5)
    until success
    
    Players.PlayerAdded:Connect(function(plr)
        plr:Kick('Oops, this is an old server')
    end)
    
    task.wait(5)
    for i,v in pairs(Players:GetChildren()) do
        v:Kick()
    end
    
    --Players:ClearAllChildren()
end)