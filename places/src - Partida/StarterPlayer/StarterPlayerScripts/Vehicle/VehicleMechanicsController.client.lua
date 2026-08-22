------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//DEPENDENCIES
local vehicleConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("VehicleConfig"))

------------------//CONSTANTS
local FESYSTEM_FOLDER_NAME: string = "FESystem"
local VEHICLES_FOLDER_NAME: string = "Vehicles"
local RACE_EVENTS_FOLDER_NAME: string = "Events"
local RACE_REMOTES_FOLDER_NAME: string = "Race"
local ATTACK_MODE_REMOTE_NAME: string = "AttackMode"
local ATTACK_MODE_KEY: Enum.KeyCode = vehicleConfig.Keybinds.AttackMode

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local attackModeRemote: RemoteFunction? = nil

------------------//FUNCTIONS
local function get_owned_vehicle(): Model?
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not seat then
		return nil
	end

	local vehicle = seat:FindFirstAncestorOfClass("Model")
	local fesystem = workspace:FindFirstChild(FESYSTEM_FOLDER_NAME)
	local vehiclesFolder = fesystem and fesystem:FindFirstChild(VEHICLES_FOLDER_NAME)
	if vehicle and vehiclesFolder and vehicle.Parent == vehiclesFolder and vehicle:GetAttribute("OwnerUserId") == localPlayer.UserId then
		return vehicle
	end
	return nil
end

local function get_attack_mode_remote(): RemoteFunction?
	if attackModeRemote then
		return attackModeRemote
	end

	local events = ReplicatedStorage:FindFirstChild(RACE_EVENTS_FOLDER_NAME)
	local raceRemotes = events and events:FindFirstChild(RACE_REMOTES_FOLDER_NAME)
	local remote = raceRemotes and raceRemotes:FindFirstChild(ATTACK_MODE_REMOTE_NAME)
	if remote and remote:IsA("RemoteFunction") then
		attackModeRemote = remote
	end
	return attackModeRemote
end

local function activate_attack_mode(): ()
	if not get_owned_vehicle() then
		return
	end

	local remote = get_attack_mode_remote()
	if not remote then
		return
	end

	local success, activated = pcall(function(): boolean
		return remote:InvokeServer("RequestActivate")
	end)
	if not success or not activated then
		return
	end
end

------------------//INIT
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed or input.KeyCode ~= ATTACK_MODE_KEY then
		return
	end
	activate_attack_mode()
end)
