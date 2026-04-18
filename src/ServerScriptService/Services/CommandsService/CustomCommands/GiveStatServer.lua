--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--//Dependecies
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)

local function normalizePlayerQuery(text: string): string
    return string.lower(text):gsub("[%s_%-_]+", "")
end

local function startsWith(text: string, prefix: string): boolean
    return string.sub(text, 1, #prefix) == prefix
end

local function resolvePlayer(targetPlayer: Player | string): (Player?, string?)
    if typeof(targetPlayer) == "Instance" and targetPlayer:IsA("Player") then
        return targetPlayer, nil
    end

    if typeof(targetPlayer) ~= "string" then
        return nil, "Player not found or no longer in game."
    end

    if targetPlayer == "" then
        return nil, "Player name is required."
    end

    local normalizedQuery = normalizePlayerQuery(targetPlayer)
    if normalizedQuery == "" then
        return nil, "Player name is required."
    end

    for _, player in Players:GetPlayers() do
        if normalizePlayerQuery(player.Name) == normalizedQuery then
            return player, nil
        end
    end

    local exactDisplayMatch = nil
    for _, player in Players:GetPlayers() do
        if normalizePlayerQuery(player.DisplayName) == normalizedQuery then
            if exactDisplayMatch and exactDisplayMatch ~= player then
                return nil, "Multiple players match that display name. Type the username instead."
            end
            exactDisplayMatch = player
        end
    end
    if exactDisplayMatch then
        return exactDisplayMatch, nil
    end

    local prefixMatch = nil
    local matchedPlayers = {}
    for _, player in Players:GetPlayers() do
        local normalizedName = normalizePlayerQuery(player.Name)
        local normalizedDisplayName = normalizePlayerQuery(player.DisplayName)
        if startsWith(normalizedName, normalizedQuery) or startsWith(normalizedDisplayName, normalizedQuery) then
            if not matchedPlayers[player] then
                matchedPlayers[player] = true
                if prefixMatch and prefixMatch ~= player then
                    return nil, (`Multiple players match "{targetPlayer}". Type more letters.`)
                end
                prefixMatch = player
            end
        end
    end
    if prefixMatch then
        return prefixMatch, nil
    end

    return nil, "Player not found or no longer in game."
end

local function resolveAmount(amount: any): (number?, string?)
    if typeof(amount) == "number" then
        return amount, nil
    end

    if typeof(amount) == "string" then
        local parsedAmount = tonumber(amount)
        if parsedAmount ~= nil then
            return parsedAmount, nil
        end
    end

    return nil, (`The type of the amount is not number, given amount type: {typeof(amount)}`)
end

return function(context, targetPlayer: Player | string, statType: string, amount: number | string)
    local executor = context.Executor
    local resolvedPlayer, resolvePlayerError = resolvePlayer(targetPlayer)
    if not resolvedPlayer or not Players:FindFirstChild(resolvedPlayer.Name) then
        return context:Error(resolvePlayerError or "Player not found or no longer in game.")
    end

    if typeof(statType) ~= "string" or statType == "" then
        return context:Error("The given stat path is not a valid path")
    end

    local resolvedAmount, resolveAmountError = resolveAmount(amount)
    if resolvedAmount == nil then
        return context:Error(resolveAmountError or "Amount must be a number")
    end

    local statvalue = PlayerDataManager:Get(resolvedPlayer, {statType})
    if statvalue == nil then
        return context:Error("The given stat path is not a valid path")
    end

    if typeof(statvalue) ~= "number" then
        return context:Error(`The target stat is not numeric, current type: {typeof(statvalue)}`)
    end
    
    if resolvedAmount <= 0 then
        return context:Error("Value must be a positive number")
    end

    PlayerDataManager:Increment(resolvedPlayer, {statType}, resolvedAmount)

    local message = (`Gave {resolvedAmount} of the {statType} to {resolvedPlayer.Name}`)
    context:SendEvent(executor, "Message", message)

    return message
end
