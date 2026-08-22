------------------//SERVICES
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//DEPENDENCIES
local raceSessionService = require(
	ServerStorage:WaitForChild("Modules"):WaitForChild("Race"):WaitForChild("RaceSessionService")
)

------------------//INIT
raceSessionService.start()
