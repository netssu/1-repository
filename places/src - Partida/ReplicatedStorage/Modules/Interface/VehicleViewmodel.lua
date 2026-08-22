------------------//SERVICES
local Players: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")

------------------//CONSTANTS
local BODY_FOLDER_NAME: string = "Body"
local CAMERAS_FOLDER_NAME: string = "Cameras"
local COCKPIT_CAMERA_NAME: string = "COCKPITCAM"
local FALLBACK_CAMERA_NAME: string = "CHASE"
local COCKPIT_FIELD_OF_VIEW: number = 80

------------------//TYPES
type ViewmodelState = {
	player: Player,
	vehicle: Model,
	character: Model,
	camera: Camera,
	cameraPart: BasePart,
	previousCameraType: Enum.CameraType,
	previousCameraSubject: Instance?,
	previousCameraMode: Enum.CameraMode,
	previousFieldOfView: number,
	previousTransparency: { [BasePart]: number },
	connections: { RBXScriptConnection },
}

------------------//VARIABLES
local currentState: ViewmodelState?

------------------//FUNCTIONS
local function find_camera_part(vehicle: Model): BasePart?
	local body = vehicle:FindFirstChild(BODY_FOLDER_NAME)
	local cameras = body and body:FindFirstChild(CAMERAS_FOLDER_NAME)
	local cockpit = cameras and cameras:FindFirstChild(COCKPIT_CAMERA_NAME)
	if cockpit and cockpit:IsA("BasePart") then
		return cockpit
	end

	local fallback = cameras and cameras:FindFirstChild(FALLBACK_CAMERA_NAME)
	if fallback and fallback:IsA("BasePart") then
		return fallback
	end

	local driveSeat = vehicle:FindFirstChild("DriveSeat", true)
	return if driveSeat and driveSeat:IsA("BasePart") then driveSeat else nil
end

local function hide_part(state: ViewmodelState, part: BasePart): ()
	if state.previousTransparency[part] == nil then
		state.previousTransparency[part] = part.LocalTransparencyModifier
	end
	part.LocalTransparencyModifier = 1
end

local function hide_character(state: ViewmodelState): ()
	for _, descendant in state.character:GetDescendants() do
		if descendant:IsA("BasePart") then
			hide_part(state, descendant)
		end
	end
end

local function restore_character(state: ViewmodelState): ()
	for part, transparency in state.previousTransparency do
		if part.Parent then
			part.LocalTransparencyModifier = transparency
		end
	end
	table.clear(state.previousTransparency)
end

local function disconnect_state(state: ViewmodelState): ()
	for _, connection in state.connections do
		connection:Disconnect()
	end
	table.clear(state.connections)
end

------------------//MAIN FUNCTIONS
local vehicleViewmodel = {}

function vehicleViewmodel.disable(): ()
	local state = currentState
	if not state then
		return
	end

	local humanoid = state.character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if humanoid and humanoid.Sit and seat and seat:IsDescendantOf(state.vehicle) then
		return
	end

	currentState = nil
	disconnect_state(state)
	restore_character(state)
	state.camera.CameraType = state.previousCameraType
	state.camera.CameraSubject = state.previousCameraSubject
	state.camera.FieldOfView = state.previousFieldOfView
	state.player.CameraMode = state.previousCameraMode
end

function vehicleViewmodel.enable(vehicle: Model): boolean
	local player = Players.LocalPlayer
	local character = player.Character
	local camera = workspace.CurrentCamera
	local cameraPart = find_camera_part(vehicle)
	if not character or not camera or not cameraPart then
		return false
	end

	if currentState and currentState.vehicle == vehicle then
		return true
	end
	vehicleViewmodel.disable()

	local state: ViewmodelState = {
		player = player,
		vehicle = vehicle,
		character = character,
		camera = camera,
		cameraPart = cameraPart,
		previousCameraType = camera.CameraType,
		previousCameraSubject = camera.CameraSubject,
		previousCameraMode = player.CameraMode,
		previousFieldOfView = camera.FieldOfView,
		previousTransparency = {},
		connections = {},
	}
	currentState = state

	hide_character(state)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = COCKPIT_FIELD_OF_VIEW
	camera.CFrame = cameraPart.CFrame

	table.insert(state.connections, RunService.RenderStepped:Connect(function()
		if not currentState or currentState ~= state then
			return
		end
		if not state.vehicle.Parent then
			vehicleViewmodel.disable()
			return
		end
		if not state.cameraPart.Parent then
			local replacement = find_camera_part(state.vehicle)
			if not replacement then
				return
			end
			state.cameraPart = replacement
		end
		camera.CFrame = state.cameraPart.CFrame
	end))

	table.insert(state.connections, character.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("BasePart") and currentState == state then
			hide_part(state, descendant)
		end
	end))

	return true
end

function vehicleViewmodel.is_enabled(vehicle: Model?): boolean
	return currentState ~= nil and (not vehicle or currentState.vehicle == vehicle)
end

------------------//INIT
return vehicleViewmodel
