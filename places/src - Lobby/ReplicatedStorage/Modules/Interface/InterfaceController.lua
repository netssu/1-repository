------------------//SERVICES
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local MAIN_UI_NAME: string = "MainUI"
local CANVAS_NAME: string = "Canvas"
local TOPBARS_FOLDER_NAME: string = "Topbars"
local BACK_FRAME_NAME: string = "Back"
local QUICK_ACTIONS_NAME: string = "QuickActions"
local CAMERA_FRAME_NAMES: { [string]: boolean } = {
	Avatar = true,
	Helmets = true,
	Upgrade = true,
	Car = true,
	TireSmoke = true,
	UnderGlow = true,
}

local FRAME_TO_TOPBAR: { [string]: string } = {
	Shop = "ShopTopbarText",
	Boosters = "ShopTopbarText",
	Items = "ShopTopbarText",
	RacingPass = "RacingPassTopbarText",
	Challenges = "RacingPassTopbarText",
	Customize = "CustomizeSelectionText",
	Avatar = "AvatarTopbarText",
	Helmets = "AvatarTopbarText",
	Upgrade = "UpgradeTopBarText",
	Play = "PlayTopBarText",
	Maps = "MapsTopbarText",
	Car = "CarTopbarText",
	TireSmoke = "CarTopbarText",
	UnderGlow = "CarTopbarText",
	Settings = "SettingsTopBarText",
}

local MANAGED_FRAME_NAMES: { string } = {
	"Home",
	"RacingPass",
	"Challenges",
	"Quests",
	"LeaderBoard",
	"Codes",
	"Stats",
	"DailyReward",
	"Shop",
	"Boosters",
	"Items",
	"Play",
	"Maps",
	"Customize",
	"Avatar",
	"Helmets",
	"Upgrade",
	"Car",
	"TireSmoke",
	"UnderGlow",
	"Settings",
}

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")

local canvas: Frame?
local activeRootFrame: GuiObject?
local activeFrame: GuiObject?
local rootCloseCallback: (() -> ())?
local interfaceControllerClose: () -> () = function() end
local backConnection: RBXScriptConnection?
local topbarConnections: { RBXScriptConnection } = {}
local isEnabled: boolean = false

------------------//FUNCTIONS
local function get_canvas(): Frame?
	if canvas and canvas.Parent then
		return canvas
	end

	local mainUi = playerGui:FindFirstChild(MAIN_UI_NAME)
	if not mainUi or not mainUi:IsA("ScreenGui") then
		return nil
	end

	local foundCanvas = mainUi:FindFirstChild(CANVAS_NAME)
	if foundCanvas and foundCanvas:IsA("Frame") then
		canvas = foundCanvas
		return canvas
	end

	return nil
end

local function disconnect_topbar_connections(): ()
	for _, connection in topbarConnections do
		connection:Disconnect()
	end
	topbarConnections = {}
end

local function hide_topbars(): ()
	local currentCanvas = get_canvas()
	local topbars = currentCanvas and currentCanvas:FindFirstChild(TOPBARS_FOLDER_NAME)
	if not topbars then
		return
	end

	for _, topbar in topbars:GetChildren() do
		if topbar:IsA("GuiObject") then
			topbar.Visible = false
			topbar.Active = false
		end
	end
end

local function set_quick_actions_visible(isVisible: boolean): ()
	local currentCanvas = get_canvas()
	local quickActions = currentCanvas and currentCanvas:FindFirstChild(QUICK_ACTIONS_NAME)
	if quickActions and quickActions:IsA("GuiObject") then
		quickActions.Visible = isVisible
	end
end

local function set_topbar_selection(topbar: GuiObject, frameName: string): ()
	for _, child in topbar:GetChildren() do
		if not child:IsA("GuiButton") then
			continue
		end

		local isSelected = child.Name == frameName
		if child:IsA("ImageButton") then
			child.ImageTransparency = if isSelected then 0.5 else 1
		end

		local label = child:FindFirstChild(child.Name)
		local stroke = label and label:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			stroke.Enabled = isSelected
		end
	end
