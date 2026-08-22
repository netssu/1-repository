------------------//SERVICES
local Players: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")

------------------//CONSTANTS
local FESYSTEM_FOLDER_NAME: string = "FESystem"
local VEHICLES_FOLDER_NAME: string = "Vehicles"
local A_CHASSIS_HUD_NAME: string = "A-ChassisHUD"
local VALUES_FOLDER_NAME: string = "Values"
local CAR_VALUE_NAME: string = "Car"
local STEERING_VALUE_NAME: string = "SteerC"
local MISC_FOLDER_NAME: string = "Misc"
local WHEEL_MODEL_NAME: string = "Wheel"
local STEERING_PIVOT_NAME: string = "A"
local STEERING_MOTOR_NAME: string = "W"
local MAX_STEERING_ANGLE: number = math.rad(25)

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local currentSteeringMotor: Motor?

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

local function find_steering_value(vehicle: Model): NumberValue?
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild(A_CHASSIS_HUD_NAME)
	local carValue = hud and hud:FindFirstChild(CAR_VALUE_NAME)
	local values = hud and hud:FindFirstChild(VALUES_FOLDER_NAME)
	local steeringValue = values and values:FindFirstChild(STEERING_VALUE_NAME)
	if carValue and carValue:IsA("ObjectValue") and carValue.Value == vehicle and steeringValue and steeringValue:IsA("NumberValue") then
		return steeringValue
	end
	return nil
end

local function find_steering_motor(vehicle: Model): Motor?
	local misc = vehicle:FindFirstChild(MISC_FOLDER_NAME)
	local wheel = misc and misc:FindFirstChild(WHEEL_MODEL_NAME)
	local pivot = wheel and wheel:FindFirstChild(STEERING_PIVOT_NAME)
	local motor = pivot and pivot:FindFirstChild(STEERING_MOTOR_NAME)
	return if motor and motor:IsA("Motor") then motor else nil
end

local function update_steering_wheel(steeringValue: NumberValue?, steeringMotor: Motor?): ()
	if not steeringValue or not steeringMotor then
		return
	end

	local steering = math.clamp(steeringValue.Value, -1, 1)
	local signedSquare = math.sign(steering) * (steering * steering)
	steeringMotor.DesiredAngle = signedSquare * MAX_STEERING_ANGLE
end

local function update_controller(): ()
	local vehicle = get_owned_vehicle()
	local steeringValue = vehicle and find_steering_value(vehicle)
	local steeringMotor = vehicle and find_steering_motor(vehicle)
	if steeringMotor and steeringValue then
		update_steering_wheel(steeringValue, steeringMotor)
	elseif currentSteeringMotor and currentSteeringMotor.Parent then
		currentSteeringMotor.DesiredAngle = 0
	end
	currentSteeringMotor = steeringMotor
end

------------------//INIT
RunService.RenderStepped:Connect(update_controller)
