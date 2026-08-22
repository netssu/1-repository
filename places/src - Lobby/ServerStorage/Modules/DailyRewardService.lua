------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataModules: Folder = modules:WaitForChild("Data")
local dataUtility = require(dataModules:WaitForChild("DataUtility"))
local dailyRewardData = require(dataModules:WaitForChild("DailyRewardData"))
local inventoryModules: Folder = dataModules:WaitForChild("Inventory")
local inventoryCatalogs: { [string]: any } = {
	Helmets = require(inventoryModules:WaitForChild("Helmets")),
	Livery = require(inventoryModules:WaitForChild("Livery")),
}

------------------//CONSTANTS
local PROFILE_REMOTES_FOLDER_NAME: string = "ProfileRemotes"
local ACTION_REMOTE_NAME: string = "DailyRewardAction"
local DAILY_REWARD_PATH: string = "Profile.DailyReward"
local CASH_PATH: string = "Currency.Cash"
local XP_PATH: string = "Currency.XP"
local RACE_PASS_XP_PATH: string = "Currency.RacePassXP"
local OWNED_PATHS: { [string]: string } = {
	Helmets = "Inventory.Owned.Helmets",
	Livery = "Inventory.Owned.Livery",
}
local CLAIM_COOLDOWN_SECONDS: number = 0.25

type Reward = dailyRewardData.Reward

------------------//VARIABLES
local dailyRewardAction: RemoteEvent
local activeRequests: { [Player]: boolean } = {}
local lastRequestAt: { [number]: number } = {}
local isEnabled: boolean = false

------------------//FUNCTIONS
local function get_profile(data: any): { [string]: any }?
	if type(data) ~= "table" or type(data.Profile) ~= "table" then
		return nil
	end

	return data.Profile
end

local function get_or_create_remote(): RemoteEvent
	local profileRemotes = ReplicatedStorage:FindFirstChild(PROFILE_REMOTES_FOLDER_NAME)
	if not profileRemotes then
		profileRemotes = Instance.new("Folder")
		profileRemotes.Name = PROFILE_REMOTES_FOLDER_NAME
		profileRemotes.Parent = ReplicatedStorage
	end

	local existingRemote = profileRemotes:FindFirstChild(ACTION_REMOTE_NAME)
	if existingRemote and existingRemote:IsA("RemoteEvent") then
		return existingRemote
	end
	if existingRemote then
		existingRemote:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = ACTION_REMOTE_NAME
	remote.Parent = profileRemotes
	return remote
end

local function send_result(
	player: Player,
	isSuccessful: boolean,
	code: string,
	rewardId: number?,
	reward: Reward?
): ()
	dailyRewardAction:FireClient(player, isSuccessful, code, rewardId, reward)
end

local function contains_item(items: { string }, itemName: string): boolean
	for _, ownedItem in items do
		if ownedItem == itemName then
			return true
		end
	end

	return false
end

local function is_known_inventory_item(reward: Reward): boolean
	if type(reward.Item) ~= "string" then
		return false
	end

	local catalog = inventoryCatalogs[reward.Type]
	return catalog ~= nil
		and type(catalog.Items) == "table"
		and type(catalog.Items[reward.Item]) == "table"
end

local function add_reward_to_data(data: any, reward: Reward): (boolean, string?)
	if type(data) ~= "table" or type(data.Currency) ~= "table" then
		return false, nil
	end

	local amount = tonumber(reward.Amount) or 0
	if reward.Type == "Cash" then
		if amount <= 0 then
			return false, nil
		end

		data.Currency.Cash = (tonumber(data.Currency.Cash) or 0) + amount
		return true, CASH_PATH
	end
	if reward.Type == "XP" then
		if amount <= 0 then
			return false, nil
		end

		data.Currency.XP = (tonumber(data.Currency.XP) or 0) + amount
		return true, XP_PATH
	end
	if reward.Type == "RacePassXP" then
		if amount <= 0 then
			return false, nil
		end

		data.Currency.RacePassXP = (tonumber(data.Currency.RacePassXP) or 0) + amount
		return true, RACE_PASS_XP_PATH
	end
	if not OWNED_PATHS[reward.Type] or not is_known_inventory_item(reward) then
		return false, nil
	end

	local inventory = data.Inventory
	local owned = type(inventory) == "table" and inventory.Owned
	local ownedItems = type(owned) == "table" and owned[reward.Type]
	if type(ownedItems) ~= "table" then
		return false, nil
	end

	if contains_item(ownedItems, reward.Item :: string) then
		local duplicateCash = tonumber(reward.DuplicateCash) or 0
		if duplicateCash <= 0 then
			return false, nil
		end

		data.Currency.Cash = (tonumber(data.Currency.Cash) or 0) + duplicateCash
		return true, CASH_PATH
	end

	table.insert(ownedItems, reward.Item :: string)
	return true, OWNED_PATHS[reward.Type]
