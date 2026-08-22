------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local MAIN_UI_NAME: string = "MainUI"
local CANVAS_NAME: string = "Canvas"
local INVENTORY_CONTAINER_NAME: string = "InventoryContainer"
local SCROLLING_FRAME_NAME: string = "ScrollingFrame"
local TEMPLATE_NAME: string = "Template"
local PROFILE_REMOTES_FOLDER_NAME: string = "ProfileRemotes"
local EQUIP_REMOTE_NAME: string = "EquipInventory"
local PURCHASE_REMOTE_NAME: string = "PurchaseInventory"
local LOCKED_NAME: string = "Locked"
local LEVEL_NAME: string = "Level"
local PRICE_NAME: string = "Price"
local LOCK_NAME: string = "Lock"
local BUY_PANEL_NAME: string = "Buy"
local BUY_BUTTON_NAME: string = "BuyBttn"
local BUY_LABEL_NAME: string = "Buy"
local ROBUX_LOCK_IMAGE: string = "rbxassetid://78016858527627"
local GROUP_OWNED: number = 0
local GROUP_CASH: number = 2
local GROUP_RACING_PASS: number = 3
local GROUP_ROBUX: number = 4
local GROUP_ITEM_MULTIPLIER: number = 1000
local DEFAULT_LEVEL: number = 1

type PageConfig = {
	category: string,
	assetFolderNames: { string },
}

type ItemInfo = {
	Disabled: boolean?,
	Level: number?,
	Price: number?,
	RacingPass: boolean?,
	RobuxShop: boolean?,
}

type Catalog = {
	Items: { [string]: ItemInfo },
}

type DataConnection = {
	disconnect: (self: DataConnection) -> (),
}

local PAGE_CONFIGS: { [string]: PageConfig } = {
	Car = {
		category = "Livery",
		assetFolderNames = { "Livery" },
	},
	Avatar = {
		category = "Suit",
		assetFolderNames = { "Suits", "Suit" },
	},
	Helmets = {
		category = "Helmets",
		assetFolderNames = { "Helmets" },
	},
}

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataFolder: Folder = modules:WaitForChild("Data") :: Folder
local inventoryData: Folder = dataFolder:WaitForChild("Inventory") :: Folder
local dataUtility = require(dataFolder:WaitForChild("DataUtility"))
local interfaceController = require(modules:WaitForChild("Interface"):WaitForChild("InterfaceController"))
local inventoryAssetRenderer = require(modules:WaitForChild("Interface"):WaitForChild("InventoryAssetRenderer"))
local inventoryCardEffects = require(modules:WaitForChild("Interface"):WaitForChild("InventoryCardEffects"))

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local catalogs: { [string]: Catalog } = {}
local dataConnections: { DataConnection } = {}
local navigationConnections: { RBXScriptConnection } = {}
local actionConnections: { RBXScriptConnection } = {}
local slotConnections: { [string]: { RBXScriptConnection } } = {}
local selectedItemNames: { [string]: string } = {}
local equipInventory: RemoteEvent?
local purchaseInventory: RemoteEvent?
local isEnabled: boolean = false

------------------//FUNCTIONS
local function get_canvas(): Frame?
	local mainUi = playerGui:FindFirstChild(MAIN_UI_NAME)
	if not mainUi or not mainUi:IsA("ScreenGui") then
		return nil
	end

	local canvas = mainUi:FindFirstChild(CANVAS_NAME)
	if canvas and canvas:IsA("Frame") then
		return canvas
	end

	return nil
end

local function get_page_canvas(pageName: string): GuiObject?
	local canvas = get_canvas()
	local page = canvas and canvas:FindFirstChild(pageName)
	if page and page:IsA("GuiObject") then
		return page
	end

	return nil
end

local function get_catalog(category: string): Catalog?
	if catalogs[category] then
		return catalogs[category]
	end

	local catalogModule = inventoryData:FindFirstChild(category)
	if not catalogModule or not catalogModule:IsA("ModuleScript") then
		warn(("[InventorySlotController] Catalog not found: %s"):format(category))
		return nil
	end

	local success, catalog = pcall(require, catalogModule)
	if not success or type(catalog) ~= "table" or type(catalog.Items) ~= "table" then
		warn(("[InventorySlotController] Failed to load catalog: %s"):format(category))
		return nil
	end

	local typedCatalog = catalog :: Catalog
	catalogs[category] = typedCatalog
	return typedCatalog
end

