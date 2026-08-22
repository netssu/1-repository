------------------//SERVICES
local MarketplaceService: MarketplaceService = game:GetService("MarketplaceService")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local racingPassData = require(modules:WaitForChild("Data"):WaitForChild("RacingPassData"))
local inventoryFolder: Folder = modules:WaitForChild("Data"):WaitForChild("Inventory")
local inventoryCatalogs: { [string]: any } = {
	Suit = require(inventoryFolder:WaitForChild("Suit")),
	Helmets = require(inventoryFolder:WaitForChild("Helmets")),
	Livery = require(inventoryFolder:WaitForChild("Livery")),
}
local profileRemotes: Folder = ReplicatedStorage:WaitForChild("ProfileRemotes")

------------------//CONSTANTS
local ACTION_REMOTE_NAME: string = "RacingPassAction"
local PASS_PATH: string = "Profile.RacingPass"
local LEVEL_PATH: string = PASS_PATH .. ".RacingpassLevel"
local OWNED_PATH: string = PASS_PATH .. ".RacingpassOwned"
local NORMAL_CLAIM_PATH: string = PASS_PATH .. ".NormalClaim"
local PREMIUM_CLAIM_PATH: string = PASS_PATH .. ".PremiumClaim"
local RACE_PASS_XP_PATH: string = "Currency.RacePassXP"
local CASH_PATH: string = "Currency.Cash"
local CLAIM_REQUEST_COOLDOWN: number = 0.25
local PLAYTIME_XP_INTERVAL: number = 60
local RACE_PASS_XP_PER_MINUTE: number = 25
local REWARD_OWNED_PATHS: { [string]: string } = {
	Suit = "Inventory.Owned.Suit",
	Helmets = "Inventory.Owned.Helmets",
	Livery = "Inventory.Owned.Livery",
}

type Reward = racingPassData.Reward
type ProductAction = "RacingPass" | "SkipOne" | "SkipFive" | "CompleteSkip"

------------------//VARIABLES
local racingPassAction: RemoteEvent
local activeRequests: { [number]: boolean } = {}
local lastRequestAt: { [number]: number } = {}

------------------//FUNCTIONS
local function get_or_create_remote(): RemoteEvent
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

local function get_level(player: Player): number
	return math.clamp(
		tonumber(dataUtility.server.get(player, LEVEL_PATH)) or racingPassData.MIN_LEVEL,
		racingPassData.MIN_LEVEL,
		racingPassData.MAX_LEVEL
	)
end

local function send_result(player: Player, success: boolean, action: string, value: any?, extra: any?): ()
	racingPassAction:FireClient(player, success, action, value, extra)
end

local function get_reward(passType: string, level: number): Reward?
	local rewards = racingPassData.REWARDS[passType]
	local reward = rewards and rewards[level]
	return if type(reward) == "table" then reward :: Reward else nil
end

local function get_claim_path(passType: string): string
	return if passType == "Premium" then PREMIUM_CLAIM_PATH else NORMAL_CLAIM_PATH
end

local function contains_item(items: any, itemName: string): boolean
	if type(items) ~= "table" then
		return false
	end

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
	return catalog ~= nil and type(catalog.Items) == "table" and type(catalog.Items[reward.Item]) == "table"
end

local function add_reward_to_data(data: any, reward: Reward): boolean
	if type(data) ~= "table" then
		return false
	end

	if reward.Type == "Cash" then
		local amount = tonumber(reward.Amount)
		local currency = data.Currency
		if not amount or amount <= 0 or type(currency) ~= "table" then
			return false
		end

		currency.Cash = (tonumber(currency.Cash) or 0) + amount
		return true
	end

	local ownedPath = REWARD_OWNED_PATHS[reward.Type]
	if not ownedPath or not is_known_inventory_item(reward) then
		return false
	end

	local inventory = data.Inventory
	local owned = type(inventory) == "table" and inventory.Owned
	local ownedItems = type(owned) == "table" and owned[reward.Type]
	if type(ownedItems) ~= "table" then
		return false
	end
	if contains_item(ownedItems, reward.Item :: string) then
		return true
	end

	table.insert(ownedItems, reward.Item :: string)
	return true
end

