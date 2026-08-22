------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local MAIN_UI_NAME: string = "MainUI"
local CANVAS_NAME: string = "Canvas"
local GARAGE_NAME: string = "Garage"
local TERRAIN_NAME: string = "Terrain"
local PLAYER_CAMERA_NAME: string = "PlayerCamera"
local CAR_CAMERA_NAME: string = "CarCamera"
local PLAYER_MODE_FRAMES: { [string]: boolean } = {
	Avatar = true,
	Helmets = true,
}
local CAR_MODE_FRAMES: { [string]: boolean } = {
	Car = true,
	TireSmoke = true,
	UnderGlow = true,
	Upgrade = true,
}
local WATCHED_FRAME_NAMES: { string } = {
	"Avatar",
	"Helmets",
	"Upgrade",
	"Car",
	"TireSmoke",
	"UnderGlow",
}

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local garageCameraController = require(modules:WaitForChild("Interface"):WaitForChild("GarageCameraController"))
local garageCarShowcase = require(modules:WaitForChild("Interface"):WaitForChild("GarageCarShowcase"))
local garageAvatarShowcase = require(modules:WaitForChild("Interface"):WaitForChild("GarageAvatarShowcase"))

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local canvas: Frame?
local watchedFrames: { GuiObject } = {}
local visibilityConnections: { RBXScriptConnection } = {}
local dataConnections: { any } = {}
local isEnabled: boolean = false
local isGarageOpen: boolean = false
local activeFamily: string?
local reconcileQueued: boolean = false

------------------//FUNCTIONS
local function get_canvas(): Frame?
	if canvas and canvas.Parent then
		return canvas
	end

	local mainUi = playerGui:FindFirstChild(MAIN_UI_NAME)
	local foundCanvas = mainUi and mainUi:FindFirstChild(CANVAS_NAME)
	if foundCanvas and foundCanvas:IsA("Frame") then
		canvas = foundCanvas
		return canvas
	end
	return nil
end

local function get_mode(frameName: string): string?
	if PLAYER_MODE_FRAMES[frameName] then
		return "Player"
	end
	if CAR_MODE_FRAMES[frameName] then
		return "Car"
	end
	return nil
end

local function get_camera_target(family: string): CFrame?
	local terrain = workspace:FindFirstChild(TERRAIN_NAME)
	local garage = terrain and terrain:FindFirstChild(GARAGE_NAME)
	if not garage then
		return nil
	end

	if family == "Car" then
		local showcaseTarget = garageCarShowcase.get_camera_target()
		if showcaseTarget then
			return showcaseTarget
		end
		local carCamera = garage:FindFirstChild(CAR_CAMERA_NAME)
		return if carCamera and carCamera:IsA("BasePart") then carCamera.CFrame else nil
	end

	local playerCamera = garage:FindFirstChild(PLAYER_CAMERA_NAME)
	return if playerCamera and playerCamera:IsA("BasePart") then playerCamera.CFrame else nil
end

local function get_visible_frame(): GuiObject?
	for _, frame in watchedFrames do
		if frame.Visible then
			return frame
		end
	end
	return nil
end

local function refresh_car_showcase(): ()
	garageCarShowcase.refresh()
	if not isGarageOpen or activeFamily ~= "Car" then
		return
	end

	local visibleFrame = get_visible_frame()
	local target = get_camera_target("Car")
	if visibleFrame and target then
		garageCameraController.set_mode(visibleFrame.Name, target)
	end
end

local function queue_reconcile(): ()
	if reconcileQueued then
		return
	end

	reconcileQueued = true
	task.defer(function()
		reconcileQueued = false
		if isEnabled then
			local visibleFrame = get_visible_frame()
			local family = visibleFrame and get_mode(visibleFrame.Name)
			if family then
				local target = get_camera_target(family)
				if target then
					if not isGarageOpen then
						if family == "Car" then
							garageCarShowcase.activate(localPlayer)
							target = get_camera_target(family) or target
						else
							garageAvatarShowcase.activate()
						end
						isGarageOpen = garageCameraController.open(visibleFrame.Name, target, localPlayer)
						activeFamily = family
					elseif activeFamily ~= family then
						if family == "Car" then
							garageCarShowcase.activate(localPlayer)
							garageAvatarShowcase.deactivate()
						else
							garageCarShowcase.deactivate()
							garageAvatarShowcase.activate()
						end
						garageCameraController.set_mode(visibleFrame.Name, target)
						activeFamily = family
					end
				end
			elseif isGarageOpen then
				garageCarShowcase.deactivate()
				garageAvatarShowcase.deactivate()
				garageCameraController.close()
				isGarageOpen = false
				activeFamily = nil
			end
		end
	end)
end

local function bind_visibility(): ()
	local currentCanvas = get_canvas()
	if not currentCanvas then
		return
	end

	for _, frameName in WATCHED_FRAME_NAMES do
		local frame = currentCanvas:FindFirstChild(frameName)
		if frame and frame:IsA("GuiObject") then
			table.insert(watchedFrames, frame)
			table.insert(visibilityConnections, frame:GetPropertyChangedSignal("Visible"):Connect(queue_reconcile))
		end
	end
end

local function bind_data_refresh(): ()
	local function bind(path: string, callback: () -> ()): ()
		local connection = dataUtility.client.bind(path, callback)
		if connection then
			table.insert(dataConnections, connection)
		end
	end

	bind("Inventory.Owned.Livery", refresh_car_showcase)
	bind("Inventory.Equipped.Livery", refresh_car_showcase)
	bind("Inventory.Equipped.Suit", garageAvatarShowcase.refresh)
	bind("Inventory.Equipped.Helmets", garageAvatarShowcase.refresh)
end

local function disconnect_connections(): ()
	for _, connection in visibilityConnections do
		connection:Disconnect()
	end
	visibilityConnections = {}
	watchedFrames = {}

	for _, connection in dataConnections do
		connection:disconnect()
	end
	dataConnections = {}
end

------------------//MAIN FUNCTIONS
local function garage_showcase_controller_enable(): boolean
	if isEnabled then
		return true
	end

	if not get_canvas() then
		warn("[GarageShowcaseController] MainUI.Canvas not found")
		return false
	end

	dataUtility.client.ensure_remotes()
	bind_visibility()
	bind_data_refresh()
	isEnabled = true
	queue_reconcile()
	return true
end

local function garage_showcase_controller_disable(): ()
	if not isEnabled then
		return
	end

	isEnabled = false
	disconnect_connections()
	garageCarShowcase.deactivate()
	garageAvatarShowcase.deactivate()
	garageCameraController.close()
	isGarageOpen = false
	activeFamily = nil
	canvas = nil
end

------------------//INIT
return {
	enable = garage_showcase_controller_enable,
	disable = garage_showcase_controller_disable,
}