local function get_owned_set(category: string): { [string]: boolean }
	local ownedItems = dataUtility.client.get("Inventory.Owned." .. category)
	local ownedSet: { [string]: boolean } = {}
	if type(ownedItems) ~= "table" then
		return ownedSet
	end

	for _, itemName in ownedItems do
		if type(itemName) == "string" then
			ownedSet[itemName] = true
		end
	end

	return ownedSet
end

local function get_equipped_name(category: string): string?
	local equippedName = dataUtility.client.get("Inventory.Equipped." .. category)
	return if type(equippedName) == "string" then equippedName else nil
end

local function get_player_level(): number
	local level = tonumber(dataUtility.client.get("Profile.Level"))
	return math.max(DEFAULT_LEVEL, level or DEFAULT_LEVEL)
end

local function bind_action_remotes(): ()
	local remotesFolder = ReplicatedStorage:FindFirstChild(PROFILE_REMOTES_FOLDER_NAME)
	local equipRemote = remotesFolder and remotesFolder:FindFirstChild(EQUIP_REMOTE_NAME)
	local purchaseRemote = remotesFolder and remotesFolder:FindFirstChild(PURCHASE_REMOTE_NAME)
	equipInventory = if equipRemote and equipRemote:IsA("RemoteEvent") then equipRemote else nil
	purchaseInventory = if purchaseRemote and purchaseRemote:IsA("RemoteEvent") then purchaseRemote else nil

	if purchaseInventory then
		table.insert(actionConnections, purchaseInventory.OnClientEvent:Connect(function(category: string, itemName: string?)
			if category == "ERROR" or not itemName or not equipInventory then
				return
			end

			equipInventory:FireServer(category, itemName)
		end))
	end
end

local function get_layout_group(itemInfo: ItemInfo, isOwned: boolean, isEquipped: boolean): number
	if isOwned then
		return GROUP_OWNED + if isEquipped then 0 else 1
	end
	if itemInfo.RobuxShop then
		return GROUP_ROBUX
	end
	if itemInfo.RacingPass then
		return GROUP_RACING_PASS
	end

	return GROUP_CASH
end

local function set_text_visibility(instance: Instance?, isVisible: boolean): ()
	if instance and instance:IsA("GuiObject") then
		instance.Visible = isVisible
	end
end

local function configure_locked(button: GuiButton, itemInfo: ItemInfo, playerLevel: number): boolean
	local locked = button:FindFirstChild(LOCKED_NAME)
	if not locked or not locked:IsA("GuiObject") then
		return false
	end

	locked.Visible = true
	local lock = locked:FindFirstChild(LOCK_NAME)
	local level = locked:FindFirstChild(LEVEL_NAME)
	local price = locked:FindFirstChild(PRICE_NAME)
	set_text_visibility(level, false)
	set_text_visibility(price, false)
	set_text_visibility(lock, false)

	if itemInfo.RobuxShop then
		if lock and lock:IsA("ImageLabel") then
			lock.Image = ROBUX_LOCK_IMAGE
		end
		set_text_visibility(lock, true)
		button:SetAttribute("InventoryGroup", "Robux")
		return true
	end

	if itemInfo.RacingPass then
		set_text_visibility(lock, true)
		button:SetAttribute("InventoryGroup", "RacingPass")
		return true
	end

	local requiredLevel = tonumber(itemInfo.Level) or DEFAULT_LEVEL
	if playerLevel >= requiredLevel then
		if price and price:IsA("TextLabel") then
			price.Text = "$" .. tostring(itemInfo.Price or 0)
		end
		set_text_visibility(price, true)
	else
		if level and level:IsA("TextLabel") then
			level.Text = "Level: " .. tostring(requiredLevel)
		end
		set_text_visibility(level, true)
	end

	button:SetAttribute("InventoryGroup", "Cash")
	return true
end

local function update_selected_label(pageCanvas: GuiObject, selectedName: string?): ()
	local selected = pageCanvas:FindFirstChild("Selected")
	local label = selected and selected:FindFirstChildWhichIsA("TextLabel", true)
	if label and selectedName then
		label.Text = selectedName
	end
end

