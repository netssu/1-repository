------------------//SERVICES
local Players: Players = game:GetService("Players")
local PhysicsService: PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//CONSTANTS
local MATCH_STATE_FOLDER_NAME: string = "MatchState"
local LOADED_MAP_ATTRIBUTE_NAME: string = "LoadedMap"
local FESYSTEM_FOLDER_NAME: string = "FESystem"
local VEHICLES_FOLDER_NAME: string = "Vehicles"
local GRID_SPAWNS_FOLDER_NAME: string = "GridSpawns"
local OWNER_ATTRIBUTE_NAME: string = "OwnerUserId"
local SESSION_ATTRIBUTE_NAME: string = "SessionId"
local LIVERY_ATTRIBUTE_NAME: string = "Livery"
local SPAWN_ATTRIBUTE_NAME: string = "SpawnSlot"
local VEHICLE_COLLISION_GROUP: string = "Vehicle"
local DRIVE_SEAT_NAME: string = "DriveSeat"
local LEGACY_SOUND_HANDLER_NAME: string = "Handler"
local A_CHASSIS_HUD_NAME: string = "A-ChassisHUD"
local DISABLED_LEGACY_PLUGIN_NAMES: { [string]: boolean } = {
	AC6_Stock_Sound = true,
	SteeringWheel = true,
}

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local serverModules: Folder = ServerStorage:WaitForChild("Modules")
local inventoryAssetResolver = require(serverModules:WaitForChild("InventoryAssetResolver"))

------------------//VARIABLES
local matchState: Folder = ReplicatedStorage:WaitForChild(MATCH_STATE_FOLDER_NAME) :: Folder
local vehiclesByUserId: { [number]: Model } = {}
local spawnsByUserId: { [number]: BasePart } = {}
local started: boolean = false

------------------//FUNCTIONS
local function ensure_collision_group(): ()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(VEHICLE_COLLISION_GROUP)
	end)
end

local function get_fesystem(): Instance?
	return workspace:FindFirstChild(FESYSTEM_FOLDER_NAME)
end

local function get_vehicles_folder(fesystem: Instance): Folder
	local vehicles = fesystem:FindFirstChild(VEHICLES_FOLDER_NAME)
	if vehicles and vehicles:IsA("Folder") then
		return vehicles
	end

	local newVehicles = Instance.new("Folder")
	newVehicles.Name = VEHICLES_FOLDER_NAME
	newVehicles.Parent = fesystem
	return newVehicles
end

local function get_sorted_spawns(fesystem: Instance): { BasePart }
	local gridSpawns = fesystem:FindFirstChild(GRID_SPAWNS_FOLDER_NAME)
	local spawns: { BasePart } = {}
	if not gridSpawns then
		return spawns
	end

	for _, child in gridSpawns:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(spawns, child)
		end
	end

	table.sort(spawns, function(left: BasePart, right: BasePart): boolean
		return (tonumber(left.Name) or math.huge) < (tonumber(right.Name) or math.huge)
	end)
	return spawns
end

local function get_available_spawn(player: Player, fesystem: Instance): BasePart?
	local currentSpawn = spawnsByUserId[player.UserId]
	if currentSpawn and currentSpawn.Parent then
		return currentSpawn
	end

	for _, spawn in get_sorted_spawns(fesystem) do
		local ownerUserId = spawn:GetAttribute(OWNER_ATTRIBUTE_NAME)
		if ownerUserId == nil or ownerUserId == player.UserId then
			spawn:SetAttribute(OWNER_ATTRIBUTE_NAME, player.UserId)
			spawnsByUserId[player.UserId] = spawn
			return spawn
		end
	end

	return nil
end

local function get_vehicle_template(player: Player): (Model?, string)
	local equippedLivery = dataUtility.server.get(player, "Inventory.Equipped.Livery")
	local resolvedLivery = inventoryAssetResolver.get_resolved_item_name("Livery", equippedLivery)
	local template = inventoryAssetResolver.get_item_template("Livery", resolvedLivery)
	if template and template:IsA("Model") then
		return template, resolvedLivery
	end

	return nil, resolvedLivery
end

local function set_network_owner(vehicle: Model, player: Player): ()
	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.Anchored then
			pcall(function()
				descendant:SetNetworkOwner(player)
			end)
		end
	end
end

local function disable_legacy_vehicle_plugins(vehicle: Model): ()
	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("LocalScript") and DISABLED_LEGACY_PLUGIN_NAMES[descendant.Name] then
			descendant.Enabled = false
		elseif descendant:IsA("Script") and descendant.Name == LEGACY_SOUND_HANDLER_NAME then
			descendant.Disabled = true
		end
	end
end

local function ensure_player_vehicle_hud(player: Player, vehicle: Model): ()
	local wheels = vehicle:FindFirstChild("Wheels")
	if wheels then
		for _, wheel in wheels:GetChildren() do
			if wheel:IsA("BasePart") then
				wheel:WaitForChild("#AV", 5)
				wheel:WaitForChild("#BV", 5)
			end
		end
	end

	local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)
	local hudTemplate = vehicle:FindFirstChild(A_CHASSIS_HUD_NAME, true)
	if not playerGui or not hudTemplate or not hudTemplate:IsA("ScreenGui") then
		return
	end

	local existingHud = playerGui:FindFirstChild(A_CHASSIS_HUD_NAME)
	if existingHud then
		existingHud:Destroy()
	end

	local hud = hudTemplate:Clone()
	local carValue = hud:FindFirstChild("Car")
	if carValue and carValue:IsA("ObjectValue") then
		carValue.Value = vehicle
	end
	hud.Parent = playerGui
