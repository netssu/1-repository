------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local PROFILE_REMOTES_FOLDER_NAME: string = "ProfileRemotes"
local REDEEM_REMOTE_NAME: string = "RedeemCode"
local PROFILE_ROOT_NAME: string = "Profile"
local CODES_NAME: string = "Codes"
local CURRENCY_ROOT_NAME: string = "Currency"
local CASH_NAME: string = "Cash"
local XP_NAME: string = "XP"
local MAX_CODE_LENGTH: number = 40

type CodeReward = {
	Cash: number,
	XP: number,
}

local CODE_REWARDS: { [string]: CodeReward } = {
	NETSSUDEV = { Cash = 1000, XP = 500 },
	HERCKAOS = { Cash = 1500, XP = 750 },
	FORMULAE = { Cash = 2000, XP = 1000 },
}

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local profileRemotes: Folder = ReplicatedStorage:WaitForChild(PROFILE_REMOTES_FOLDER_NAME)

------------------//VARIABLES
local redeemCode: RemoteEvent
local activeRedemptions: { [Player]: boolean } = {}

------------------//FUNCTIONS
local function get_or_create_remote(): RemoteEvent
	local existingRemote = profileRemotes:FindFirstChild(REDEEM_REMOTE_NAME)
	if existingRemote and existingRemote:IsA("RemoteEvent") then
		return existingRemote
	end

	if existingRemote then
		existingRemote:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = REDEEM_REMOTE_NAME
	remote.Parent = profileRemotes
	return remote
end

local function normalize_code(rawCode: any): string?
	if type(rawCode) ~= "string" then
		return nil
	end

	local normalizedCode = string.upper(string.gsub(rawCode, "^%s*(.-)%s*$", "%1"))
	if #normalizedCode == 0 or #normalizedCode > MAX_CODE_LENGTH then
		return nil
	end

	return normalizedCode
end

local function send_result(player: Player, isSuccessful: boolean, code: string?, reward: CodeReward?, reason: string?): ()
	if isSuccessful and reward then
		redeemCode:FireClient(player, true, code, reward.Cash, reward.XP)
		return
	end

	redeemCode:FireClient(player, false, code, 0, 0, reason)
end

local function redeem_code(player: Player, rawCode: any): ()
	if activeRedemptions[player] then
		return
	end

	activeRedemptions[player] = true
	local code = normalize_code(rawCode)
	local reward = code and CODE_REWARDS[code]
	if not code or not reward then
		send_result(player, false, code, nil, "INVALID_CODE")
		activeRedemptions[player] = nil
		return
	end

	local profile = dataUtility.server.get(player, PROFILE_ROOT_NAME)
	if type(profile) ~= "table" then
		send_result(player, false, code, nil, "PROFILE_NOT_READY")
		activeRedemptions[player] = nil
		return
	end

	local claimedCodes = profile[CODES_NAME]
	if type(claimedCodes) ~= "table" then
		claimedCodes = {}
	end
	if claimedCodes[code] == true then
		send_result(player, false, code, nil, "ALREADY_CLAIMED")
		activeRedemptions[player] = nil
		return
	end

	local currentCash = tonumber(dataUtility.server.get(player, CURRENCY_ROOT_NAME .. "." .. CASH_NAME)) or 0
	local currentXp = tonumber(dataUtility.server.get(player, CURRENCY_ROOT_NAME .. "." .. XP_NAME)) or 0
	local updatedCodes = table.clone(claimedCodes)
	updatedCodes[code] = true
	dataUtility.server.set(player, PROFILE_ROOT_NAME .. "." .. CODES_NAME, updatedCodes)
	dataUtility.server.set(player, CURRENCY_ROOT_NAME .. "." .. CASH_NAME, currentCash + reward.Cash)
	dataUtility.server.set(player, CURRENCY_ROOT_NAME .. "." .. XP_NAME, currentXp + reward.XP)
	send_result(player, true, code, reward, nil)
	activeRedemptions[player] = nil
end

------------------//MAIN FUNCTIONS
redeemCode = get_or_create_remote()
redeemCode.OnServerEvent:Connect(redeem_code)

Players.PlayerRemoving:Connect(function(player: Player)
	activeRedemptions[player] = nil
end)

------------------//INIT