end

local function refresh_player_data(player: Player): boolean
	local didUpdate = dataUtility.server.update(player, function(data: any): { [string]: any }?
		local profile = get_profile(data)
		if not profile then
			return nil
		end

		local state = dailyRewardData.normalize_state(profile.DailyReward, os.time())
		profile.DailyReward = state
		return {
			[DAILY_REWARD_PATH] = state,
		}
	end)
	return didUpdate
end

local function claim_reward(player: Player, rawRewardId: any): ()
	local rewardId = tonumber(rawRewardId)
	if not rewardId then
		send_result(player, false, "INVALID_REWARD", nil, nil)
		return
	end
	rewardId = math.floor(rewardId)

	local reward = dailyRewardData.get_reward(rewardId)
	if not reward then
		send_result(player, false, "INVALID_REWARD", rewardId, nil)
		return
	end

	local resultCode: string = "PROFILE_NOT_READY"
	local didUpdate = dataUtility.server.update(player, function(data: any): { [string]: any }?
		local profile = get_profile(data)
		if not profile then
			return nil
		end

		local state = dailyRewardData.normalize_state(profile.DailyReward, os.time())
		if not dailyRewardData.can_claim(state, rewardId, os.time()) then
			profile.DailyReward = state
			resultCode = if dailyRewardData.is_claimed(state, rewardId) then "ALREADY_CLAIMED" else "REWARD_LOCKED"
			return {
				[DAILY_REWARD_PATH] = state,
			}
		end

		local granted, changedPath = add_reward_to_data(data, reward)
		if not granted then
			resultCode = "REWARD_UNAVAILABLE"
			return nil
		end

		state.Claimed[tostring(rewardId)] = true
		profile.DailyReward = state
		resultCode = "SUCCESS"
		local changes: { [string]: any } = {
			[DAILY_REWARD_PATH] = state,
		}
		if changedPath == CASH_PATH then
			changes[CASH_PATH] = data.Currency.Cash
		elseif changedPath == XP_PATH then
			changes[XP_PATH] = data.Currency.XP
		elseif changedPath == RACE_PASS_XP_PATH then
			changes[RACE_PASS_XP_PATH] = data.Currency.RacePassXP
		else
			changes[changedPath :: string] = data.Inventory.Owned[reward.Type]
		end
		return changes
	end)

	if not didUpdate and resultCode == "SUCCESS" then
		resultCode = "PROFILE_NOT_READY"
	end
	if resultCode == "SUCCESS" then
		send_result(player, true, resultCode, rewardId, reward)
	else
		send_result(player, false, resultCode, rewardId, nil)
	end
end

local function handle_request(player: Player, action: any, value: any): ()
	local now = os.clock()
	local lastRequest = lastRequestAt[player.UserId] or 0
	if activeRequests[player] or now - lastRequest < CLAIM_COOLDOWN_SECONDS then
		return
	end

	lastRequestAt[player.UserId] = now
	activeRequests[player] = true
	if action == "Sync" then
		refresh_player_data(player)
	elseif action == "Claim" then
		claim_reward(player, value)
	end
	activeRequests[player] = nil
end

local function bind_player(player: Player): ()
	task.spawn(function()
		dataUtility.server.get(player, "Profile")
		if player.Parent then
			refresh_player_data(player)
		end
	end)
end

local function unbind_player(player: Player): ()
	activeRequests[player] = nil
	lastRequestAt[player.UserId] = nil
end

------------------//MAIN FUNCTIONS
local dailyRewardService = {}

function dailyRewardService.enable(): ()
	if isEnabled then
		return
	end

	dailyRewardAction = get_or_create_remote()
	dailyRewardAction.OnServerEvent:Connect(handle_request)
	for _, player in Players:GetPlayers() do
		bind_player(player)
	end
	Players.PlayerAdded:Connect(bind_player)
	Players.PlayerRemoving:Connect(unbind_player)
	isEnabled = true
end

------------------//INIT
return dailyRewardService
