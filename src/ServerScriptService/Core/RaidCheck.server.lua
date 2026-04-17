local Players = game:GetService('Players')
local ServerStorage = game:GetService('ServerStorage')
local ErrorService = require(ServerStorage.ServerModules.ErrorService)
local ServerScriptService = game:GetService('ServerScriptService')
local RaidDataSync = require(ServerScriptService.ProfileServiceMain.Main.RaidDataSync)

local function main()
    while task.wait(1) do
        for i, player in pairs(Players:GetChildren()) do
            local s,e = pcall(function()
                if player:FindFirstChild('DataLoaded') then
                    RaidDataSync.checkIfReset(player)
                end
            end)
            
            if not s then
                warn(e)
            end
        end
    end
end

ErrorService.wrap(main)