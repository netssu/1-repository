------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local MAIN_UI_NAME: string = "MainUI"
local CANVAS_NAME: string = "Canvas"
local UPGRADE_FRAME_NAME: string = "Upgrade"
local CAR_UPGRADES_FRAME_NAME: string = "CarUpgrades"
local PLAYER_UPGRADES_FRAME_NAME: string = "PlayerUpgrades"
local PROFILE_REMOTES_FOLDER_NAME: string = "ProfileRemotes"
local UPGRADE_REMOTE_NAME: string = "UpgradeInventory"
local UPGRADES_PATH: string = "Inventory.Upgrades."
local CASH_PATH: string = "Currency.Cash"
local BUY_NAME: string = "Buy"
local BUY_LABEL_NAME: string = "TextLabel"
local STATS_NAME: string = "Stats"
local ALERT_NAME: string = "Alert"
local MAX_UPGRADE_LEVEL: number = 3
local COMPLETED_COLOR: Color3 = Color3.fromRGB(104, 156, 0)
local INCOMPLETE_COLOR: Color3 = Color3.fromRGB(255, 255, 255)
local CLICK_COOLDOWN: number = 0.35

local UPGRADE_NAMES: { string } = {
	"Horsepower",
	"Battery",
	"KiloWatt",
	"Cash",
	"XP",
}
local UPGRADE_STAGE_NAMES: { string } = { "One", "Two", "Three" }

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataFolder: Folder = modules:WaitForChild("Data") :: Folder
local dataUtility = require(dataFolder:WaitForChild("DataUtility"))
local upgradeCatalog = require(dataFolder:WaitForChild("Inventory"):WaitForChild("Upgrades"))

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local upgradeInventory: RemoteEvent?
local dataConnections: { { disconnect: (self: any) -> () } } = {}
local actionConnections: { RBXScriptConnection } = {}
local isEnabled: boolean = false
local lastClickAt: { [string]: number } = {}
local alertTokens: { [string]: number } = {}

------------------//FUNCTIONS
local function get_upgrade_canvas(): GuiObject?
	local mainUi = playerGui:FindFirstChild(MAIN_UI_NAME)
	local canvas = mainUi and mainUi:FindFirstChild(CANVAS_NAME)
	local upgrade = canvas and canvas:FindFirstChild(UPGRADE_FRAME_NAME)
	return if upgrade and upgrade:IsA("GuiObject") then upgrade else nil
end

local function get_upgrade_card(upgradeName: string): GuiObject?
	local upgradeCanvas = get_upgrade_canvas()
	if not upgradeCanvas then
		return nil
	end

	local parentName = if upgradeName == "Horsepower" or upgradeName == "Battery" or upgradeName == "KiloWatt"
		then CAR_UPGRADES_FRAME_NAME
		else PLAYER_UPGRADES_FRAME_NAME
	local parent = upgradeCanvas:FindFirstChild(parentName)
	local card = parent and parent:FindFirstChild(upgradeName)
	return if card and card:IsA("GuiObject") then card else nil
end

local function get_current_level(upgradeName: string): number
	local value = tonumber(dataUtility.client.get(UPGRADES_PATH .. upgradeName))
	return math.clamp(value or 0, 0, MAX_UPGRADE_LEVEL)
end

local function get_cash(): number
	return math.max(0, tonumber(dataUtility.client.get(CASH_PATH)) or 0)
end

local function get_next_step(upgradeName: string, currentLevel: number): { [string]: any }?
	local steps = upgradeCatalog[upgradeName]
	local step = steps and steps[currentLevel]
	return if type(step) == "table" then step else nil
end

local function set_alert(card: GuiObject, isVisible: boolean): ()
	local alert = card:FindFirstChild(ALERT_NAME)
	if alert and alert:IsA("GuiObject") then
		alert.Visible = isVisible
	end
end

local function show_failed_alert(upgradeName: string): ()
	local card = get_upgrade_card(upgradeName)
	if not card then
		return
	end

	local token = (alertTokens[upgradeName] or 0) + 1
	alertTokens[upgradeName] = token
	set_alert(card, true)
	task.delay(1, function()
		if alertTokens[upgradeName] == token then
			local currentCard = get_upgrade_card(upgradeName)
			if currentCard then
				set_alert(currentCard, get_current_level(upgradeName) < MAX_UPGRADE_LEVEL and get_cash() < (tonumber((get_next_step(upgradeName, get_current_level(upgradeName)) or {}).Price) or 0))
			end
		end
	end)
