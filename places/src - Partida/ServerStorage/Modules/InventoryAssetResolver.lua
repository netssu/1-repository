------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local ASSETS_FOLDER_NAME: string = "Assets"
local INVENTORY_ASSETS_FOLDER_NAME: string = "InventoryAssets"
local ITEMS_FOLDER_NAME: string = "Items"
local DEFAULT_ITEM_NAME: string = "Default"

local CATEGORY_FOLDER_NAMES: { [string]: string } = {
	Livery = "Livery",
	Suit = "Suits",
	Helmets = "Helmets",
}

local ITEM_ALIASES: { [string]: { [string]: string } } = {
	Suit = {
		["Porche Motorsport"] = "Porsche Motorsport",
	},
}

------------------//DEPENDENCIES
local dataModules: Folder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data")
local inventoryData: { [string]: any } = {
	Livery = require(dataModules:WaitForChild("Inventory"):WaitForChild("Livery")),
	Suit = require(dataModules:WaitForChild("Inventory"):WaitForChild("Suit")),
	Helmets = require(dataModules:WaitForChild("Inventory"):WaitForChild("Helmets")),
}

------------------//VARIABLES
local itemsFolder: Folder = ReplicatedStorage
	:WaitForChild(ASSETS_FOLDER_NAME)
	:WaitForChild(INVENTORY_ASSETS_FOLDER_NAME)
	:WaitForChild(ITEMS_FOLDER_NAME) :: Folder

------------------//FUNCTIONS
local function get_item_folder(category: string): Folder?
	local folderName = CATEGORY_FOLDER_NAMES[category]
	if not folderName then
		return nil
	end

	local itemFolder = itemsFolder:FindFirstChild(folderName)
	if itemFolder and itemFolder:IsA("Folder") then
		return itemFolder
	end

	return nil
end

local function get_resolved_item_name(category: string, requestedName: any): string
	local itemName = if type(requestedName) == "string" and requestedName ~= "" then requestedName else DEFAULT_ITEM_NAME
	local aliases = ITEM_ALIASES[category]
	if aliases and aliases[itemName] then
		itemName = aliases[itemName]
	end

	local catalog = inventoryData[category]
	if type(catalog) == "table" and type(catalog.Items) == "table" and catalog.Items[itemName] == nil then
		itemName = DEFAULT_ITEM_NAME
	end

	local itemFolder = get_item_folder(category)
	if not itemFolder or not itemFolder:FindFirstChild(itemName) then
		itemName = DEFAULT_ITEM_NAME
	end

	return itemName
end

local function get_item_template(category: string, requestedName: any): Instance?
	local itemFolder = get_item_folder(category)
	if not itemFolder then
		return nil
	end

	local resolvedName = get_resolved_item_name(category, requestedName)
	return itemFolder:FindFirstChild(resolvedName) or itemFolder:FindFirstChild(DEFAULT_ITEM_NAME)
end

------------------//MAIN FUNCTIONS
local inventoryAssetResolver = {}

function inventoryAssetResolver.get_resolved_item_name(category: string, requestedName: any): string
	return get_resolved_item_name(category, requestedName)
end

function inventoryAssetResolver.get_item_template(category: string, requestedName: any): Instance?
	return get_item_template(category, requestedName)
end

function inventoryAssetResolver.clone_item_template(category: string, requestedName: any): Instance?
	local template = get_item_template(category, requestedName)
	return if template then template:Clone() else nil
end

------------------//INIT
return inventoryAssetResolver

