--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--//Dependecies
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)

return function(context, targetPlayer: Player, spinType: string, amount: number)
    local executor = context.Executor
    if not targetPlayer or not Players:FindFirstChild(targetPlayer.Name) then
        return context:Error("Player not found or no longer in game.")
    end

    local spinValue = PlayerDataManager:Get(targetPlayer, { spinType })
    if not spinValue then
        return context:Error(`{spinType} is not a valid spin type`)
    end

    if typeof(amount) ~= "number" then
        return context:Error(`The type of the amount is not number, given amount type: {typeof(amount)}`)
    end

    if amount <= 0 then
        return context:Error("Amount must be a positive number")
    end

    PlayerDataManager:Increment(targetPlayer, { spinType }, amount)

    local message = (`Gave {amount} of {spinType} to {targetPlayer.Name}`)
    context:SendEvent(executor, "Message", message)

    return message
end
