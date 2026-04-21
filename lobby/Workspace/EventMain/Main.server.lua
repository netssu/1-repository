local Players = game:GetService('Players')
local ServerScriptService = game:GetService('ServerScriptService')
local TeleportService = game:GetService('TeleportService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local SafeTeleport = require(ServerScriptService.SafeTeleport)
local PlaceData = require(game.ServerStorage.ServerModules.PlaceData)

local function TeleportPlayers()
    local placeId = PlaceData.Game
    local server = TeleportService:ReserveServer(placeId)
    local options = Instance.new("TeleportOptions")
    options.ReservedServerAccessCode = server
    local ownerPlayer = game.Players:FindFirstChild(script.Parent.Owner.Value)
    local ownerId = ownerPlayer and ownerPlayer.UserId or nil
    
    local playersWaiting = {}
    
    for i,v in pairs(script.Parent.Players:GetChildren()) do
        local plr = Players:FindFirstChild(v.Name)
        
        if plr then
            ReplicatedStorage.Remotes.UI.Blackout:FireClient(plr)
            table.insert(playersWaiting, plr)
        end
        
        v:Destroy()
    end

    options:SetTeleportData({World = 11,Level = 1, Mode = 2, OwnerId = ownerId, Raid = false, Event = true})
    SafeTeleport(placeId, playersWaiting, options)
    script.Parent.Owner.Value = ''
end


local breakLoop = true

script.Join.OnServerEvent:Connect(function(plr)
    if #script.Parent.Players:GetChildren() ~= 4 and not script.Parent.Players:FindFirstChild(plr.Name) then
        
        Instance.new('Folder', script.Parent.Players).Name = plr.Name
        
        if #script.Parent.Players:GetChildren() == 1 then
            script.Parent.Owner.Value = plr.Name
        end
    end
end)

script.Leave.OnServerEvent:Connect(function(plr)
    if script.Parent.Players:FindFirstChild(plr.Name) then
        script.Parent.Players[plr.Name]:Destroy()
        
        if script.Parent.Owner.Value == plr.Name then
           if #script.Parent.Players:GetChildren() ~= 0 then
                script.Parent.Owner.Value = script.Parent.Players:GetChildren()[1].Name
           else
                script.Parent.Owner.Value = ''
           end
        end
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    local foundPlr = script.Parent.Players:FindFirstChild(plr.Name)
    
    if foundPlr then
        foundPlr:Destroy()
    end
    
    if #script.Parent.Players:GetChildren() == 0 then
        breakLoop = true
    end
end)

while true do
    if breakLoop then
        script.Countdown.Value = 15
        breakLoop = false
    end
    
    if #script.Parent.Players:GetChildren() ~= 0 then
        script.Countdown.Value -= 1
    else
        script.Countdown.Value = 15
    end
    
    if script.Countdown.Value == 0 then
        local s,e = pcall(TeleportPlayers)
        
        if not s then
            print('There was an error teleporting:')
            print(e)
        end
        
        breakLoop = true
    end
    
    task.wait(1)
end