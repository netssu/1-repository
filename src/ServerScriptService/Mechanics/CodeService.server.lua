------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

------------------//CONSTANTS
local REMOTE_FOLDER_NAME = "Assets/Remotes"
local REMOTE_NAME = "RedeemCode"

local ACTIVE_CODES = {
	["TATU"] = {
		rewardType = "Currency",
		amount = 500
	},
	["LEITAO"] = {
		rewardType = "Currency",
		amount = 1000
	},
	["POGO"] = {
		rewardType = "Currency",
		amount = 250
	}
}

------------------//VARIABLES
local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local redeemRemote = nil

------------------//FUNCTIONS
local function ensure_remote()
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local remotesObj = assets:WaitForChild("Remotes")

	redeemRemote = remotesObj:FindFirstChild(REMOTE_NAME)
	if not redeemRemote then
		redeemRemote = Instance.new("RemoteFunction")
		redeemRemote.Name = REMOTE_NAME
		redeemRemote.Parent = remotesObj
	end
end

local function process_reward(player, rewardData)
	if rewardData.rewardType == "Currency" then
		local currentCoins = DataUtility.server.get(player, "Coins") or 0
		DataUtility.server.set(player, "Coins", currentCoins + rewardData.amount)
		return true
	end
	return false
end

local function on_redeem_request(player, codeInput)
	if typeof(codeInput) ~= "string" then return "ERROR_INTERNAL" end

	local cleanCode = string.upper(string.gsub(codeInput, "%s+", ""))

	local codeData = ACTIVE_CODES[cleanCode]
	if not codeData then
		return "INVALID"
	end

	local redeemedList = DataUtility.server.get(player, "RedeemedCodes") or {}
	if redeemedList[cleanCode] then
		return "ALREADY_REDEEMED" 
	end

	local success = process_reward(player, codeData)

	if success then
		redeemedList[cleanCode] = true
		DataUtility.server.set(player, "RedeemedCodes", redeemedList)
		return "SUCCESS" 
	else
		return "ERROR_INTERNAL"
	end
end

------------------//INIT
ensure_remote()
redeemRemote.OnServerInvoke = on_redeem_request