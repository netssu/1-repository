local ServerStorage = game:GetService('ServerStorage')
local ErrorCatcher = require(ServerStorage.ServerModules.ErrorService)

local function doSomethingRisky(player)
    error("uh oh 💥")
end

game.Players.PlayerAdded:Connect(function(player)
    ErrorCatcher.wrap(doSomethingRisky, player)
end)