local function update_buy_button(pageCanvas: GuiObject, itemInfo: ItemInfo?, isOwned: boolean, playerLevel: number): ()
	local buyPanel = pageCanvas:FindFirstChild(BUY_PANEL_NAME)
	local buyButton = buyPanel and buyPanel:FindFirstChild(BUY_BUTTON_NAME)
	local buyLabel = buyPanel and buyPanel:FindFirstChild(BUY_LABEL_NAME)
	if not buyButton or not buyButton:IsA("GuiButton") then
		return
	end

	if not itemInfo then
		buyButton.Active = false
		buyButton.AutoButtonColor = false
		if buyLabel and buyLabel:IsA("TextLabel") then
			buyLabel.Text = "BUY"
		end
		return
	end

	local isCashItem = not itemInfo.RobuxShop and not itemInfo.RacingPass
	local requiredLevel = tonumber(itemInfo.Level) or DEFAULT_LEVEL
	local canPurchase = isCashItem and not isOwned and not itemInfo.Disabled and playerLevel >= requiredLevel

	buyButton.Active = canPurchase == true
	buyButton.AutoButtonColor = canPurchase == true
	if buyLabel and buyLabel:IsA("TextLabel") then
		buyLabel.Text = if isCashItem and not isOwned
			then "BUY $" .. tostring(itemInfo.Price or 0)
			else "BUY"
	end
end

local function set_selected_item(pageName: string, pageCanvas: GuiObject, itemName: string): ()
	selectedItemNames[pageName] = itemName
	update_selected_label(pageCanvas, itemName)
end

local function handle_slot_activation(
	button: GuiButton,
	pageName: string,
	pageCanvas: GuiObject,
	pageConfig: PageConfig,
	itemName: string,
	itemInfo: ItemInfo,
	isOwned: boolean,
	playerLevel: number
): ()
	set_selected_item(pageName, pageCanvas, itemName)
	update_buy_button(pageCanvas, itemInfo, isOwned, playerLevel)

	if itemInfo.RobuxShop or itemInfo.RacingPass then
		interfaceController.navigate_to("Items", pageName)
		return
	end

	if isOwned then
		if equipInventory then
			equipInventory:FireServer(pageConfig.category, itemName)
		end
		return
	end

	if itemInfo.Disabled or playerLevel < (tonumber(itemInfo.Level) or DEFAULT_LEVEL) then
		return
	end

	button:SetAttribute("InventoryAction", "Buy")
end

local function configure_slot(
	button: GuiButton,
	pageName: string,
	pageCanvas: GuiObject,
	pageConfig: PageConfig,
	itemName: string,
	itemInfo: ItemInfo,
	itemRank: number,
	ownedSet: { [string]: boolean },
	equippedName: string?,
	playerLevel: number
): ()
	local isOwned = ownedSet[itemName] == true
	local isEquipped = equippedName == itemName
	button:SetAttribute("InventoryCategory", pageConfig.category)
	button:SetAttribute("InventoryOwned", isOwned)
	button:SetAttribute("InventoryRobux", itemInfo.RobuxShop == true)
	button.LayoutOrder = get_layout_group(itemInfo, isOwned, isEquipped) * GROUP_ITEM_MULTIPLIER + itemRank
	button:SetAttribute(
		"InventoryAction",
		if isEquipped
			then "Equipped"
			elseif isOwned
			then "Equip"
			elseif itemInfo.RobuxShop or itemInfo.RacingPass
			then "Shop"
			elseif playerLevel >= (tonumber(itemInfo.Level) or DEFAULT_LEVEL)
			then "Buy"
			else "Locked"
	)

	local locked = button:FindFirstChild(LOCKED_NAME)
	if isOwned then
		set_text_visibility(locked, false)
		button:SetAttribute("InventoryGroup", "Owned")
	else
		configure_locked(button, itemInfo, playerLevel)
	end

	local viewport = button:FindFirstChildWhichIsA("ViewportFrame", true)
	if viewport then
		local rendered = inventoryAssetRenderer.render(viewport, pageConfig, itemName)
		button:SetAttribute("InventoryRendered", rendered)
	end

	for _, connection in inventoryCardEffects.bind(button) do
		table.insert(slotConnections[pageName], connection)
	end
	table.insert(slotConnections[pageName], button.Activated:Connect(function()
		handle_slot_activation(button, pageName, pageCanvas, pageConfig, itemName, itemInfo, isOwned, playerLevel)
	end))
end

local function disconnect_slot_connections(pageName: string?): ()
	if pageName then
		local pageConnections = slotConnections[pageName]
		if pageConnections then
			for _, connection in pageConnections do
				connection:Disconnect()
			end
		end
		slotConnections[pageName] = nil
		return
	end

	for _, pageConnections in slotConnections do
		for _, connection in pageConnections do
			connection:Disconnect()
		end
	end
	slotConnections = {}
end

