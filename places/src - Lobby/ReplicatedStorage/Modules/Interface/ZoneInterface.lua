------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedFirst: ReplicatedFirst = game:GetService("ReplicatedFirst")

------------------//CONSTANTS
local ZONES_FOLDER_NAME: string = "Zones"
local ZONE_TO_FRAME: { [string]: string } = {
	Customize = "Customize",
	Quick = "Play",
	Car = "Car",
	Shop = "Shop",
}

------------------//DEPENDENCIES
local packages: Folder = ReplicatedFirst:WaitForChild("Packages")
local zonePlus = require(packages:WaitForChild("Zone"))
local interfaceController = require(script.Parent:WaitForChild("InterfaceController"))

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local zoneFolder: Folder?
local activeZone: BasePart?
local ignoredZoneUntilExit: BasePart?
local zoneObjects = {}
local zoneConnections: { RBXScriptConnection } = {}
local isEnabled: boolean = false

------------------//FUNCTIONS
local function get_frame_name(zonePart: BasePart): string
	local configuredFrameName = zonePart:GetAttribute("FrameName")
	if typeof(configuredFrameName) == "string" and configuredFrameName ~= "" then
		return configuredFrameName
	end

	local uiName = zonePart:GetAttribute("UI")
	if typeof(uiName) == "string" and uiName ~= "" then
		return uiName
	end

	return ZONE_TO_FRAME[zonePart.Name] or zonePart.Name
end

local function disconnect_zone_connections(): ()
	for _, connection in zoneConnections do
		connection:Disconnect()
	end
	zoneConnections = {}
end

local function destroy_zone_objects(): ()
	for _, zoneObject in zoneObjects do
		zoneObject:destroy()
	end
	zoneObjects = {}
end

local function close_zone(zonePart: BasePart): ()
	if ignoredZoneUntilExit == zonePart then
		ignoredZoneUntilExit = nil
	end

	if activeZone ~= zonePart then
		return
	end

	activeZone = nil
	interfaceController.close()
end

local function open_zone(zonePart: BasePart, frameName: string): ()
	if ignoredZoneUntilExit == zonePart then
		return
	end

	local frame = interfaceController.get_frame(frameName)
	if not frame then
		warn(("[ZoneInterface] UI frame not found for zone %s: %s"):format(zonePart.Name, frameName))
		return
	end

	activeZone = zonePart
	ignoredZoneUntilExit = nil
	interfaceController.open(frame, function()
		ignoredZoneUntilExit = zonePart
		activeZone = nil
		interfaceController.close()
	end)
end

local function bind_zone(zonePart: BasePart): ()
	local frameName = get_frame_name(zonePart)
	if not interfaceController.get_frame(frameName) then
		warn(("[ZoneInterface] UI frame not found for zone %s: %s"):format(zonePart.Name, frameName))
		return
	end

	local zoneObject = zonePlus.new(zonePart)
	table.insert(zoneObjects, zoneObject)
	table.insert(zoneConnections, zoneObject.localPlayerEntered:Connect(function()
		open_zone(zonePart, frameName)
	end))
	table.insert(zoneConnections, zoneObject.localPlayerExited:Connect(function()
		close_zone(zonePart)
	end))

	if zoneObject:findPlayer(localPlayer) then
		open_zone(zonePart, frameName)
	end
end

local function on_zone_added(instance: Instance): ()
	if instance:IsA("BasePart") then
		bind_zone(instance)
	end
end

------------------//MAIN FUNCTIONS
local function zone_interface_enable(): boolean
	if isEnabled then
		return true
	end

	if not interfaceController.enable() then
		return false
	end

	local foundZoneFolder = workspace:WaitForChild(ZONES_FOLDER_NAME, 10)
	if not foundZoneFolder or not foundZoneFolder:IsA("Folder") then
		warn("[ZoneInterface] Workspace.Zones not found")
		interfaceController.disable()
		return false
	end

	zoneFolder = foundZoneFolder
	isEnabled = true
	activeZone = nil
	ignoredZoneUntilExit = nil
	interfaceController.close()

	for _, instance in zoneFolder:GetChildren() do
		on_zone_added(instance)
	end

	table.insert(zoneConnections, zoneFolder.ChildAdded:Connect(on_zone_added))
	return true
end

local function zone_interface_disable(): ()
	isEnabled = false

	disconnect_zone_connections()
	destroy_zone_objects()
	zoneFolder = nil
	activeZone = nil
	ignoredZoneUntilExit = nil
	interfaceController.disable()
end

------------------//INIT
local zoneInterface = {
	enable = zone_interface_enable,
	disable = zone_interface_disable,
}

return zoneInterface