end

local function show_topbar_for_frame(frameName: string): ()
	local currentCanvas = get_canvas()
	local topbars = currentCanvas and currentCanvas:FindFirstChild(TOPBARS_FOLDER_NAME)
	local topbarName = FRAME_TO_TOPBAR[frameName]
	local topbar = topbarName and topbars and topbars:FindFirstChild(topbarName)
	hide_topbars()
	if not topbar or not topbar:IsA("GuiObject") then
		return
	end

	topbar.Visible = true
	topbar.Active = true

	local visibleButtonCount = 0
	for _, child in topbar:GetChildren() do
		if child:IsA("GuiButton") and child.Visible then
			visibleButtonCount += 1
		end
	end

	for _, child in topbar:GetChildren() do
		if child:IsA("GuiButton") then
			child.Active = visibleButtonCount > 1 and child.Visible
		end
	end

	set_topbar_selection(topbar, frameName)
end

local function set_back_visible(isVisible: boolean): ()
	local currentCanvas = get_canvas()
	local back = currentCanvas and currentCanvas:FindFirstChild(BACK_FRAME_NAME)
	if not back or not back:IsA("GuiObject") then
		return
	end

	back.Visible = isVisible
	back.Active = isVisible

	local backButton = back:FindFirstChild("Back")
	if backButton and backButton:IsA("GuiButton") then
		backButton.Visible = isVisible
		backButton.Active = isVisible
		backButton.ZIndex = 10
	end
end

local function set_managed_frame(frameToShow: GuiObject?): ()
	local currentCanvas = get_canvas()
	if not currentCanvas then
		return
	end

	set_quick_actions_visible(frameToShow == nil or frameToShow.Name == "Home")

	for _, frameName in MANAGED_FRAME_NAMES do
		local frame = currentCanvas:FindFirstChild(frameName)
		if frame and frame:IsA("GuiObject") then
			frame.Visible = frame == frameToShow
		end
	end
end

local function activate_frame(frame: GuiObject): ()
	activeFrame = frame
	set_managed_frame(frame)
	show_topbar_for_frame(frame.Name)
	set_back_visible(activeFrame ~= activeRootFrame or CAMERA_FRAME_NAMES[frame.Name] == true)
end

local function get_visible_managed_frame(): GuiObject?
	local currentCanvas = get_canvas()
	if not currentCanvas then
		return nil
	end

	for _, frameName in MANAGED_FRAME_NAMES do
		local frame = currentCanvas:FindFirstChild(frameName)
		if frame and frame:IsA("GuiObject") and frame.Visible then
			return frame
		end
	end

	return nil
end

local function handle_back(): ()
	if not activeRootFrame or not activeFrame then
		return
	end

	local currentVisibleFrame = get_visible_managed_frame()
	if currentVisibleFrame and currentVisibleFrame ~= activeRootFrame then
		if activeRootFrame.Name == "Home" then
			interfaceControllerClose()
		else
			activate_frame(activeRootFrame)
		end
		return
	end

	if activeFrame ~= activeRootFrame then
		activate_frame(activeRootFrame)
		return
	end

	local closeCallback = rootCloseCallback
	if closeCallback then
		closeCallback()
	else
		interfaceControllerClose()
	end
end

local function bind_back_button(): ()
	local currentCanvas = get_canvas()
	local back = currentCanvas and currentCanvas:FindFirstChild(BACK_FRAME_NAME)
	local backButton = back and back:FindFirstChild("Back")
	if not backButton or not backButton:IsA("GuiButton") then
		warn("[InterfaceController] Back button not found")
		return
	end

	backConnection = backButton.Activated:Connect(handle_back)
end

local function is_button_in_active_topbar(button: GuiButton): boolean
	local currentFrame = get_visible_managed_frame() or activeFrame or activeRootFrame
	if not currentFrame then
		return false
	end

	local currentTopbarName = FRAME_TO_TOPBAR[currentFrame.Name]
	return FRAME_TO_TOPBAR[button.Name] == currentTopbarName
end