end

local function prepare_vehicle(vehicle: Model, player: Player, sessionId: string, livery: string): ()
	vehicle.Name = player.Name .. "_Vehicle"
	vehicle:SetAttribute(OWNER_ATTRIBUTE_NAME, player.UserId)
	vehicle:SetAttribute(SESSION_ATTRIBUTE_NAME, sessionId)
	vehicle:SetAttribute(LIVERY_ATTRIBUTE_NAME, livery)
	local driveSeat = vehicle:FindFirstChild(DRIVE_SEAT_NAME, true)
	if driveSeat and driveSeat:IsA("BasePart") then
		vehicle.PrimaryPart = driveSeat
	end

	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = VEHICLE_COLLISION_GROUP
		end
	end

	disable_legacy_vehicle_plugins(vehicle)
	set_network_owner(vehicle, player)
end

local function align_vehicle_to_spawn(vehicle: Model, spawn: BasePart): ()
	local referencePart = vehicle.PrimaryPart
	if not referencePart then
		vehicle:PivotTo(spawn.CFrame)
		return
	end

	local pivot = vehicle:GetPivot()
	local referenceRelativeToPivot = pivot:ToObjectSpace(referencePart.CFrame)
	vehicle:PivotTo(spawn.CFrame * referenceRelativeToPivot:Inverse())
end

------------------//MAIN FUNCTIONS
local vehicleService = {}

function vehicleService.get_player_vehicle(player: Player): Model?
	local vehicle = vehiclesByUserId[player.UserId]
	if vehicle and vehicle.Parent then
		return vehicle
	end

	vehiclesByUserId[player.UserId] = nil
	return nil
end

function vehicleService.spawn_vehicle(player: Player, sessionId: string): (Model?, BasePart?)
	vehicleService.destroy_vehicle(player)

	local fesystem = get_fesystem()
	if not fesystem then
		return nil, nil
	end

	local template, resolvedLivery = get_vehicle_template(player)
	if not template then
		warn(("[VehicleService] Livery inválida para %s"):format(player.Name))
		return nil, nil
	end

	local spawn = get_available_spawn(player, fesystem)
	if not spawn then
		warn(("[VehicleService] Nenhuma vaga disponível para %s"):format(player.Name))
		return nil, nil
	end

	local vehicle = template:Clone()
	prepare_vehicle(vehicle, player, sessionId, resolvedLivery)
	vehicle:SetAttribute(SPAWN_ATTRIBUTE_NAME, spawn.Name)
	vehicle.Parent = get_vehicles_folder(fesystem)
	align_vehicle_to_spawn(vehicle, spawn)

	vehiclesByUserId[player.UserId] = vehicle
	player:SetAttribute(LIVERY_ATTRIBUTE_NAME, resolvedLivery)
	return vehicle, spawn
end

function vehicleService.position_vehicle(vehicle: Model, spawn: BasePart): boolean
	if not vehicle.Parent then
		return false
	end

	align_vehicle_to_spawn(vehicle, spawn)
	return true
end

function vehicleService.set_enabled(player: Player, enabled: boolean): boolean
	local vehicle = vehicleService.get_player_vehicle(player)
	local seat = vehicle and vehicle:FindFirstChild("DriveSeat")
	if not seat or not seat:IsA("VehicleSeat") then
		return false
	end

	seat.Disabled = not enabled
	return true
end

function vehicleService.seat_player(player: Player): boolean
	local vehicle = vehicleService.get_player_vehicle(player)
	local seat = vehicle and vehicle:FindFirstChild("DriveSeat")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not seat or not seat:IsA("VehicleSeat") or not humanoid then
		return false
	end

	seat:Sit(humanoid)
	ensure_player_vehicle_hud(player, vehicle)
	return true
end

function vehicleService.destroy_vehicle(player: Player): ()
	local vehicle = vehiclesByUserId[player.UserId]
	if vehicle then
		vehicle:Destroy()
	end
	vehiclesByUserId[player.UserId] = nil

	local spawn = spawnsByUserId[player.UserId]
	if spawn then
		spawn:SetAttribute(OWNER_ATTRIBUTE_NAME, nil)
	end
	spawnsByUserId[player.UserId] = nil
	player:SetAttribute(LIVERY_ATTRIBUTE_NAME, nil)
end

function vehicleService.destroy_all(): ()
	for _, player in Players:GetPlayers() do
		vehicleService.destroy_vehicle(player)
	end
end

function vehicleService.start(): ()
	if started then
		return
	end
	started = true
	ensure_collision_group()

	Players.PlayerRemoving:Connect(function(player: Player)
		vehicleService.destroy_vehicle(player)
	end)

	matchState:GetAttributeChangedSignal(LOADED_MAP_ATTRIBUTE_NAME):Connect(function()
		vehicleService.destroy_all()
	end)
end

------------------//INIT
return vehicleService