local function get_page_children(pageCanvas: GuiObject): (ScrollingFrame?, GuiButton?)
	local inventoryContainer = pageCanvas:FindFirstChild(INVENTORY_CONTAINER_NAME)
	local scrollingFrame = inventoryContainer and inventoryContainer:FindFirstChild(SCROLLING_FRAME_NAME)
	if not scrollingFrame or not scrollingFrame:IsA("ScrollingFrame") then
		return nil, nil
	end

	local template = scrollingFrame:FindFirstChild(TEMPLATE_NAME)
	if not template or not template:IsA("GuiButton") then
		return scrollingFrame, nil
	end

	return scrollingFrame, template
end

local function bind_buy_button(
	pageName: string,
	pageCanvas: GuiObject,
	pageConfig: PageConfig,
	pageSlotConnections: { RBXScriptConnection }
): ()
	local buyPanel = pageCanvas:FindFirstChild(BUY_PANEL_NAME)
	local buyButton = buyPanel and buyPanel:FindFirstChild(BUY_BUTTON_NAME)
	if not buyButton or not buyButton:IsA("GuiButton") then
		return
	end

	table.insert(pageSlotConnections, buyButton.Activated:Connect(function()
		local itemName = selectedItemNames[pageName]
		local catalog = get_catalog(pageConfig.category)
		local itemInfo = catalog and catalog.Items[itemName or ""]
		if not itemName or not itemInfo or itemInfo.Disabled then
			return
		end

		if itemInfo.RobuxShop or itemInfo.RacingPass then
			interfaceController.navigate_to("Items", pageName)
			return
		end

		local ownedSet = get_owned_set(pageConfig.category)
		update_buy_button(pageCanvas, itemInfo, ownedSet[itemName] == true, get_player_level())
		if ownedSet[itemName] then
			if equipInventory then
				equipInventory:FireServer(pageConfig.category, itemName)
			end
			return
		end

		if get_player_level() < (tonumber(itemInfo.Level) or DEFAULT_LEVEL) then
			return
		end

		if purchaseInventory then
			purchaseInventory:FireServer(pageConfig.category, itemName)
		end
	end))
end

local function compare_item_names(
	firstName: string,
	secondName: string,
	items: { [string]: ItemInfo },
	ownedSet: { [string]: boolean },
	equippedName: string?
): boolean
	local firstInfo = items[firstName]
	local secondInfo = items[secondName]
	local firstOwned = ownedSet[firstName] == true
	local secondOwned = ownedSet[secondName] == true
	local firstEquipped = equippedName == firstName
	local secondEquipped = equippedName == secondName
	local firstGroup = get_layout_group(firstInfo, firstOwned, firstEquipped)
	local secondGroup = get_layout_group(secondInfo, secondOwned, secondEquipped)

	if firstGroup ~= secondGroup then
		return firstGroup < secondGroup
	end

	local firstLevel = tonumber(firstInfo.Level) or DEFAULT_LEVEL
	local secondLevel = tonumber(secondInfo.Level) or DEFAULT_LEVEL
	if firstLevel ~= secondLevel then
		return firstLevel < secondLevel
	end

	local firstPrice = tonumber(firstInfo.Price) or 0
	local secondPrice = tonumber(secondInfo.Price) or 0
	if firstPrice ~= secondPrice then
		return firstPrice < secondPrice
	end

	return string.lower(firstName) < string.lower(secondName)
end

