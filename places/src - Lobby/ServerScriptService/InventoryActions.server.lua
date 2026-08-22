------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local PROFILE_REMOTES_FOLDER_NAME: string = "ProfileRemotes"
local EQUIP_REMOTE_NAME: string = "EquipInventory"
local PURCHASE_REMOTE_NAME: string = "PurchaseInventory"
local INVENTORY_ROOT_NAME: string = "Inventory"
local OWNED_ROOT_NAME: string = "Owned"
local EQUIPPED_ROOT_NAME: string = "Equipped"
local CURRENCY_ROOT_NAME: string = "Currency"
local CASH_NAME: string = "Cash"
local PROFILE_ROOT_NAME: string = "Profile"
local LEVEL_NAME: string = "Level"
local DEFAULT_LEVEL: number = 1
local VALID_CATEGORIES: { [string]: boolean } = {
	Livery = true,
	Suit = true,
	Helmets = true,
}

type ItemInfo = {
	Disabled: boolean?,
	Level: number?,
	Price: number?,
	RacingPass: boolean?,
	RobuxShop: boolean?,
}

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataFolder: Folder = modules:WaitForChild("Data") :: Folder
local dataUtility = require(dataFolder:WaitForChild("DataUtility"))
local inventoryData: Folder = dataFolder:WaitForChild("Inventory") :: Folder
local profileRemotes: Folder = ReplicatedStorage:WaitForChild(PROFILE_REMOTES_FOLDER_NAME) :: Folder

------------------//VARIABLES
local equipInventory: RemoteEvent
local purchaseInventory: RemoteEvent

------------------//FUNCTIONS
local function get_or_create_remote(remoteName: string): RemoteEvent
	local existingRemote = profileRemotes:FindFirstChild(remoteName)
	if existingRemote and existingRemote:IsA("RemoteEvent") then
		return existingRemote
	end

	if existingRemote then
		existingRemote:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = remoteName
	remote.Parent = profileRemotes
	return remote
end

local function send_error(remote: RemoteEvent, player: Player): ()
	remote:FireClient(player, "ERROR")
end

local function get_item_info(category: string, itemName: string): ItemInfo?
	local catalogModule = inventoryData:FindFirstChild(category)
	if not catalogModule or not catalogModule:IsA("ModuleScript") then
		return nil
	end

	local success, catalog = pcall(require, catalogModule)
	if not success or type(catalog) ~= "table" or type(catalog.Items) ~= "table" then
		return nil
	end

	local itemInfo = catalog.Items[itemName]
	return if type(itemInfo) == "table" then itemInfo :: ItemInfo else nil
end

local function get_inventory_path(rootName: string, category: string): string
	return INVENTORY_ROOT_NAME .. "." .. rootName .. "." .. category
end

local function contains_item(items: any, itemName: string): boolean
	if type(items) ~= "table" then
		return false
	end

	for _, ownedItemName in items do
		if ownedItemName == itemName then
			return true
		end
	end

	return false
end

local function get_player_level(player: Player): number
	local level = tonumber(dataUtility.server.get(player, PROFILE_ROOT_NAME .. "." .. LEVEL_NAME))
	return math.max(DEFAULT_LEVEL, level or DEFAULT_LEVEL)
end

local function is_valid_item(category: any, itemName: any): boolean
	return type(category) == "string"
		and VALID_CATEGORIES[category] == true
		and type(itemName) == "string"
		and #itemName > 0
		and #itemName <= 100
end

local function handle_equip(player: Player, category: any, itemName: any): ()
	if not is_valid_item(category, itemName) then
		send_error(equipInventory, player)
		return
	end

	local itemInfo = get_item_info(category, itemName)
	local ownedItems = dataUtility.server.get(player, get_inventory_path(OWNED_ROOT_NAME, category))
	if not itemInfo or itemInfo.Disabled or not contains_item(ownedItems, itemName) then
		send_error(equipInventory, player)
		return
	end

	dataUtility.server.set(player, get_inventory_path(EQUIPPED_ROOT_NAME, category), itemName)
	equipInventory:FireClient(player, category, itemName)
end

local function handle_purchase(player: Player, category: any, itemName: any): ()
	if not is_valid_item(category, itemName) then
		send_error(purchaseInventory, player)
		return
	end

	local itemInfo = get_item_info(category, itemName)
	local ownedItems = dataUtility.server.get(player, get_inventory_path(OWNED_ROOT_NAME, category))
	if not itemInfo or itemInfo.Disabled or contains_item(ownedItems, itemName) then
		send_error(purchaseInventory, player)
		return
	end

	if itemInfo.RacingPass or itemInfo.RobuxShop then
		send_error(purchaseInventory, player)
		return
	end

	local requiredLevel = tonumber(itemInfo.Level) or DEFAULT_LEVEL
	if get_player_level(player) < requiredLevel then
		send_error(purchaseInventory, player)
		return
	end

	local price = math.max(0, tonumber(itemInfo.Price) or 0)
	local currentCash = tonumber(dataUtility.server.get(player, CURRENCY_ROOT_NAME .. "." .. CASH_NAME)) or 0
	if currentCash < price then
		send_error(purchaseInventory, player)
		return
	end

	local updatedOwnedItems = table.clone(ownedItems)
	table.insert(updatedOwnedItems, itemName)
	dataUtility.server.set(player, CURRENCY_ROOT_NAME .. "." .. CASH_NAME, currentCash - price)
	dataUtility.server.set(player, get_inventory_path(OWNED_ROOT_NAME, category), updatedOwnedItems)
	purchaseInventory:FireClient(player, category, itemName)
end

------------------//MAIN FUNCTIONS
local function bind_inventory_remotes(): ()
	equipInventory = get_or_create_remote(EQUIP_REMOTE_NAME)
	purchaseInventory = get_or_create_remote(PURCHASE_REMOTE_NAME)
	equipInventory.OnServerEvent:Connect(handle_equip)
	purchaseInventory.OnServerEvent:Connect(handle_purchase)
end

------------------//INIT
bind_inventory_remotes()
