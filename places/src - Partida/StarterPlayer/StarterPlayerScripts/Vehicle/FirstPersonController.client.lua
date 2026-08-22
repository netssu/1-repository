------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local vehicleController = require(modules:WaitForChild("Interface"):WaitForChild("VehicleController"))

------------------//CONSTANTS
local VEHICLE_RELEASE_GRACE_SECONDS: number = 1

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local seatedConnection: RBXScriptConnection?
local lastVehicleTime: number = 0

------------------//FUNCTIONS
local function get_owned_vehicle(): Model?
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not seat then
		return nil
	end

	local vehicle = seat:FindFirstAncestorOfClass("Model")
	if vehicle and vehicle:GetAttribute("OwnerUserId") == localPlayer.UserId then
		return vehicle
	end
	return nil
end

local function connect_character(character: Model): ()
	if seatedConnection then
		seatedConnection:Disconnect()
		seatedConnection = nil
	end

	local humanoid = character:WaitForChild("Humanoid")
	if not humanoid:IsA("Humanoid") then
		return
	end

	local function handle_seated(active: boolean, seat: BasePart?): ()
		if active and seat then
			task.defer(function()
				local vehicle = get_owned_vehicle()
				if vehicle then
					vehicleController.Enable(vehicle, nil)
				end
			end)
		end
	end

	seatedConnection = humanoid.Seated:Connect(handle_seated)
	if humanoid.Sit and humanoid.SeatPart then
		task.defer(function()
			handle_seated(true, humanoid.SeatPart)
		end)
	end
end

local function update_vehicle_viewmodel(): ()
	local vehicle = get_owned_vehicle()
	if vehicle then
		lastVehicleTime = os.clock()
		vehicleController.Enable(vehicle, nil)
	elseif os.clock() - lastVehicleTime >= VEHICLE_RELEASE_GRACE_SECONDS then
		vehicleController.Disable()
	end
end

------------------//INIT
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
connect_character(character)
localPlayer.CharacterAdded:Connect(connect_character)
task.spawn(function()
	while localPlayer.Parent do
		update_vehicle_viewmodel()
		task.wait(0.25)
	end
end)
