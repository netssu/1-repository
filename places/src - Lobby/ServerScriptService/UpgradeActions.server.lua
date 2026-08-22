------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local PROFILE_REMOTES_FOLDER_NAME: string = "ProfileRemotes"
local UPGRADE_REMOTE_NAME: string = "UpgradeInventory"
local INVENTORY_UPGRADES_PATH: string = "Inventory.Upgrades."
local CASH_PATH: string = "Currency.Cash"
local MAX_UPGRADE_LEVEL: number = 3
local MIN_UPGRADE_NAME_LENGTH: number = 1
local MAX_UPGRADE_NAME_LENGTH: number = 32

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataFolder: Folder = modules:WaitForChild("Data") :: Folder
local dataUtility = require(dataFolder:WaitForChild("DataUtility"))
local upgradeCatalog = require(dataFolder:WaitForChild("Inventory"):WaitForChild("Upgrades"))

------------------//VARIABLES
local upgradeInventory: RemoteEvent
local purchaseLocks: { [number]: boolean } = {}

------------------//FUNCTIONS
local function get_or_create_remote(): RemoteEvent
	local remotesFolder = ReplicatedStorage:FindFirstChild(PROFILE_REMOTES_FOLDER_NAME)
	if not remotesFolder then
		local createdFolder = Instance.new("Folder")
		createdFolder.Name = PROFILE_REMOTES_FOLDER_NAME
		createdFolder.Parent = ReplicatedStorage
		remotesFolder = createdFolder
	end

	local existingRemote = remotesFolder:FindFirstChild(UPGRADE_REMOTE_NAME)
	if existingRemote and existingRemote:IsA("RemoteEvent") then
		return existingRemote
	end

	if existingRemote then
		existingRemote:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = UPGRADE_REMOTE_NAME
	remote.Parent = remotesFolder
	return remote
end

local function send_result(player: Player, success: boolean, upgradeName: string): ()
	upgradeInventory:FireClient(player, success, upgradeName)
end

local function is_valid_upgrade_name(upgradeName: any): boolean
	return type(upgradeName) == "string"
		and #upgradeName >= MIN_UPGRADE_NAME_LENGTH
		and #upgradeName <= MAX_UPGRADE_NAME_LENGTH
		and type(upgradeCatalog[upgradeName]) == "table"
end

local function get_current_level(player: Player, upgradeName: string): number
	local value = tonumber(dataUtility.server.get(player, INVENTORY_UPGRADES_PATH .. upgradeName))
	return math.clamp(value or 0, 0, MAX_UPGRADE_LEVEL)
end

local function handle_upgrade_request(player: Player, upgradeName: any): ()
	if type(upgradeName) ~= "string" then
		return
	end

	if not is_valid_upgrade_name(upgradeName) then
		send_result(player, false, upgradeName)
		return
	end

	if purchaseLocks[player.UserId] then
		return
	end
	purchaseLocks[player.UserId] = true

	local currentLevel = get_current_level(player, upgradeName)
	local nextStep = upgradeCatalog[upgradeName][currentLevel]
	if currentLevel >= MAX_UPGRADE_LEVEL or type(nextStep) ~= "table" then
		send_result(player, false, upgradeName)
		purchaseLocks[player.UserId] = nil
		return
	end

	local price = math.max(0, tonumber(nextStep.Price) or 0)
	local currentCash = tonumber(dataUtility.server.get(player, CASH_PATH)) or 0
	if currentCash < price then
		send_result(player, false, upgradeName)
		purchaseLocks[player.UserId] = nil
		return
	end

	dataUtility.server.set(player, CASH_PATH, currentCash - price)
	dataUtility.server.set(player, INVENTORY_UPGRADES_PATH .. upgradeName, currentLevel + 1)
	send_result(player, true, upgradeName)
	purchaseLocks[player.UserId] = nil
end

------------------//MAIN FUNCTIONS
local function bind_upgrade_remote(): ()
	upgradeInventory = get_or_create_remote()
	upgradeInventory.OnServerEvent:Connect(handle_upgrade_request)
end

------------------//INIT
bind_upgrade_remote()

