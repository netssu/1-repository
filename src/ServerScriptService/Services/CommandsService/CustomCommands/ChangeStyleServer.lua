--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--//Dependencies
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local StyleAdminOptions = require(ReplicatedStorage.Modules.Data.StyleAdminOptions)

local DEFAULT_SELECTED_SLOT = 1
local MIN_SELECTED_SLOT = 1
local MAX_SELECTED_SLOT = 4

local function normalizePlayerQuery(text: string): string
    return string.lower(text):gsub("[%s_%-_]+", "")
end

local function startsWith(text: string, prefix: string): boolean
    return string.sub(text, 1, #prefix) == prefix
end

local function resolvePlayer(targetPlayer: Player | string): (Player?, string?)
    if typeof(targetPlayer) == "string" then
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

    if typeof(targetPlayer) == "Instance" and targetPlayer:IsA("Player") then
        return targetPlayer, nil
    end

    return nil, "Player not found or no longer in game."
end

local function resolveSelectedSlot(slotValue: any): number
    local slotNumber = tonumber(slotValue) or DEFAULT_SELECTED_SLOT
    slotNumber = math.floor(slotNumber)

    if slotNumber < MIN_SELECTED_SLOT or slotNumber > MAX_SELECTED_SLOT then
        return DEFAULT_SELECTED_SLOT
    end

    return slotNumber
end

local function resolveStyleId(styleName: string): string?
    return StyleAdminOptions.ResolveStyleId(styleName)
end

return function(context, targetPlayer: Player | string, styleName: string)
    local executor = context.Executor
    local resolvedPlayer, resolvePlayerError = resolvePlayer(targetPlayer)
    if not resolvedPlayer or not Players:FindFirstChild(resolvedPlayer.Name) then
        return context:Error(resolvePlayerError or "Player not found or no longer in game.")
    end

    if typeof(styleName) ~= "string" or styleName == "" then
        return context:Error("Style name is required.")
    end

    local styleId = resolveStyleId(styleName)
    if not styleId then
        local availableStyles = StyleAdminOptions.GetAvailableDisplayText()
        return context:Error(`Invalid style. Available styles: {availableStyles}.`)
    end

    local selectedSlot = resolveSelectedSlot(PlayerDataManager:Get(resolvedPlayer, { "SelectedSlot" }))
    local slotKey = "Slot" .. tostring(selectedSlot)

    PlayerDataManager:Set(resolvedPlayer, { "StyleSlots", slotKey }, styleId)

    local displayStyleName = StyleAdminOptions.GetDisplayName(styleId)
    local message = (`Changed {resolvedPlayer.Name}'s style to {displayStyleName} in {slotKey}`)

    context:SendEvent(executor, "Message", message)

    return message
end