local function claim_reward(player: Player, rawLevel: any, rawPassType: any): ()
	local level = tonumber(rawLevel)
	local passType = if rawPassType == "Premium" then "Premium" elseif rawPassType == "Normal" then "Normal" else nil
	if not level or not passType then
		send_result(player, false, "Claim", "INVALID_REQUEST", nil)
		return
	end

	level = math.floor(level)
	if level < racingPassData.MIN_LEVEL or level > racingPassData.MAX_LEVEL then
		send_result(player, false, "Claim", "INVALID_LEVEL", nil)
		return
	end

	local resultCode: string = "PROFILE_NOT_READY"
	local didUpdate = dataUtility.server.update(player, function(data: any): { [string]: any }?
		local profile = type(data) == "table" and data.Profile
		local racingPass = type(profile) == "table" and profile.RacingPass
		if type(racingPass) ~= "table" then
			return nil
		end

		if passType == "Premium" and racingPass.RacingpassOwned ~= true then
			resultCode = "PREMIUM_LOCKED"
			return nil
		end

		local currentLevel = math.clamp(
			tonumber(racingPass.RacingpassLevel) or racingPassData.MIN_LEVEL,
			racingPassData.MIN_LEVEL,
			racingPassData.MAX_LEVEL
		)
		if currentLevel < level then
			resultCode = "LEVEL_LOCKED"
			return nil
		end

		local claimField = if passType == "Premium" then "PremiumClaim" else "NormalClaim"
		local claims = racingPass[claimField]
		if type(claims) ~= "table" then
			claims = {}
			racingPass[claimField] = claims
		end

		local levelKey = tostring(level)
		if claims[levelKey] == true then
			resultCode = "ALREADY_CLAIMED"
			return nil
		end

		local reward = get_reward(passType, level)
		if not reward or not add_reward_to_data(data, reward) then
			resultCode = "REWARD_UNAVAILABLE"
			return nil
		end

		claims[levelKey] = true
		resultCode = "SUCCESS"
		local changes: { [string]: any } = {
			[get_claim_path(passType)] = claims,
		}
		if reward.Type == "Cash" then
			changes[CASH_PATH] = data.Currency.Cash
		else
			changes[REWARD_OWNED_PATHS[reward.Type]] = data.Inventory.Owned[reward.Type]
		end
		return changes
	end)

	if not didUpdate and resultCode == "SUCCESS" then
		resultCode = "PROFILE_NOT_READY"
	end
	if resultCode == "SUCCESS" then
		send_result(player, true, "Claim", level, passType)
	else
		send_result(player, false, "Claim", resultCode, level)
	end
end

local function get_product_action(productId: any): ProductAction?
	if type(productId) ~= "number" then
		return nil
	end

	for action, configuredProductId in racingPassData.PRODUCTS do
		if configuredProductId == productId then
			return action :: ProductAction
		end
	end

	return nil
end

local function apply_purchase(player: Player, action: ProductAction, purchaseId: string): (boolean, ProductAction?)
	local processedAction: ProductAction?
	local didUpdate = dataUtility.server.update(player, function(data: any): { [string]: any }?
		local profile = type(data) == "table" and data.Profile
		local racingPass = type(profile) == "table" and profile.RacingPass
		if type(racingPass) ~= "table" then
			return nil
		end

		local processedReceipts = racingPass.ProcessedReceipts
		if type(processedReceipts) ~= "table" then
			processedReceipts = {}
			racingPass.ProcessedReceipts = processedReceipts
		end

		local previousAction = processedReceipts[purchaseId]
		if type(previousAction) == "string" then
			processedAction = previousAction :: ProductAction
			return {}
		end

		if action == "RacingPass" then
			racingPass.RacingpassOwned = true
		else
			local skipAmount = if action == "SkipOne" then 1 elseif action == "SkipFive" then 5 else racingPassData.MAX_LEVEL
			local currentLevel = math.clamp(
				tonumber(racingPass.RacingpassLevel) or racingPassData.MIN_LEVEL,
				racingPassData.MIN_LEVEL,
				racingPassData.MAX_LEVEL
			)
			racingPass.RacingpassLevel = math.min(racingPassData.MAX_LEVEL, currentLevel + skipAmount)
		end

		processedReceipts[purchaseId] = action
		processedAction = action
		if action == "RacingPass" then
			return {
				[OWNED_PATH] = racingPass.RacingpassOwned,
			}
		end

		return {
			[LEVEL_PATH] = racingPass.RacingpassLevel,
		}
	end)

	if not didUpdate or not processedAction then
		return false, nil
	end
	return true, processedAction
end

local function process_receipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local action = get_product_action(receiptInfo.ProductId)
	local purchaseId = tostring(receiptInfo.PurchaseId or "")
	if not action or purchaseId == "" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local didApply, appliedAction = apply_purchase(player, action, purchaseId)
	if not didApply or not appliedAction then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	send_result(player, true, "Purchase", appliedAction, nil)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function add_racing_pass_xp(player: Player, amount: number): ()
	local level = get_level(player)
	if level >= racingPassData.MAX_LEVEL then
		return
	end

	local currentXp = math.max(0, tonumber(dataUtility.server.get(player, RACE_PASS_XP_PATH)) or 0) + amount
	while level < racingPassData.MAX_LEVEL do
		local requiredXp = racingPassData.LEVEL_REQUIREMENTS[level]
		if not requiredXp or currentXp < requiredXp then
			break
		end
		currentXp -= requiredXp
		level += 1
	end

	dataUtility.server.set(player, LEVEL_PATH, level)
	dataUtility.server.set(player, RACE_PASS_XP_PATH, currentXp)
end

local function handle_action(player: Player, action: any, value: any, extra: any): ()
	local now = os.clock()
	local lastRequest = lastRequestAt[player.UserId] or 0
	if activeRequests[player.UserId] or now - lastRequest < CLAIM_REQUEST_COOLDOWN then
		return
	end

	lastRequestAt[player.UserId] = now
	activeRequests[player.UserId] = true
	if action == "Claim" then
		claim_reward(player, value, extra)
	end
	activeRequests[player.UserId] = nil
end

------------------//MAIN FUNCTIONS
racingPassAction = get_or_create_remote()
racingPassAction.OnServerEvent:Connect(handle_action)
MarketplaceService.ProcessReceipt = process_receipt

task.spawn(function()
	while true do
		task.wait(PLAYTIME_XP_INTERVAL)
		for _, player in Players:GetPlayers() do
			add_racing_pass_xp(player, RACE_PASS_XP_PER_MINUTE)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	activeRequests[player.UserId] = nil
	lastRequestAt[player.UserId] = nil
end)

------------------//INIT