local function bind_topbar_buttons(): ()
	local currentCanvas = get_canvas()
	local topbars = currentCanvas and currentCanvas:FindFirstChild(TOPBARS_FOLDER_NAME)
	if not currentCanvas or not topbars then
		return
	end

	for _, topbar in topbars:GetChildren() do
		if not topbar:IsA("GuiObject") then
			continue
		end

		for _, child in topbar:GetChildren() do
			if not child:IsA("GuiButton") then
				continue
			end

			table.insert(topbarConnections, child.Activated:Connect(function()
				if not is_button_in_active_topbar(child) then
					return
				end

				local targetFrame = currentCanvas:FindFirstChild(child.Name)
				if targetFrame and targetFrame:IsA("GuiObject") then
					activate_frame(targetFrame)
				end
			end))
		end
	end
end

------------------//MAIN FUNCTIONS
local function interface_controller_enable(): boolean
	if isEnabled then
		return true
	end

	local mainUi = playerGui:WaitForChild(MAIN_UI_NAME, 10)
	if not mainUi then
		warn("[InterfaceController] MainUI not found")
		return false
	end

	local foundCanvas = mainUi:WaitForChild(CANVAS_NAME, 10)
	if not foundCanvas or not foundCanvas:IsA("Frame") then
		warn("[InterfaceController] MainUI.Canvas not found")
		return false
	end

	canvas = foundCanvas
	isEnabled = true
	activeRootFrame = nil
	activeFrame = nil
	rootCloseCallback = nil
	set_managed_frame(nil)
	hide_topbars()
	set_back_visible(false)
	bind_back_button()
	bind_topbar_buttons()
	return true
end

local function interface_controller_open(frame: GuiObject, onRootClose: (() -> ())?): ()
	if not isEnabled and not interface_controller_enable() then
		return
	end

	activeRootFrame = frame
	activeFrame = frame
	rootCloseCallback = onRootClose
	set_managed_frame(frame)
	show_topbar_for_frame(frame.Name)
	set_back_visible(CAMERA_FRAME_NAMES[frame.Name] == true)
end

interfaceControllerClose = function(): ()
	activeRootFrame = nil
	activeFrame = nil
	rootCloseCallback = nil
	set_managed_frame(nil)
	hide_topbars()
	set_back_visible(false)
end

local function interface_controller_get_frame(frameName: string): GuiObject?
	local currentCanvas = get_canvas()
	local frame = currentCanvas and currentCanvas:FindFirstChild(frameName)
	if frame and frame:IsA("GuiObject") then
		return frame
	end

	return nil
end

local function interface_controller_navigate_to(frameName: string, rootFrameName: string?): boolean
	local targetFrame = interface_controller_get_frame(frameName)
	if not targetFrame then
		warn(("[InterfaceController] UI frame not found: %s"):format(frameName))
		return false
	end

	if not isEnabled and not interface_controller_enable() then
		return false
	end

	if rootFrameName then
		local rootFrame = interface_controller_get_frame(rootFrameName)
		if not rootFrame then
			warn(("[InterfaceController] Root UI frame not found: %s"):format(rootFrameName))
			return false
		end
		activeRootFrame = rootFrame
		rootCloseCallback = nil

		local currentVisibleFrame = get_visible_managed_frame()
		if currentVisibleFrame == targetFrame then
			interfaceControllerClose()
			return true
		end
	end

	if not activeRootFrame then
		interface_controller_open(targetFrame)
	else
		activate_frame(targetFrame)
	end

	return true
end

local function interface_controller_disable(): ()
	isEnabled = false

	if backConnection then
		backConnection:Disconnect()
		backConnection = nil
	end

	disconnect_topbar_connections()
	interfaceControllerClose()
	canvas = nil
end

------------------//INIT
local interfaceController = {
	enable = interface_controller_enable,
	open = interface_controller_open,
	close = interfaceControllerClose,
	get_frame = interface_controller_get_frame,
	navigate_to = interface_controller_navigate_to,
	disable = interface_controller_disable,
}

return interfaceController
