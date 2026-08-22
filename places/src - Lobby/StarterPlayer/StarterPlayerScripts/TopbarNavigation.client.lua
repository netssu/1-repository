------------------//SERVICES
local ReplicatedFirst: ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local HOME_FRAME_NAME: string = "Home"
local DAILY_REWARD_FRAME_NAME: string = "DailyReward"
local CODES_FRAME_NAME: string = "Codes"
local DAILY_REWARD_ICON_IMAGE: string = "rbxthumb://type=Asset&id=82819743427196&w=150&h=150"
local CODES_ICON_IMAGE: string = "rbxthumb://type=Asset&id=5055129667&w=150&h=150"

------------------//DEPENDENCIES
local packages: Folder = ReplicatedFirst:WaitForChild("Packages")
local icon = require(packages:WaitForChild("Icon"))
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local interfaceController = require(modules:WaitForChild("Interface"):WaitForChild("InterfaceController"))

------------------//FUNCTIONS
local function navigate_to(frameName: string): ()
	interfaceController.navigate_to(frameName, HOME_FRAME_NAME)
end

local function create_navigation_icon(name: string, image: string, caption: string, order: number, frameName: string): ()
	local navigationIcon = icon.new()
	navigationIcon:setName(name)
	navigationIcon:setImage(image)
	navigationIcon:setCaption(caption)
	navigationIcon:setOrder(order)
	navigationIcon:oneClick()
	navigationIcon.selected:Connect(function()
		navigate_to(frameName)
	end)
end

------------------//MAIN FUNCTIONS
local function topbar_navigation_enable(): ()
	create_navigation_icon("DailyReward", DAILY_REWARD_ICON_IMAGE, "Daily Reward", 1, DAILY_REWARD_FRAME_NAME)
	create_navigation_icon("Codes", CODES_ICON_IMAGE, "Codes", 2, CODES_FRAME_NAME)
end

------------------//INIT
topbar_navigation_enable()
