------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local mapsData = require(modules:WaitForChild("Data"):WaitForChild("MapsData"))
local interfaceController = require(modules:WaitForChild("Interface"):WaitForChild("InterfaceController"))

------------------//CONSTANTS
local MAIN_UI_NAME: string = "MainUI"
local CANVAS_NAME: string = "Canvas"
local PLAY_FRAME_NAME: string = "Play"
local MAPS_FRAME_NAME: string = "Maps"
local MATCH_REMOTES_FOLDER_NAME: string = "MatchRemotes"
local JOIN_MATCH_REMOTE_NAME: string = "JoinMatch"
local TELEPORT_STATUS_REMOTE_NAME: string = "TeleportStatus"
local SELECTED_COLOR: Color3 = Color3.fromRGB(0, 170, 255)
local UNSELECTED_COLOR: Color3 = Color3.fromRGB(255, 255, 255)
local READY_COLOR: Color3 = Color3.fromRGB(0, 170, 255)
local BUSY_COLOR: Color3 = Color3.fromRGB(110, 130, 155)
local FAILED_COLOR: Color3 = Color3.fromRGB(255, 110, 110)

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local selectedMapName: string = mapsData.DEFAULT_MAP_NAME
local joinMatch: RemoteEvent?
local teleportStatus: RemoteEvent?
local playMapsConnection: RBXScriptConnection?
local travelConnection: RBXScriptConnection?
local mapConnections: { RBXScriptConnection } = {}
local teleportStatusConnection: RBXScriptConnection?
local isTeleporting: boolean = false
local isEnabled: boolean = false

------------------//FUNCTIONS
local function get_canvas(): Frame?
	local mainUi = playerGui:FindFirstChild(MAIN_UI_NAME)
	local canvas = mainUi and mainUi:FindFirstChild(CANVAS_NAME)
	if canvas and canvas:IsA("Frame") then
		return canvas
	end

	return nil
end

local function get_maps_frame(): Frame?
	local canvas = get_canvas()
	local mapsFrame = canvas and canvas:FindFirstChild(MAPS_FRAME_NAME)
	if mapsFrame and mapsFrame:IsA("Frame") then
		return mapsFrame
	end

	return nil
end

local function get_map_scrolling_frame(): ScrollingFrame?
	local mapsFrame = get_maps_frame()
	local mapCard = mapsFrame and mapsFrame:FindFirstChild("Mapcard")
	local scrollingFrame = mapCard and mapCard:FindFirstChild("ScrollingFrame")
	if scrollingFrame and scrollingFrame:IsA("ScrollingFrame") then
		return scrollingFrame
	end

	return nil
end

local function get_map_button(scrollingFrame: ScrollingFrame, mapName: string): GuiButton?
	local mapCard = scrollingFrame:FindFirstChild(mapName)
	if not mapCard then
		return nil
	end

	local mapButton = mapCard:FindFirstChild(mapName)
	if mapButton and mapButton:IsA("GuiButton") then
		return mapButton
	end

	return nil
end

local function get_travel_button(): GuiButton?
	local mapsFrame = get_maps_frame()
	local travel = mapsFrame and mapsFrame:FindFirstChild("Travel")
	local button = travel and travel:FindFirstChild("TravelBttn")
	if button and button:IsA("GuiButton") then
		return button
	end

	return nil
end

local function get_travel_label(): TextLabel?
	local mapsFrame = get_maps_frame()
	local travel = mapsFrame and mapsFrame:FindFirstChild("Travel")
	local label = travel and travel:FindFirstChild("TextLabel")
	if label and label:IsA("TextLabel") then
		return label
	end

	return nil
end

local function get_map_info_label(): TextLabel?
	local mapsFrame = get_maps_frame()
	local mapInfo = mapsFrame and mapsFrame:FindFirstChild("MapInfo")
	local label = mapInfo and mapInfo:FindFirstChild("TextLabel")
	if label and label:IsA("TextLabel") then
		return label
	end

	return nil
end

local function get_map_marker(): ImageLabel?
	local mapsFrame = get_maps_frame()
	local mapInfo = mapsFrame and mapsFrame:FindFirstChild("MapInfo")
	local worldMap = mapInfo and mapInfo:FindFirstChild("WorldMap")
	local marker = worldMap and worldMap:FindFirstChild("Marker")
	if marker and marker:IsA("ImageLabel") then
		return marker
	end

	return nil
end

local function set_travel_state(labelText: string, color: Color3, isActive: boolean): ()
	local button = get_travel_button()
	local label = get_travel_label()
	if button then
		button.Active = isActive
		button.AutoButtonColor = isActive
		button.ImageColor3 = color
	end
	if label then
		label.Text = labelText
	end
end