local function load_page(pageName: string): ()
	local pageConfig = PAGE_CONFIGS[pageName]
	local pageCanvas = get_page_canvas(pageName)
	if not pageConfig or not pageCanvas then
		return
	end

	local scrollingFrame, template = get_page_children(pageCanvas)
	if not scrollingFrame or not template then
		warn(("[InventorySlotController] Inventory template not found: %s"):format(pageName))
		return
	end

	template.Visible = false
	local layout = scrollingFrame:FindFirstChildWhichIsA("UIGridLayout") or scrollingFrame:FindFirstChildWhichIsA("UIListLayout")
	if layout then
		layout.SortOrder = Enum.SortOrder.LayoutOrder
	end

	for _, child in scrollingFrame:GetChildren() do
		if child:GetAttribute("InventorySlot") == true then
			child:Destroy()
		end
	end
	disconnect_slot_connections(pageName)

	local catalog = get_catalog(pageConfig.category)
	local items = catalog and catalog.Items
	if not items then
		return
	end

	local itemNames: { string } = {}
	for itemName, itemInfo in items do
		if type(itemName) == "string" and type(itemInfo) == "table" and not itemInfo.Disabled then
			table.insert(itemNames, itemName)
		end
	end

	local ownedSet = get_owned_set(pageConfig.category)
	local equippedName = get_equipped_name(pageConfig.category)
	local playerLevel = get_player_level()
	table.sort(itemNames, function(firstName: string, secondName: string): boolean
		return compare_item_names(firstName, secondName, items, ownedSet, equippedName)
	end)

	local pageSlotConnections: { RBXScriptConnection } = {}
	slotConnections[pageName] = pageSlotConnections
	for itemRank, itemName in itemNames do
		local itemInfo = items[itemName]
		local button = template:Clone()
		button.Name = itemName
		button:SetAttribute("InventorySlot", true)
		button.Visible = true
		configure_slot(button, pageName, pageCanvas, pageConfig, itemName, itemInfo, itemRank, ownedSet, equippedName, playerLevel)
		button.Parent = scrollingFrame
	end

	bind_buy_button(pageName, pageCanvas, pageConfig, pageSlotConnections)
	local selectedName = selectedItemNames[pageName] or equippedName
	update_selected_label(pageCanvas, selectedName)
	update_buy_button(pageCanvas, selectedName and items[selectedName], selectedName ~= nil and ownedSet[selectedName] == true, playerLevel)
end

local function load_all_pages(): ()
	for pageName in PAGE_CONFIGS do
		load_page(pageName)
	end
end

local function bind_navigation_button(button: Instance?, targetName: string, rootName: string): ()
	if not button or not button:IsA("GuiButton") then
		return
	end

	table.insert(navigationConnections, button.Activated:Connect(function()
		interfaceController.navigate_to(targetName, rootName)
	end))
end

local function bind_customize_navigation(): ()
	local customize = get_page_canvas("Customize")
	local avatarCard = customize and customize:FindFirstChild("Avatar")
	local upgradeCard = customize and customize:FindFirstChild("Upgrade")
	bind_navigation_button(avatarCard and avatarCard:FindFirstChild("Avatar"), "Avatar", "Customize")
	bind_navigation_button(upgradeCard and upgradeCard:FindFirstChild("Upgrade"), "Upgrade", "Customize")

	local canvas = get_canvas()
	local topbars = canvas and canvas:FindFirstChild("Topbars")
	local avatarTopbar = topbars and topbars:FindFirstChild("AvatarTopbarText")
	bind_navigation_button(avatarTopbar and avatarTopbar:FindFirstChild("Avatar"), "Avatar", "Customize")
	bind_navigation_button(avatarTopbar and avatarTopbar:FindFirstChild("Helmets"), "Helmets", "Customize")
end

local function disconnect_connections(): ()
	for _, connection in dataConnections do
		connection:disconnect()
	end
	dataConnections = {}

	for _, connection in navigationConnections do
		connection:Disconnect()
	end
	navigationConnections = {}

	for _, connection in actionConnections do
		connection:Disconnect()
	end
	actionConnections = {}
	equipInventory = nil
	purchaseInventory = nil
	disconnect_slot_connections()
end

local function bind_data_refresh(): ()
	local function bind(path: string, callback: () -> ()): ()
		local connection = dataUtility.client.bind(path, callback)
		if connection then
			table.insert(dataConnections, connection :: DataConnection)
		end
	end

	bind("Inventory.Owned.Livery", function()
		load_page("Car")
	end)
	bind("Inventory.Equipped.Livery", function()
		load_page("Car")
	end)
	bind("Inventory.Owned.Suit", function()
		load_page("Avatar")
	end)
	bind("Inventory.Equipped.Suit", function()
		load_page("Avatar")
	end)
	bind("Inventory.Owned.Helmets", function()
		load_page("Helmets")
	end)
	bind("Inventory.Equipped.Helmets", function()
		load_page("Helmets")
	end)
	bind("Profile.Level", load_all_pages)
end

------------------//MAIN FUNCTIONS
local function inventory_slot_controller_enable(): boolean
	if isEnabled then
		return true
	end

	dataUtility.client.ensure_remotes()
	bind_action_remotes()
	load_all_pages()
	bind_customize_navigation()
	bind_data_refresh()
	isEnabled = true
	return true
end

local function inventory_slot_controller_disable(): ()
	if not isEnabled then
		return
	end

	disconnect_connections()
	isEnabled = false
end

------------------//INIT
return {
	enable = inventory_slot_controller_enable,
	disable = inventory_slot_controller_disable,
}
