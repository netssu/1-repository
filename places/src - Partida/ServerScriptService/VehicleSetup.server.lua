------------------//SERVICES
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//DEPENDENCIES
local vehicleService = require(
	ServerStorage:WaitForChild("Modules"):WaitForChild("Race"):WaitForChild("VehicleService")
)

------------------//INIT
vehicleService.start()
