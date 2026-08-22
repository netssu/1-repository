------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local MAIN_UI_NAME: string = "MainUI"
local CANVAS_NAME: string = "Canvas"
local HOME_FRAME_NAME: string = "Home"
local QUICK_ACTIONS_NAME: string = "QuickActions"
local REMOVED_QUICK_ACTION_BUTTON_NAMES: { string } = { "Quests" }

type NavigationAction = {
	buttonName: string,
	frameName: string,
}

local NAVIGATION_ACTIONS: { NavigationAction } = {
	{ buttonName = "RacingPass", frameName = "RacingPass" },
	{ buttonName = "Challenges", frameName = "Challenges" },
	{ buttonName = "DailyReward", frameName = "DailyReward" },
}

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local interfaceController = require(modules:WaitForChild("Interface"):WaitForChild("InterfaceController"))

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local navigationConnections: { RBXScriptConnection } = {}

------------------//FUNCTIONS
local function get_canvas(): Frame?
	local mainUi = playerGui:WaitForChild(MAIN_UI_NAME, 10)
	local canvas = mainUi and mainUi:WaitForChild(CANVAS_NAME, 10)
	if canvas and canvas:IsA("Frame") then
		return canvas
	end

	return nil
end

local function bind_navigation_button(button: Instance?, frameName: string): ()
	if not button or not button:IsA("GuiButton") then
		return
	end

	table.insert(navigationConnections, button.Activated:Connect(function()
		interfaceController.navigate_to(frameName, HOME_FRAME_NAME)
	end))
end

local function find_button(root: Instance, buttonName: string): GuiButton?
	if root:IsA("GuiButton") and root.Name == buttonName then
		return root
	end

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiButton") and descendant.Name == buttonName then
			return descendant
		end
	end
	return nil
end

local function bind_quick_actions(canvas: Frame): ()
	local quickActions = canvas:FindFirstChild(QUICK_ACTIONS_NAME)
	if not quickActions then
		return
	end

	for _, buttonName in REMOVED_QUICK_ACTION_BUTTON_NAMES do
		local button = quickActions:FindFirstChild(buttonName)
		if button and button:IsA("GuiButton") then
			button.Visible = false
			button.Active = false
		end
	end

	for _, action in NAVIGATION_ACTIONS do
		bind_navigation_button(quickActions:FindFirstChild(action.buttonName), action.frameName)
	end
end

local function bind_home_actions(canvas: Frame): ()
	local home = canvas:FindFirstChild(HOME_FRAME_NAME)
	if not home then
		return
	end

	for _, action in {
		{ buttonName = "Shop", frameName = "Shop" },
		{ buttonName = "Customize", frameName = "Customize" },
		{ buttonName = "RacingPass", frameName = "RacingPass" },
		{ buttonName = "Play", frameName = "Play" },
	} do
		bind_navigation_button(find_button(home, action.buttonName), action.frameName)
	end
end

local function bind_navigation(): ()
	local canvas = get_canvas()
	if not canvas then
		return
	end

	bind_quick_actions(canvas)
	bind_home_actions(canvas)
end

------------------//MAIN FUNCTIONS
local function main_navigation_enable(): ()
	bind_navigation()
end

------------------//INIT
main_navigation_enable()