end

local function update_card(upgradeName: string): ()
	local card = get_upgrade_card(upgradeName)
	if not card then
		return
	end

	local currentLevel = get_current_level(upgradeName)
	local nextStep = get_next_step(upgradeName, currentLevel)
	for level, stageName in UPGRADE_STAGE_NAMES do
		local levelImage = card:FindFirstChild("Upgrade" .. stageName)
		if levelImage and levelImage:IsA("ImageLabel") then
			levelImage.ImageColor3 = if currentLevel >= level then COMPLETED_COLOR else INCOMPLETE_COLOR
		end
	end

	local buy = card:FindFirstChild(BUY_NAME)
	local buyLabel = buy and buy:FindFirstChild(BUY_LABEL_NAME)
	local stats = card:FindFirstChild(STATS_NAME)
	local isMax = currentLevel >= MAX_UPGRADE_LEVEL or not nextStep
	local canAfford = not isMax and get_cash() >= (tonumber(nextStep and nextStep.Price) or 0)
	if buy and buy:IsA("GuiButton") then
		buy.Active = not isMax
		buy.AutoButtonColor = not isMax
	end
	if buyLabel and buyLabel:IsA("TextLabel") then
		buyLabel.Text = if isMax then "MAX" else "$" .. tostring(nextStep and nextStep.Price or 0)
	end
	if stats and stats:IsA("TextLabel") then
		stats.Text = if isMax then "MAX LEVEL" else tostring(nextStep and nextStep.Description or "")
	end
	set_alert(card, not isMax and not canAfford)
end

local function update_all_cards(): ()
	for _, upgradeName in UPGRADE_NAMES do
		update_card(upgradeName)
	end
end

local function bind_buy_button(upgradeName: string): ()
	local card = get_upgrade_card(upgradeName)
	local buy = card and card:FindFirstChild(BUY_NAME)
	if not buy or not buy:IsA("GuiButton") then
		return
	end

	table.insert(actionConnections, buy.Activated:Connect(function()
		local now = os.clock()
		if now - (lastClickAt[upgradeName] or 0) < CLICK_COOLDOWN then
			return
		end
		lastClickAt[upgradeName] = now

		local currentLevel = get_current_level(upgradeName)
		local nextStep = get_next_step(upgradeName, currentLevel)
		if not nextStep or get_cash() < (tonumber(nextStep.Price) or 0) then
			show_failed_alert(upgradeName)
			return
		end
		if upgradeInventory then
			buy.Active = false
			upgradeInventory:FireServer(upgradeName)
		end
	end))
end

local function bind_upgrade_remote(): ()
	local remotesFolder = ReplicatedStorage:WaitForChild(PROFILE_REMOTES_FOLDER_NAME)
	local remote = remotesFolder:WaitForChild(UPGRADE_REMOTE_NAME)
	if not remote:IsA("RemoteEvent") then
		return
	end

	upgradeInventory = remote
	table.insert(actionConnections, remote.OnClientEvent:Connect(function(success: boolean, upgradeName: string?)
		if not upgradeName then
			return
		end
		if not success then
			show_failed_alert(upgradeName)
		end
		update_card(upgradeName)
	end))
end

local function bind_data_refresh(): ()
	local function bind(path: string): ()
		local connection = dataUtility.client.bind(path, update_all_cards)
		if connection then
			table.insert(dataConnections, connection)
		end
	end

	bind(CASH_PATH)
	for _, upgradeName in UPGRADE_NAMES do
		bind(UPGRADES_PATH .. upgradeName)
	end
end

local function disconnect_connections(): ()
	for _, connection in dataConnections do
		connection:disconnect()
	end
	dataConnections = {}
	for _, connection in actionConnections do
		connection:Disconnect()
	end
	actionConnections = {}
	upgradeInventory = nil
end

------------------//MAIN FUNCTIONS
local function upgrade_controller_enable(): boolean
	if isEnabled then
		return true
	end

	dataUtility.client.ensure_remotes()
	bind_upgrade_remote()
	bind_data_refresh()
	for _, upgradeName in UPGRADE_NAMES do
		bind_buy_button(upgradeName)
	end
	update_all_cards()
	isEnabled = true
	return true
end

local function upgrade_controller_disable(): ()
	if not isEnabled then
		return
	end

	disconnect_connections()
	isEnabled = false
end

------------------//INIT
return {
	enable = upgrade_controller_enable,
	disable = upgrade_controller_disable,
}
