------------------//SERVICES
local Players: Players = game:GetService("Players")

------------------//DEPENDENCIES
local vehicleViewmodel = require(script.Parent:WaitForChild("VehicleViewmodel"))

------------------//VARIABLES
local activeAnimationTrack: AnimationTrack?
local activeVehicle: Model?

------------------//MAIN FUNCTIONS
local vehicleController = {}

function vehicleController.Disable(): ()
	if activeAnimationTrack then
		activeAnimationTrack:Stop()
		activeAnimationTrack = nil
	end
	activeVehicle = nil
	vehicleViewmodel.disable()
end

function vehicleController.Enable(car: Model, _interface: Instance?): boolean
	if activeVehicle == car and vehicleViewmodel.is_enabled(car) then
		return true
	end

	vehicleController.Disable()
	local player = Players.LocalPlayer
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	local driverAnimation = car:FindFirstChild("Driver", true)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if driverAnimation and driverAnimation:IsA("Animation") and animator then
		activeAnimationTrack = animator:LoadAnimation(driverAnimation)
		activeAnimationTrack:Play()
	end

	if not vehicleViewmodel.enable(car) then
		vehicleController.Disable()
		return false
	end

	activeVehicle = car
	return true
end

------------------//INIT
return vehicleController
