local CodesService = {}

------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

------------------//PACKAGES
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local Packet = require(ReplicatedStorage.Modules.Game.Packets)

------------------//CONSTANTS
local AVAILABLE_CODES = {
    ["SPIN10"] = {
        RewardType = "SpinStyle",
        Amount = 10
    },
    ["YEN500"] = {
        RewardType = "Yen",
        Amount = 500
    },
    ["WELCOME"] = {
        RewardType = "Yen",
        Amount = 1000
    },
    ["NETSUISGAY"] = {
        RewardType = "Yen",
        Amount = 1000
    },
}

------------------//FUNCTIONS

local function grantReward(player, rewardData)
    local success, err = pcall(function()
        PlayerDataManager:Increment(player, {rewardData.RewardType}, rewardData.Amount)
    end)
    
    return success
end

local function onRedeemRequest(player, codeText)
    if not player or not player:IsDescendantOf(Players) then 
        return "Error" 
    end
    
    if typeof(codeText) ~= "string" or codeText == "" then 
        return "Invalid Code" 
    end
    
    local cleanCode = string.upper(string.gsub(codeText, "%s+", ""))
    
    local rewardData = AVAILABLE_CODES[cleanCode]
    if not rewardData then
        return "Invalid Code" 
    end
    
    local redeemedCodes = PlayerDataManager:Get(player, {"RedeemedCodes"})
    if not redeemedCodes then 
        redeemedCodes = {}
    end
    
    for _, code in ipairs(redeemedCodes) do
        if code == cleanCode then
            return "Already Redeemed"
        end
    end
    
    local insertSuccess, insertErr = pcall(function()
        PlayerDataManager:Insert(player, {"RedeemedCodes"}, cleanCode)
    end)
    
    if not insertSuccess then
        return "Error"
    end
    
    local rewardSuccess = grantReward(player, rewardData)
    
    if rewardSuccess then
        return "Success"
    else
        pcall(function()
            local codes = PlayerDataManager:Get(player, {"RedeemedCodes"})
            for i, code in ipairs(codes) do
                if code == cleanCode then
                    PlayerDataManager:Remove(player, {"RedeemedCodes"}, i)
                    break
                end
            end
        end)
        return "Error"
    end
end

------------------//INIT

function CodesService.Start()
    Packet.RequestRedeemCode.OnServerInvoke = function(player, ...)
        local success, result = pcall(onRedeemRequest, player, ...)
        
        if success then
            return result
        else
            return "Error"
        end
    end
end

return CodesService