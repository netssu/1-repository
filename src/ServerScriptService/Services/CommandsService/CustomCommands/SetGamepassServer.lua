--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--//Dependecies
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)

return function(context, targetPlayer: Player|string, gamepass: string, value: boolean|string)
    local executor = context.Executor
    if typeof(targetPlayer) == "string" then
        targetPlayer = Players:FindFirstChild(targetPlayer)
        if not targetPlayer then return context:Error("Player not found or no longer in game") end
    end

    if typeof(value) == "string" then
        local loweredValue = string.lower(value)
        if loweredValue == "true" then
            value = true
        elseif loweredValue == "false" then
            value = false
        end
        
        if typeof(value) ~= "boolean" then
            return context:Error(`Type of value is wrong: {value}`)
        end
    end

    if not targetPlayer or not Players:FindFirstChild(targetPlayer.Name) then
        return context:Error("Player not found or no longer in game.")
    end

    local gamepassPath = {"Gamepass", gamepass}
    local statvalue = PlayerDataManager:Get(targetPlayer, gamepassPath)
    print(typeof(value), typeof(statvalue))
    if typeof(value) ~= "boolean" then
        return context:Error("Given value is not a boolean")
    end

    if typeof(statvalue) ~= "boolean" then
        return context:Error(`fail to set the gamepass, because the gamepass value in the table is not a boolean`)
    end
    
    PlayerDataManager:Set(targetPlayer, gamepassPath, value)

    local keyWord = value and "Gave" or "Removed"
    local message = (`{keyWord} {gamepass} to {targetPlayer.Name}`)
    context:SendEvent(executor, "Message", message)

    return message
end