local function render_map_selection(): ()
	local selectedMap = mapsData.get_map(selectedMapName)
	local infoLabel = get_map_info_label()
	local marker = get_map_marker()
	local scrollingFrame = get_map_scrolling_frame()
	if not selectedMap or not scrollingFrame then
		return
	end

	localPlayer:SetAttribute("SelectedMap", selectedMap.Name)
	if infoLabel then
		infoLabel.Text = selectedMap.Description
	end
	if marker then
		marker.Visible = selectedMap.MarkerPosition ~= nil
		if selectedMap.MarkerPosition then
			marker.Position = selectedMap.MarkerPosition
		end
	end

	for _, map in mapsData.Maps do
		local button = get_map_button(scrollingFrame, map.Name)
		if button then
			button.ImageColor3 = if map.Name == selectedMap.Name then SELECTED_COLOR else UNSELECTED_COLOR
		end
	end
end

local function select_map(mapName: string): ()
	if not mapsData.get_map(mapName) then
		return
	end

	selectedMapName = mapName
	if not isTeleporting then
		set_travel_state("TRAVEL", READY_COLOR, true)
	end
	render_map_selection()
end

local function get_match_remotes(): boolean
	local remotes = ReplicatedStorage:WaitForChild(MATCH_REMOTES_FOLDER_NAME, 10)
	if not remotes then
		warn("[MapsController] MatchRemotes not found")
		return false
	end

	local joinRemote = remotes:WaitForChild(JOIN_MATCH_REMOTE_NAME, 10)
	local statusRemote = remotes:WaitForChild(TELEPORT_STATUS_REMOTE_NAME, 10)
	if not joinRemote or not joinRemote:IsA("RemoteEvent") or not statusRemote or not statusRemote:IsA("RemoteEvent") then
		warn("[MapsController] Match remotes are incomplete")
		return false
	end

	joinMatch = joinRemote
	teleportStatus = statusRemote
	return true
end

local function bind_play_maps_button(): ()
	local canvas = get_canvas()
	local playFrame = canvas and canvas:FindFirstChild(PLAY_FRAME_NAME)
	local mapsCard = playFrame and playFrame:FindFirstChild(MAPS_FRAME_NAME)
	local mapsButton = mapsCard and mapsCard:FindFirstChild(MAPS_FRAME_NAME)
	if not mapsButton or not mapsButton:IsA("GuiButton") then
		warn("[MapsController] Play maps button not found")
		return
	end

	playMapsConnection = mapsButton.Activated:Connect(function()
		interfaceController.navigate_to(MAPS_FRAME_NAME, PLAY_FRAME_NAME)
	end)
end

local function bind_map_buttons(): ()
	local scrollingFrame = get_map_scrolling_frame()
	if not scrollingFrame then
		warn("[MapsController] Map scrolling frame not found")
		return
	end

	for _, map in mapsData.Maps do
		local button = get_map_button(scrollingFrame, map.Name)
		if button then
			table.insert(mapConnections, button.Activated:Connect(function()
				select_map(map.Name)
			end))
		end
	end
end

local function bind_travel_button(): ()
	local button = get_travel_button()
	if not button or not joinMatch then
		return
	end

	travelConnection = button.Activated:Connect(function()
		if isTeleporting or not joinMatch then
			return
		end

		isTeleporting = true
		set_travel_state("LOADING", BUSY_COLOR, false)
		joinMatch:FireServer(selectedMapName)
	end)
end

local function bind_teleport_status(): ()
	if not teleportStatus then
		return
	end

	teleportStatusConnection = teleportStatus.OnClientEvent:Connect(function(isSuccessful: boolean, _code: string?)
		if isSuccessful then
			return
		end

		isTeleporting = false
		set_travel_state("RETRY", FAILED_COLOR, true)
	end)
end

local function disconnect_connections(): ()
	if playMapsConnection then
		playMapsConnection:Disconnect()
		playMapsConnection = nil
	end
	if travelConnection then
		travelConnection:Disconnect()
		travelConnection = nil
	end
	for _, connection in mapConnections do
		connection:Disconnect()
	end
	mapConnections = {}
	if teleportStatusConnection then
		teleportStatusConnection:Disconnect()
		teleportStatusConnection = nil
	end
end

------------------//MAIN FUNCTIONS
local function maps_controller_enable(): boolean
	if isEnabled then
		return true
	end

	if not get_maps_frame() or not get_match_remotes() then
		return false
	end

	isEnabled = true
	isTeleporting = false
	select_map(mapsData.DEFAULT_MAP_NAME)
	bind_play_maps_button()
	bind_map_buttons()
	bind_travel_button()
	bind_teleport_status()
	return true
end

local function maps_controller_disable(): ()
	if not isEnabled then
		return
	end

	disconnect_connections()
	joinMatch = nil
	teleportStatus = nil
	isTeleporting = false
	isEnabled = false
end

------------------//INIT
return {
	enable = maps_controller_enable,
	disable = maps_controller_disable,
}
